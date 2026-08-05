import AppKit
import SwiftUI
import Sparkle

extension Notification.Name {
    /// Posted by AppDelegate (and the panel rail) to open Settings — `PanelView`
    /// observes this and calls `@Environment(\.openWindow)`, and AppDelegate also
    /// brings any existing Settings window forward / triggers the Settings… menu item.
    static let openSettingsRequested = Notification.Name("openSettingsRequested")
    /// Posted whenever the widget panel is about to appear (popover or floating) so
    /// `PanelView` can reset rail focus even when the hosting controller is reused.
    static let panelWillShow = Notification.Name("panelWillShow")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// A direct reference views can reach for things like keeping the panel open —
    /// `NSApp.delegate as? AppDelegate` silently fails under `@NSApplicationDelegateAdaptor`
    /// (it's actually a `SwiftUI.AppDelegate` wrapper instance, a different type).
    static private(set) var shared: AppDelegate?

    /// Unique autosave name — must NOT be a generic `Item-N`. Those collide with
    /// Control Center's `NSStatusItem Visible Item-0`…`Item-11` (all set to 0 on this Mac),
    /// which hides the icon as if the user had ⌘-dragged it out of the menu bar.
    private static let statusItemAutosaveName = "com.humanmarketing.storefront.bag"

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    /// Borderless movable panel used when the menu bar icon is hidden (no popover beak).
    private var floatingPanel: StorefrontFloatingPanel?
    private var floatingPanelHosting: NSViewController?
    private var floatingClickOutsideMonitor: Any?
    private var floatingGlobalClickOutsideMonitor: Any?
    /// Suppresses click-outside dismiss briefly (⌘-click keep-open → browser activation).
    private var suppressFloatingClickOutsideUntil: Date?
    private static let floatingPanelCornerRadius: CGFloat = 14
    let appState = AppState()
    /// Lazy so `self` can be the user-driver delegate (gentle reminders → rail Update button).
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Always come up as a normal app first so the status bar will accept our item.
        // Accessory-only launch on multi-display Macs (esp. macOS 26) was leaving the
        // status item at a zero-height frame. We switch back to the user's Dock preference
        // after the item is created.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        clearStaleStatusItemVisibility()

        if appState.settings.showInMenuBar {
            ensureStatusItem()
        }

        let pop = NSPopover()
        pop.behavior = .transient
        pop.contentSize = Theme.panelSize
        pop.delegate = self
        let hosting = NSHostingController(
            rootView: PanelView().environment(appState)
        )
        hosting.view.wantsLayer = true
        hosting.view.focusRingType = .none
        pop.contentViewController = hosting
        popover = pop

        applyActivationPolicy()
        applyAppearancePreference(appState.settings.appearancePreference)
        applyPanelBackgroundOpacity(appState.settings.opaqueMenuBarWidget)
        // After launch — Tahoe can wedge if `applicationIconImage` runs in App.init.
        AppIconPreference.apply(appState.settings.appIconPreference)
        observeSystemAppearanceChanges()

        GlobalHotKeyManager.shared.register(appState.settings.globalHotkey) { [weak self] in
            self?.togglePanel()
        }
    }

    /// Clicking the Dock icon (or re-opening while already running) surfaces Settings
    /// when no windows are visible — useful if the menu bar icon is missing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openSettingsWindow()
        }
        return true
    }

    /// Keep running as a menu-bar / hotkey app when Settings is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Store writes made in the last moments before quit are debounced (see
    /// `AppState.scheduleSaveStores`) — write them out or they're lost.
    func applicationWillTerminate(_ notification: Notification) {
        appState.flushPendingSaves()
    }

    // MARK: - Status item

    /// Wipe any leftover "hidden by ⌘-drag" flags for our autosave name (and a few
    /// generic names MenuBarExtra may have used in earlier builds).
    private func clearStaleStatusItemVisibility() {
        let defaults = UserDefaults.standard
        let keys = [
            "NSStatusItem Visible \(Self.statusItemAutosaveName)",
            "NSStatusItem Preferred Position \(Self.statusItemAutosaveName)",
            "NSStatusItem Visible Item-0",
            "NSStatusItem Preferred Position Item-0",
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        // Force visible for our named item before creating it.
        defaults.set(true, forKey: "NSStatusItem Visible \(Self.statusItemAutosaveName)")
    }

    func ensureStatusItem() {
        if statusItem != nil {
            statusItem?.isVisible = true
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = Self.statusItemAutosaveName
        item.isVisible = true

        if let button = item.button {
            button.imagePosition = .imageOnly
            button.toolTip = "Storefront"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        statusItem = item
        applyMenuBarIcon()
        UserDefaults.standard.set(true, forKey: "NSStatusItem Visible \(Self.statusItemAutosaveName)")
        // Prefer a right-side slot (low value) so the icon isn't the first one
        // swallowed by the notch / application menu overflow on dual displays.
        if UserDefaults.standard.object(forKey: "NSStatusItem Preferred Position \(Self.statusItemAutosaveName)") == nil {
            UserDefaults.standard.set(Double(48), forKey: "NSStatusItem Preferred Position \(Self.statusItemAutosaveName)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.warnIfMenuBarPermissionMissing()
        }
    }

    /// Updates the status item glyph from `menuBarIconPreference`.
    func applyMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        let preference = appState.settings.menuBarIconPreference
        if let image = Self.menuBarStatusImage(for: preference) {
            button.image = image
            button.title = ""
        } else {
            button.image = nil
            // Text fallback so something still shows if the asset fails to load.
            button.title = "SF"
        }
    }

    /// Template menu-bar glyph sized to match typical status-item SF Symbols.
    private static func menuBarStatusImage(for preference: MenuBarIconPreference) -> NSImage? {
        if let symbolName = preference.systemSymbolName {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Storefront")?
                .withSymbolConfiguration(config)
            image?.isTemplate = true
            return image
        }

        guard let assetName = preference.assetName,
              let source = NSImage(named: assetName) else { return nil }
        // Polaris SVGs read smaller than SF Symbols at the same point size; ~1.5× matches bag.
        let size = NSSize(width: 19.5, height: 19.5)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(
            in: NSRect(origin: .zero, size: size),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = "Storefront"
        return image
    }

    /// macOS 26 (Tahoe) added System Settings → Menu Bar permissions. Without the
    /// app enabled there, `NSStatusItem` still creates successfully but lands at
    /// `(0, -22)` with `button.window.screen == nil` and never appears.
    private func warnIfMenuBarPermissionMissing() {
        guard let button = statusItem?.button,
              let window = button.window else { return }
        let frame = window.frame
        let screenMissing = window.screen == nil
        let offScreen = frame.minY < 0 || frame.height < 1
        guard screenMissing || offScreen else { return }

        // Persist Dock so the user can still reach Settings after dismissing.
        if !appState.settings.showInDock {
            var settings = appState.settings
            settings.showInDock = true
            appState.settings = settings
            appState.saveSettings()
            applyActivationPolicy()
        }

        openSettingsWindow()

        let alert = NSAlert()
        alert.messageText = "Allow Storefront in the Menu Bar"
        alert.informativeText = """
            macOS is hiding the menu bar icon until Storefront is allowed under:

            System Settings → Menu Bar

            Turn Storefront on, then quit and reopen the app (or toggle Show in menu bar).
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Menu Bar Settings")
        alert.addButton(withTitle: "OK")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.MenuBar-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func removeStatusItem() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        self.statusItem = nil
    }

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            // Icon click always anchors to the status item (beak), ignoring Open under mouse.
            togglePanel(anchorToMenuBarIcon: true)
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Storefront", action: #selector(openPanelFromMenu), keyEquivalent: "")
        let (key, mask) = appState.settings.globalHotkey.nsMenuKeyEquivalent
        openItem.keyEquivalent = key
        openItem.keyEquivalentModifierMask = mask
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(settingsTabItem(title: "How to use", tab: .howToUse))

        menu.addItem(.separator())

        // Top-level peers (same group) — not nested under Settings.
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettingsFromMenu), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(settingsTabItem(title: "Stores", tab: .stores))
        menu.addItem(settingsTabItem(title: "Sections", tab: .sections))
        menu.addItem(settingsTabItem(title: "Keybindings", tab: .keybindings))

        menu.addItem(.separator())

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        let feedbackItem = NSMenuItem(title: "Send Feedback", action: #selector(sendFeedback(_:)), keyEquivalent: "")
        feedbackItem.target = self
        menu.addItem(feedbackItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Storefront", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openPanelFromMenu() {
        togglePanel(anchorToMenuBarIcon: true)
    }

    @objc private func openSettingsFromMenu() {
        openSettingsWindow(tab: .general)
    }

    private func settingsTabItem(title: String, tab: SettingsTab) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(openSettingsTabFromMenu(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = tab
        return item
    }

    @objc private func openSettingsTabFromMenu(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? SettingsTab else { return }
        openSettingsWindow(tab: tab)
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    // MARK: - Panel (hotkey + status click)

    private var isPanelVisible: Bool {
        (popover?.isShown ?? false) || (floatingPanel?.isVisible ?? false)
    }

    func togglePanel(anchorToMenuBarIcon: Bool = false) {
        if isPanelVisible {
            closePanel()
            return
        }

        preparePanelForShow()

        // Status-item click / menu: always popover under the icon (with beak).
        // Hotkey: honor Open under mouse, or fall back to floating when no icon.
        let preferFloating = !anchorToMenuBarIcon
            && (appState.settings.openUnderMouse || statusItem?.button == nil)

        if !preferFloating, let button = statusItem?.button, let popover {
            // Optical nudge: status glyphs often sit slightly right of midX; shift
            // the popover anchor 1pt so the arrow lines up with the icon.
            var anchor = button.bounds
            anchor.origin.x += 1
            popover.show(relativeTo: anchor, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
        } else {
            showFloatingPanel()
        }
    }

    /// Rail focus + keyboard parking before each open (hosting views are reused).
    private func preparePanelForShow() {
        appState.exitToRail()
        NotificationCenter.default.post(name: .panelWillShow, object: nil)
    }

    func closePanel() {
        appState.flushPendingSaves()
        popover?.performClose(nil)
        hideFloatingPanel()
    }

    private func showFloatingPanel() {
        let panel = ensureFloatingPanel()
        panel.setFrame(Self.clampedFloatingPanelFrame(near: NSEvent.mouseLocation), display: true)
        applyAppearancePreference(appState.settings.appearancePreference)
        applyPanelBackgroundOpacity(appState.settings.opaqueMenuBarWidget)
        NSApp.activate(ignoringOtherApps: true)
        // Brief grace so the opening interaction can't immediately dismiss us.
        suppressFloatingClickOutsideUntil = Date().addingTimeInterval(0.2)
        panel.makeKeyAndOrderFront(nil)
        // Ensure SwiftUI’s focus / key-press path is live (Escape, TextField, buttons).
        panel.makeFirstResponder(panel.contentView)
        startFloatingClickOutsideMonitor()
    }

    private func hideFloatingPanel() {
        stopFloatingClickOutsideMonitor()
        floatingPanel?.orderOut(nil)
    }

    private func ensureFloatingPanel() -> StorefrontFloatingPanel {
        if let floatingPanel { return floatingPanel }

        let size = Theme.panelSize
        // Borderless windows return `canBecomeKey == false` by default — without a
        // subclass override, SwiftUI never receives clicks or Escape.
        let panel = StorefrontFloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = true
        // Empty chrome / non-interactive labels move the window; buttons and fields
        // keep their own hit targets.
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.acceptsMouseMovedEvents = true

        // Not type-erased through AnyView — that would hide the panel's real view type
        // from SwiftUI's structural diffing at the hosting root.
        let hosting = NSHostingController(
            rootView: PanelView().environment(appState)
        )
        hosting.view.wantsLayer = true
        hosting.view.focusRingType = .none
        hosting.view.layer?.cornerRadius = Self.floatingPanelCornerRadius
        hosting.view.layer?.cornerCurve = .continuous
        hosting.view.layer?.masksToBounds = true
        panel.contentViewController = hosting
        panel.setContentSize(size)

        floatingPanelHosting = hosting
        floatingPanel = panel
        return panel
    }

    /// Places the panel so the pointer sits on the center of the first sidebar store row.
    private static func clampedFloatingPanelFrame(near mouse: NSPoint) -> NSRect {
        let size = Theme.panelSize
        let anchorOffset = Theme.floatingPanelFirstStoreRowCenter

        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        let anchor: NSPoint
        if let screen, NSMouseInRect(mouse, screen.frame, false) {
            anchor = mouse
        } else if let screen {
            anchor = NSPoint(x: screen.frame.midX, y: screen.frame.maxY - 4)
        } else {
            anchor = mouse
        }

        // AppKit origin is bottom-left; SwiftUI offset y is measured from the top.
        let frame = NSRect(
            x: anchor.x - anchorOffset.x,
            y: anchor.y - (size.height - anchorOffset.y),
            width: size.width,
            height: size.height
        )
        return frame.clamped(toVisibleFrameOf: screen)
    }

    private func startFloatingClickOutsideMonitor() {
        stopFloatingClickOutsideMonitor()

        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self else { return }
            guard let panel = self.floatingPanel, panel.isVisible else { return }
            if let until = self.suppressFloatingClickOutsideUntil, Date() < until { return }

            let point = NSEvent.mouseLocation
            if panel.frame.contains(point) { return }
            // Keep open when interacting with Settings.
            if let settings = Self.findSettingsWindow(), settings.isVisible, settings.frame.contains(point) {
                return
            }
            // Ignore the event that opened us (same runloop turn).
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                self.closePanel()
            }
        }

        floatingClickOutsideMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { event in
            handler(event)
            return event
        }
        floatingGlobalClickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown],
            handler: handler
        )
    }

    private func stopFloatingClickOutsideMonitor() {
        if let floatingClickOutsideMonitor {
            NSEvent.removeMonitor(floatingClickOutsideMonitor)
            self.floatingClickOutsideMonitor = nil
        }
        if let floatingGlobalClickOutsideMonitor {
            NSEvent.removeMonitor(floatingGlobalClickOutsideMonitor)
            self.floatingGlobalClickOutsideMonitor = nil
        }
    }

    /// Temporarily stops the popover from auto-dismissing when it loses key status
    /// (which normally happens the instant a link click activates the browser) — used
    /// for the ⌘-click "keep open" behavior on links. Also suppresses floating
    /// click-outside dismiss for the same window.
    func keepPopoverOpenTemporarily() {
        popover?.behavior = .applicationDefined
        suppressFloatingClickOutsideUntil = Date().addingTimeInterval(1.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.popover?.behavior = .transient
        }
    }

    // MARK: - Settings

    /// Opens the dedicated Settings `Window` (id: `"settings"`).
    func openSettingsWindow(tab: SettingsTab? = nil) {
        if let tab {
            appState.selectedSettingsTab = tab
        }
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
        // Bring an existing window forward, or invoke Settings… (Commands → openWindow)
        // when the panel hosting controller hasn't mounted yet.
        DispatchQueue.main.async {
            if let window = Self.findSettingsWindow() {
                window.appearance = self.appState.settings.appearancePreference.nsAppearance
                window.makeKeyAndOrderFront(nil)
            } else if let item = Self.settingsMenuItem(), let action = item.action {
                NSApp.sendAction(action, to: item.target, from: item)
            }
        }
    }

    private static func findSettingsWindow() -> NSWindow? {
        NSApp.windows.first(where: isSettingsWindow)
    }

    private static func isSettingsWindow(_ window: NSWindow) -> Bool {
        let id = window.identifier?.rawValue ?? ""
        if id == "settings" || id.contains("settings") { return true }
        return window.title == "Settings"
    }

    private static func settingsMenuItem() -> NSMenuItem? {
        guard let appMenu = NSApp.mainMenu?.items.first?.submenu else { return nil }
        return appMenu.items.first { item in
            item.keyEquivalent == "," || item.title.localizedCaseInsensitiveContains("settings")
        }
    }

    // MARK: - General toggles

    func setShowInMenuBar(_ enabled: Bool) {
        var settings = appState.settings
        settings.showInMenuBar = enabled
        appState.settings = settings
        appState.saveSettings()
        // Switching surfaces — close whichever panel is up so we don't leave a
        // floating window around after restoring the menu bar icon (or vice versa).
        closePanel()
        if enabled {
            clearStaleStatusItemVisibility()
            removeStatusItem()
            ensureStatusItem()
        } else {
            removeStatusItem()
        }
    }

    func setShowInDock(_ enabled: Bool) {
        var settings = appState.settings
        settings.showInDock = enabled
        appState.settings = settings
        appState.saveSettings()
        applyActivationPolicy()
        if enabled {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func applyActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = appState.settings.showInDock ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
    }

    /// Keeps the menu bar panel popover, floating panel, and Settings windows on the
    /// chosen appearance without overriding `NSApp.appearance` (which would recolor
    /// the status icon).
    func applyAppearancePreference(_ preference: AppearancePreference) {
        NSApp.appearance = nil
        let appearance = preference.nsAppearance

        popover?.appearance = appearance
        popover?.contentViewController?.view.appearance = appearance

        floatingPanel?.appearance = appearance
        floatingPanelHosting?.view.appearance = appearance

        for window in NSApp.windows where Self.isSettingsWindow(window) {
            window.appearance = appearance
            window.contentView?.appearance = appearance
        }

        statusItem?.button?.window?.appearance = nil
        applyPanelBackgroundOpacity(appState.settings.opaqueMenuBarWidget)
    }

    /// Opaque mode fills the hosting view so popover vibrancy doesn’t leak under SwiftUI;
    /// transparent mode stays clear so Liquid Glass / vibrancy show through.
    func applyPanelBackgroundOpacity(_ opaque: Bool) {
        let views = [
            popover?.contentViewController?.view,
            floatingPanelHosting?.view,
        ].compactMap { $0 }

        for view in views {
            view.wantsLayer = true
            if opaque {
                var resolved: CGColor?
                view.effectiveAppearance.performAsCurrentDrawingAppearance {
                    resolved = NSColor.windowBackgroundColor.cgColor
                }
                view.layer?.backgroundColor = resolved
            } else {
                view.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }

    private func observeSystemAppearanceChanges() {
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(systemAppearanceDidChange),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }

    @objc private func systemAppearanceDidChange() {
        // Defaults can lag this notification — resolve on the next turn.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Light/Dark may switch between bundle chrome and an inset override
            // when system appearance flips.
            AppIconPreference.apply(self.appState.settings.appIconPreference)
            guard self.appState.settings.appearancePreference == .system else { return }
            self.applyAppearancePreference(.system)
            self.appState.noteSystemAppearanceChanged()
        }
    }

    // MARK: - Sparkle

    @objc func checkForUpdates(_ sender: Any?) {
        updaterController.checkForUpdates(sender)
    }

    @objc func sendFeedback(_ sender: Any?) {
        guard let url = URL(string: "https://storefront.nuotsu.dev/contact?source=context-menu") else { return }
        NSWorkspace.shared.open(url)
    }
}

extension AppDelegate: NSPopoverDelegate {}

/// Borderless `NSPanel` that can become key/main so SwiftUI receives clicks and Escape.
private final class StorefrontFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Borderless windows skip AppKit’s automatic `constrainFrameRect` during drag,
    /// so every frame change must clamp here for a hard on-screen stop.
    override func setFrameOrigin(_ point: NSPoint) {
        var proposed = frame
        proposed.origin = point
        super.setFrameOrigin(Self.clampedFrame(proposed).origin)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(Self.clampedFrame(frameRect), display: flag)
    }

    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool, animate animateFlag: Bool) {
        super.setFrame(Self.clampedFrame(frameRect), display: displayFlag, animate: animateFlag)
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect.clamped(toVisibleFrameOf: screen ?? Self.preferredScreen(for: frameRect))
    }

    private static func clampedFrame(_ frameRect: NSRect) -> NSRect {
        frameRect.clamped(toVisibleFrameOf: preferredScreen(for: frameRect))
    }

    /// Prefer the screen under the pointer so the panel can cross monitors;
    /// otherwise the screen with the largest intersection with the proposed frame.
    private static func preferredScreen(for frame: NSRect) -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        if let underMouse = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            return underMouse
        }
        return NSScreen.screens.max(by: {
            $0.visibleFrame.intersection(frame).area < $1.visibleFrame.intersection(frame).area
        }) ?? NSScreen.main
    }
}

private extension NSRect {
    /// Clamps origin so the full rect stays inside `screen.visibleFrame`.
    func clamped(toVisibleFrameOf screen: NSScreen?) -> NSRect {
        guard let visible = screen?.visibleFrame else { return self }
        var frame = self
        frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        return frame
    }

    var area: CGFloat { max(0, width) * max(0, height) }
}

// Gentle scheduled reminders: defer Sparkle's auto alert and surface the rail Update button.
// User-initiated checks (menu / About / the button itself) still use Sparkle's standard UI.
extension AppDelegate: SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        if !handleShowingUpdate {
            appState.updateAvailable = true
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        appState.updateAvailable = false
    }

    func standardUserDriverWillFinishUpdateSession() {
        appState.updateAvailable = false
    }
}
