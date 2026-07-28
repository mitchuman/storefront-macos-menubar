import Carbon.HIToolbox
import AppKit

/// Registers a single system-wide keyboard shortcut via Carbon's `RegisterEventHotKey` —
/// deliberately not `NSEvent.addGlobalMonitorForEvents`, which requires the user to grant
/// Input Monitoring / Accessibility access. `RegisterEventHotKey` is the long-established,
/// permission-free mechanism most Mac hotkey utilities use for exactly this.
///
/// A standalone singleton, not routed through `NSApp.delegate` — we already learned that
/// `NSApp.delegate as? AppDelegate` silently fails under `@NSApplicationDelegateAdaptor`
/// (see the `@Environment(\.openSettings)` fix used for the Settings window).
@MainActor
final class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var action: (() -> Void)?
    private let hotKeyID = EventHotKeyID(signature: 0x53544652, id: 1) // 'STFR'

    private init() {}

    func register(_ combo: KeyCombo, action: @escaping () -> Void) {
        unregister()
        self.action = action

        if eventHandlerRef == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            let selfPointer = Unmanaged.passUnretained(self).toOpaque()
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, _, userData -> OSStatus in
                    guard let userData else { return OSStatus(eventNotHandledErr) }
                    let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                    MainActor.assumeIsolated {
                        manager.action?()
                    }
                    return noErr
                },
                1,
                &eventType,
                selfPointer,
                &eventHandlerRef
            )
        }

        RegisterEventHotKey(
            combo.keyCode,
            combo.modifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    /// Re-registers with a new combo, reusing whatever action was already set — for
    /// the Settings recorder, which shouldn't need to know the open-panel logic itself.
    func updateCombo(_ combo: KeyCombo) {
        guard let action else { return }
        register(combo, action: action)
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}
