import Carbon.HIToolbox
import Foundation

/// A keyboard shortcut, stored in Carbon's key-code + modifier-mask shape since that's
/// what `RegisterEventHotKey` needs directly (see `GlobalHotKeyManager`).
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var modifierFlags: UInt32

    static let `default` = KeyCombo(
        keyCode: UInt32(kVK_ANSI_S),
        modifierFlags: UInt32(cmdKey | optionKey | controlKey)
    )

    var displayString: String {
        var result = ""
        if modifierFlags & UInt32(controlKey) != 0 { result += "⌃" }
        if modifierFlags & UInt32(optionKey) != 0 { result += "⌥" }
        if modifierFlags & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifierFlags & UInt32(cmdKey) != 0 { result += "⌘" }
        result += Self.keyCodeToDisplayString(keyCode)
        return result
    }

    /// Covers the common ANSI/QWERTY keys used for hotkeys. Non-QWERTY layouts may show
    /// the wrong glyph for punctuation keys — a documented, common simplification (full
    /// layout-aware translation needs `UCKeyTranslate`, overkill for this use case).
    private static func keyCodeToDisplayString(_ keyCode: UInt32) -> String {
        let map: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E",
            kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J",
            kVK_ANSI_K: "K", kVK_ANSI_L: "L", kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
            kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X", kVK_ANSI_Y: "Y",
            kVK_ANSI_Z: "Z",
            kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
            kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
            kVK_Space: "Space", kVK_Return: "⏎", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_Escape: "⎋",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        return map[Int(keyCode)] ?? "Key\(keyCode)"
    }

    /// Builds a combo from a SwiftUI `KeyPress` (used by the Settings recorder).
    static func from(keyCode: UInt32, commandDown: Bool, optionDown: Bool, controlDown: Bool, shiftDown: Bool) -> KeyCombo {
        var mods: UInt32 = 0
        if commandDown { mods |= UInt32(cmdKey) }
        if optionDown { mods |= UInt32(optionKey) }
        if controlDown { mods |= UInt32(controlKey) }
        if shiftDown { mods |= UInt32(shiftKey) }
        return KeyCombo(keyCode: keyCode, modifierFlags: mods)
    }
}
