import SwiftUI

/// Click-to-record control for editable keyboard shortcuts. Captures the next key +
/// modifiers via `.onKeyPress`, stores a Carbon-style `KeyCombo`, and updates the binding.
struct HotKeyRecorderView: View {
    enum Style {
        case field
        case compact
    }

    @Binding var combo: KeyCombo
    var style: Style = .field
    @State private var isRecording = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button {
            beginRecording()
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
        .focusable()
        .focused($isFocused)
        .onChange(of: isFocused) { _, focused in
            // Losing focus (clicking elsewhere) cancels an in-progress recording.
            if !focused { isRecording = false }
        }
        .onKeyPress { keyPress in
            guard isRecording, isFocused else { return .ignored }
            // Esc cancels without changing the combo.
            if keyPress.key == .escape {
                isRecording = false
                isFocused = false
                return .handled
            }
            guard let keyCode = KeyCombo.keyCode(for: keyPress.key) else { return .ignored }
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

    private func beginRecording() {
        isRecording = true
        // Focus after the button action + label update so the first keystroke is
        // delivered to `.onKeyPress` without requiring a second click.
        DispatchQueue.main.async {
            isFocused = true
        }
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
