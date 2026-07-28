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
        Text(isRecording ? "Press keys…" : combo.displayString)
            .font(.mono(12, weight: .medium))
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

    private static let characterKeyCodes: [Character: Int] = [
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E,
        "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J,
        "k": kVK_ANSI_K, "l": kVK_ANSI_L, "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O,
        "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
        "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X, "y": kVK_ANSI_Y,
        "z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4,
        "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
    ]

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
            return characterKeyCodes[lowerChar]
        }
    }
}
