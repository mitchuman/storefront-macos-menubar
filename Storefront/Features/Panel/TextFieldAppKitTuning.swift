import SwiftUI
import AppKit

/// Walks to the nearby `NSTextField` under a SwiftUI `TextField` and applies AppKit
/// tuning that SwiftUI does not expose: no focus ring (avoids focus layout shift).
/// Caret color is deliberately not handled here — use `CaretTintedTextField` when the
/// caret must match a custom accent.
struct TextFieldAppKitTuning: NSViewRepresentable {
    func makeNSView(context: Context) -> TunerView {
        let view = TunerView()
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: TunerView, context: Context) {
        nsView.applyTuning()
    }

    final class TunerView: NSView {
        /// `updateNSView` fires on every panel re-render, and resolving the field means
        /// walking up the superview chain and recursing through sibling subtrees. Hold
        /// on to the field we found instead of re-walking for it each time.
        private weak var tunedField: NSTextField?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            tunedField = nil
            applyTuning()
        }

        func applyTuning() {
            guard let field = resolvedField() else { return }
            field.focusRingType = .none
            field.isBordered = false
            field.isBezeled = false
            field.drawsBackground = false
            if let editor = field.currentEditor() as? NSTextView {
                editor.textContainerInset = .zero
                editor.textContainer?.lineFragmentPadding = 0
            }
        }

        private func resolvedField() -> NSTextField? {
            if let tunedField, let window, tunedField.window === window {
                return tunedField
            }
            let field = Self.nearestTextField(from: self)
            tunedField = field
            return field
        }

        private static func nearestTextField(from view: NSView) -> NSTextField? {
            var node: NSView? = view.superview
            while let current = node {
                if let field = current as? NSTextField {
                    return field
                }
                if let field = current.subviews.compactMap({ $0 as? NSTextField }).first {
                    return field
                }
                for sibling in current.subviews where sibling !== view {
                    if let field = findTextField(in: sibling) {
                        return field
                    }
                }
                node = current.superview
            }
            return nil
        }

        private static func findTextField(in root: NSView) -> NSTextField? {
            if let field = root as? NSTextField { return field }
            for child in root.subviews {
                if let field = findTextField(in: child) { return field }
            }
            return nil
        }
    }
}

// MARK: - Owned AppKit field (reliable caret tint)

/// Single-line plain text field that owns its field-editor caret color. Use this
/// instead of SwiftUI `TextField` + `TextFieldAppKitTuning` when caret color must
/// match a store accent — SwiftUI resets the shared field editor after focus.
struct CaretTintedTextField: NSViewRepresentable {
    @Binding var text: String
    var caretColor: NSColor
    var fontSize: CGFloat = 11.5
    var onSubmit: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> CaretTintedNSTextField {
        let field = CaretTintedNSTextField(string: text)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: fontSize)
        field.textColor = NSColor.labelColor
        field.caretColor = caretColor
        field.delegate = context.coordinator
        field.cell?.isScrollable = true
        field.lineBreakMode = .byClipping
        field.usesSingleLineMode = true
        field.maximumNumberOfLines = 1
        return field
    }

    func updateNSView(_ nsView: CaretTintedNSTextField, context: Context) {
        context.coordinator.parent = self
        if !nsView.caretColor.isEqual(caretColor) {
            nsView.caretColor = caretColor
        }
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.applyCaretColor()
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CaretTintedTextField

        init(_ parent: CaretTintedTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

/// `NSTextField` subclass that re-applies caret color whenever the shared field
/// editor is attached or queried — AppKit otherwise paints the system accent.
final class CaretTintedNSTextField: NSTextField {
    var caretColor: NSColor = .controlAccentColor {
        didSet { applyCaretColor() }
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            applyCaretColor()
            // Field editor finishes configuring after becomeFirstResponder returns.
            DispatchQueue.main.async { [weak self] in
                self?.applyCaretColor()
            }
        }
        return became
    }

    override func currentEditor() -> NSText? {
        let editor = super.currentEditor()
        if let textView = editor as? NSTextView {
            textView.textContainerInset = .zero
            textView.textContainer?.lineFragmentPadding = 0
            if !textView.insertionPointColor.isEqual(caretColor) {
                textView.insertionPointColor = caretColor
                textView.updateInsertionPointStateAndRestartTimer(true)
            }
        }
        return editor
    }

    func applyCaretColor() {
        // Prefer the window field editor — avoid re-entering `currentEditor()`.
        guard let editor = window?.fieldEditor(false, for: self) as? NSTextView else { return }
        if !editor.insertionPointColor.isEqual(caretColor) {
            editor.insertionPointColor = caretColor
            editor.updateInsertionPointStateAndRestartTimer(true)
        }
    }
}

extension NSColor {
    /// Opaque sRGB color from a `"rrggbb"` / `"#rrggbb"` hex string.
    convenience init(hex: String) {
        let (r, g, b) = HexColor.components(hex)
        self.init(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
    }
}
