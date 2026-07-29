import AppKit
import SwiftUI
import Sparkle

extension Notification.Name {
    /// Posted by the status-item right-click menu's "Settings…" item, since `AppDelegate`
    /// (an `NSObject`, not a SwiftUI `View`) has no direct access to `@Environment(\.openSettings)`
    /// — `PanelView` observes this and calls its own `openSettings` action instead.
    static let openSettingsRequested = Notification.Name("openSettingsRequested")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// A direct reference views can reach for things like keeping the popover open —
    /// `NSApp.delegate as? AppDelegate` silently fails under `@NSApplicationDelegateAdaptor`
    /// (it's actually a `SwiftUI.AppDelegate` wrapper instance, a different type).
    static private(set) var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    let appState = AppState()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            button.image = NSImage(systemSymbolName: "bag", accessibilityDescription: "Storefront")?
                .withSymbolConfiguration(config)
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        let pop = NSPopover()
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(
            rootView: PanelView().environmentObject(appState)
        )
        popover = pop

        GlobalHotKeyManager.shared.register(appState.settings.globalHotkey) { [weak self] in
            self?.togglePanel(nil)
        }
    }

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            togglePanel(sender)
        }
    }

    @objc private func togglePanel(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
        }
    }

    /// Closes the popover if it's open — used by Esc at the top level of keyboard
    /// navigation (mirrors the `keepPopoverOpenTemporarily()` reach-into-`shared` convention).
    func closePanel() {
        popover?.performClose(nil)
    }

    /// A standalone `NSMenu` shown only for a right-click, rather than assigning
    /// `statusItem.menu` permanently — that would route every click (including the
    /// normal left-click open/close) through the menu instead of `togglePanel`.
    private func showStatusMenu() {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Storefront", action: #selector(openPanelFromMenu), keyEquivalent: "")
        let (key, mask) = appState.settings.globalHotkey.nsMenuKeyEquivalent
        openItem.keyEquivalent = key
        openItem.keyEquivalentModifierMask = mask
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        func tabItem(_ title: String, tab: SettingsTab, keyEquivalent: String = "") -> NSMenuItem {
            let item = NSMenuItem(title: title, action: #selector(openSettingsTabFromMenu(_:)), keyEquivalent: keyEquivalent)
            item.target = self
            item.representedObject = tab
            return item
        }

        menu.addItem(tabItem("Settings…", tab: .general, keyEquivalent: ","))
        menu.addItem(tabItem("Stores", tab: .stores))
        menu.addItem(tabItem("Sections", tab: .sections))
        menu.addItem(tabItem("Shortcuts", tab: .shortcuts))

        menu.addItem(.separator())

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
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
        togglePanel(nil)
    }

    @objc private func openSettingsTabFromMenu(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? SettingsTab else { return }
        appState.selectedSettingsTab = tab
        NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    /// Temporarily stops the popover from auto-dismissing when it loses key status
    /// (which normally happens the instant a link click activates the browser) — used
    /// for the ⌥-click "keep open" behavior on links.
    func keepPopoverOpenTemporarily() {
        popover?.behavior = .applicationDefined
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.popover?.behavior = .transient
        }
    }
}
