import SwiftUI
import AppKit

/// Walks to the nearby `NSTextField` under a SwiftUI `TextField` and applies AppKit
/// tuning that SwiftUI does not expose: no focus ring (avoids focus layout shift).
/// Optional caret color is best-effort for SwiftUI-owned fields; prefer
/// `CaretTintedTextField` when the caret must match a custom accent.
struct TextFieldAppKitTuning: NSViewRepresentable {
    var insertionPointColor: NSColor?

    func makeNSView(context: Context) -> TunerView {
        let view = TunerView()
        view.isHidden = true
        view.insertionPointColor = insertionPointColor
        return view
    }

    func updateNSView(_ nsView: TunerView, context: Context) {
        nsView.insertionPointColor = insertionPointColor
        nsView.applyTuning()
    }

    final class TunerView: NSView {
        var insertionPointColor: NSColor?
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyTuning()
            installObserversIfNeeded()
        }

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func applyTuning() {
            guard let field = Self.nearestTextField(from: self) else { return }
            field.focusRingType = .none
            field.isBordered = false
            field.isBezeled = false
            field.drawsBackground = false
            if let editor = field.currentEditor() as? NSTextView {
                editor.textContainerInset = .zero
                editor.textContainer?.lineFragmentPadding = 0
            }
            applyCaretColor(on: field)
            scheduleCaretColor(on: field)
        }

        private func installObserversIfNeeded() {
            guard observers.isEmpty else { return }

            observers.append(
                NotificationCenter.default.addObserver(
                    forName: NSControl.textDidBeginEditingNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] note in
                    guard let self,
                          let field = note.object as? NSTextField,
                          Self.nearestTextField(from: self) === field
                    else { return }
                    self.applyCaretColor(on: field)
                    self.scheduleCaretColor(on: field)
                }
            )

            observers.append(
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didBecomeKeyNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] note in
                    guard let self,
                          let window = note.object as? NSWindow,
                          window === self.window,
                          let field = Self.nearestTextField(from: self),
                          window.firstResponder === field || window.firstResponder === field.currentEditor()
                    else { return }
                    self.applyCaretColor(on: field)
                    self.scheduleCaretColor(on: field)
                }
            )
        }

        private func scheduleCaretColor(on field: NSTextField) {
            DispatchQueue.main.async { [weak self] in
                self?.applyCaretColor(on: field)
            }
        }

        private func applyCaretColor(on field: NSTextField) {
            guard let insertionPointColor else { return }
            let editor = (field.currentEditor() as? NSTextView)
                ?? (field.window?.fieldEditor(false, for: field) as? NSTextView)
            guard let editor else { return }
            editor.insertionPointColor = insertionPointColor
            editor.updateInsertionPointStateAndRestartTimer(true)
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
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&value)
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
