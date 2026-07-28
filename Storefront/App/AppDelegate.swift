import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// A direct reference views can reach for things like keeping the popover open —
    /// `NSApp.delegate as? AppDelegate` silently fails under `@NSApplicationDelegateAdaptor`
    /// (it's actually a `SwiftUI.AppDelegate` wrapper instance, a different type).
    static private(set) var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "bag", accessibilityDescription: "Storefront")
            button.action = #selector(togglePanel(_:))
            button.target = self
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

    @objc private func togglePanel(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
            appState.refreshVisibleStoresIfStale()
        }
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
