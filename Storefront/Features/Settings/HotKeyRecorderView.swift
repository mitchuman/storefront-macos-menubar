import SwiftUI
import Carbon.HIToolbox

/// A "click to record" field for the global open-panel shortcut. Captures the next
/// key + modifiers via SwiftUI's `.onKeyPress` while focused, translates it into the
/// Carbon key code `KeyCombo`/`GlobalHotKeyManager` need, and updates the binding.
struct HotKeyRecorderView: View {
    @Binding var combo: KeyCombo
    @State private var isRecording = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isRecording {
                Text("Record keys…")
                    .font(.mono(12, weight: .medium))
            } else {
                KeyComboView(combo: combo, font: .system(size: 12, weight: .medium))
            }
        }
            .foregroundStyle(isRecording ? Theme.textSecondary : Theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minWidth: 110)
            .background(Theme.settingsCardFill)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isRecording ? Theme.accent : Theme.borderColor, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .focusable()
            .focused($isFocused)
            .onTapGesture {
                isRecording = true
                isFocused = true
            }
            .onKeyPress { keyPress in
                guard isRecording else { return .ignored }
                guard let keyCode = Self.keyCode(for: keyPress.key) else { return .ignored }
                combo = KeyCombo.from(
                    keyCode: UInt32(keyCode),
                    commandDown: keyPress.modifiers.contains(.command),
                    optionDown: keyPress.modifiers.contains(.option),
                    controlDown: keyPress.modifiers.contains(.control),
                    shiftDown: keyPress.modifiers.contains(.shift)
                )
                isRecording = false
                isFocused = false
                return .handled
            }
    }

    private static func keyCode(for key: KeyEquivalent) -> Int? {
        switch key {
        case .space: return kVK_Space
        case .return: return kVK_Return
        case .tab: return kVK_Tab
        case .delete: return kVK_Delete
        case .escape: return kVK_Escape
        case .upArrow: return kVK_UpArrow
        case .downArrow: return kVK_DownArrow
        case .leftArrow: return kVK_LeftArrow
        case .rightArrow: return kVK_RightArrow
        default:
            guard let lowerChar = String(key.character).lowercased().first else { return nil }
            return KeyCombo.alphanumericKeyCodes[lowerChar]
        }
    }
}
