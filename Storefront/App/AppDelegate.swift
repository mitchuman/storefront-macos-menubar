import AppKit
import SwiftUI
import Sparkle

extension Notification.Name {
    /// Posted by AppDelegate (and the panel rail) to open Settings — `PanelView`
    /// observes this and calls `@Environment(\.openWindow)`, and AppDelegate also
    /// brings any existing Settings window forward / triggers the Settings… menu item.
    static let openSettingsRequested = Notification.Name("openSettingsRequested")
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
    /// Invisible window used to anchor the popover when the menu bar item is hidden.
    private var panelAnchorWindow: NSWindow?
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
            rootView: PanelView().environmentObject(appState)
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
        defaults.synchronize()
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
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let image = NSImage(systemSymbolName: "bag", accessibilityDescription: "Storefront")?
                .withSymbolConfiguration(config)
            image?.isTemplate = true
            button.image = image
            // Text fallback so something still shows if the symbol fails to render.
            if button.image == nil {
                button.title = "SF"
            }
            button.imagePosition = .imageOnly
            button.toolTip = "Storefront"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        statusItem = item
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
            appState.save()
            applyActivationPolicy()
        }

        openSettingsWindow()

        let alert = NSAlert()
        alert.messageText = "Allow Storefront in the Menu Bar"
        alert.informativeText = """
            macOS is hiding the bag icon until Storefront is allowed under:

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
            togglePanel()
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

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Storefront", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openPanelFromMenu() {
        togglePanel()
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

    func togglePanel() {
        guard let popover else { return }

        if popover.isShown {
            closePanel()
            return
        }

        if let button = statusItem?.button {
            // Optical nudge: the bag SF Symbol’s visual center sits slightly right of
            // the button bounds midX, so shift the anchor 1pt right for the arrow.
            var anchor = button.bounds
            anchor.origin.x += 1
            popover.show(relativeTo: anchor, of: button, preferredEdge: .minY)
        } else {
            // Menu bar icon hidden — still honor the global hotkey by anchoring near
            // the pointer (or the primary screen’s menu-bar center as a fallback).
            showPanelFromPointerAnchor(popover)
        }
        popover.contentViewController?.view.window?.becomeKey()
    }

    func closePanel() {
        popover?.performClose(nil)
    }

    private func showPanelFromPointerAnchor(_ popover: NSPopover) {
        tearDownPanelAnchorWindow()

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        let anchorPoint: NSPoint
        if let screen, NSMouseInRect(mouse, screen.frame, false) {
            anchorPoint = mouse
        } else if let screen {
            anchorPoint = NSPoint(x: screen.frame.midX, y: screen.frame.maxY - 4)
        } else {
            anchorPoint = mouse
        }

        let size = NSSize(width: 2, height: 2)
        let frame = NSRect(
            x: anchorPoint.x - size.width / 2,
            y: anchorPoint.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let anchorView = NSView(frame: NSRect(origin: .zero, size: size))
        window.contentView = anchorView
        window.orderFront(nil)
        panelAnchorWindow = window
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
    }

    private func tearDownPanelAnchorWindow() {
        panelAnchorWindow?.orderOut(nil)
        panelAnchorWindow = nil
    }

    /// Temporarily stops the popover from auto-dismissing when it loses key status
    /// (which normally happens the instant a link click activates the browser) — used
    /// for the ⌘-click "keep open" behavior on links.
    func keepPopoverOpenTemporarily() {
        popover?.behavior = .applicationDefined
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
        appState.save()
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
        appState.save()
        applyActivationPolicy()
        if enabled {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func applyActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = appState.settings.showInDock ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
    }

    /// Keeps the menu bar panel popover and Settings windows on the chosen appearance
    /// without overriding `NSApp.appearance` (which would recolor the bag status icon).
    func applyAppearancePreference(_ preference: AppearancePreference) {
        NSApp.appearance = nil
        let appearance = preference.nsAppearance

        popover?.appearance = appearance
        popover?.contentViewController?.view.appearance = appearance

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
        guard let view = popover?.contentViewController?.view else { return }
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
            self.appState.objectWillChange.send()
        }
    }

    // MARK: - Sparkle

    @objc func checkForUpdates(_ sender: Any?) {
        updaterController.checkForUpdates(sender)
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        tearDownPanelAnchorWindow()
    }
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
