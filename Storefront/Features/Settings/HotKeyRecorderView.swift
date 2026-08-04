import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click-to-record control for editable keyboard shortcuts. Captures the next key +
/// modifiers via a local `NSEvent` monitor (not `@FocusState` — plain buttons don't
/// keep keyboard focus after click on macOS, which snapped recording back to idle).
struct HotKeyRecorderView: View {
    enum Style {
        case field
        case compact
    }

    @Binding var combo: KeyCombo
    var style: Style = .field
    @State private var isRecording = false
    /// Owns NSEvent monitors so closures don't capture a stale `View` value.
    @StateObject private var session = RecordingSession()
    /// After click-away cancel, the same click can still fire this Button — ignore it.
    @State private var suppressRestartUntil: Date?

    var body: some View {
        Button {
            if isRecording {
                stopRecording()
            } else if let until = suppressRestartUntil, Date() < until {
                return
            } else {
                beginRecording()
            }
        } label: {
            Group {
                if isRecording {
                    Text("Record keys…")
                        .font(recordingFont)
                } else {
                    KeyComboView(combo: combo, font: idleFont)
                }
            }
            .foregroundStyle(isRecording ? Theme.recordingText : Theme.textPrimary)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minWidth: style == .field ? 110 : nil)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(isRecording ? Theme.errorDot : Theme.borderColor, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(style == .compact ? "Click to re-record this shortcut" : "")
        .accessibilityHint(style == .compact ? "Click to re-record this shortcut" : "")
        .onDisappear { stopRecording() }
    }

    private func beginRecording() {
        isRecording = true
        session.start(
            onCombo: { newCombo in
                combo = newCombo
                stopRecording()
            },
            onCancel: {
                stopRecording()
            },
            onClickAway: {
                stopRecording(suppressRestart: true)
            }
        )
    }

    private func stopRecording(suppressRestart: Bool = false) {
        if suppressRestart {
            suppressRestartUntil = Date().addingTimeInterval(0.2)
        }
        isRecording = false
        session.stop()
    }

    private var recordingFont: Font {
        switch style {
        case .field: .mono(12, weight: .medium)
        case .compact: .system(size: 11, weight: .medium)
        }
    }

    private var idleFont: Font {
        switch style {
        case .field: .system(size: 12, weight: .medium)
        case .compact: .system(size: 11, weight: .medium)
        }
    }

    private var horizontalPadding: CGFloat {
        style == .field ? 10 : 7
    }

    private var verticalPadding: CGFloat {
        style == .field ? 6 : 3
    }

    private var cornerRadius: CGFloat {
        style == .field ? 6 : 5
    }

    private var backgroundColor: Color {
        switch style {
        case .field: Theme.settingsCardFill
        // Editable legend chips read as interactive (white); fixed chips stay greyed.
        case .compact: Color.adaptive(light: .white, dark: .white.opacity(0.14))
        }
    }
}

/// Holds local event monitors for one recording session.
private final class RecordingSession: ObservableObject {
    private var keyMonitor: Any?
    private var mouseMonitor: Any?

    func start(
        onCombo: @escaping (KeyCombo) -> Void,
        onCancel: @escaping () -> Void,
        onClickAway: @escaping () -> Void
    ) {
        stop()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                onCancel()
                return nil
            }
            if Self.isModifierKeyCode(event.keyCode) {
                return nil
            }
            onCombo(
                KeyCombo.from(
                    keyCode: UInt32(event.keyCode),
                    commandDown: event.modifierFlags.contains(.command),
                    optionDown: event.modifierFlags.contains(.option),
                    controlDown: event.modifierFlags.contains(.control),
                    shiftDown: event.modifierFlags.contains(.shift)
                )
            )
            return nil
        }

        // Install after the initiating click finishes so it doesn't immediately cancel.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.keyMonitor != nil else { return }
            self.mouseMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { event in
                onClickAway()
                return event
            }
        }
    }

    func stop() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
    }

    deinit {
        stop()
    }

    private static func isModifierKeyCode(_ keyCode: UInt16) -> Bool {
        switch Int(keyCode) {
        case kVK_Shift, kVK_RightShift,
             kVK_Control, kVK_RightControl,
             kVK_Option, kVK_RightOption,
             kVK_Command, kVK_RightCommand,
             kVK_Function:
            return true
        default:
            return false
        }
    }
}
