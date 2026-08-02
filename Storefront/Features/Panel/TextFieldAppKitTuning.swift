import SwiftUI
import AppKit

/// Walks to the nearby `NSTextField` under a SwiftUI `TextField` and applies AppKit
/// tuning that SwiftUI does not expose: no focus ring (avoids focus layout shift) and
/// an optional custom insertion-point (caret) color on the field editor.
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
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyTuning()
            installObserverIfNeeded()
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func applyTuning() {
            guard let field = Self.nearestTextField(from: self) else { return }
            field.focusRingType = .none
            field.isBordered = false
            field.isBezeled = false
            field.drawsBackground = false
            // Keep field-editor metrics flush with the idle cell so typed text doesn't
            // jump relative to our SwiftUI placeholder overlay.
            if let editor = field.currentEditor() as? NSTextView {
                editor.textContainerInset = .zero
                editor.textContainer?.lineFragmentPadding = 0
            }
            applyCaretColor(on: field)
        }

        private func installObserverIfNeeded() {
            guard observer == nil else { return }
            observer = NotificationCenter.default.addObserver(
                forName: NSControl.textDidBeginEditingNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let self,
                      let field = note.object as? NSTextField,
                      Self.nearestTextField(from: self) === field
                else { return }
                self.applyCaretColor(on: field)
            }
        }

        private func applyCaretColor(on field: NSTextField) {
            guard let insertionPointColor,
                  let editor = field.currentEditor() as? NSTextView
            else { return }
            editor.insertionPointColor = insertionPointColor
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
