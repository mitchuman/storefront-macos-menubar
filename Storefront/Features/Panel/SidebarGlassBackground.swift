import AppKit
import SwiftUI

/// Floating sidebar / header chrome — prefers macOS 26 `NSGlassEffectView`, falls back to
/// `NSVisualEffectView` (cmux `SidebarVisualEffectBackground` recipe).
///
/// Always installed as a **background**: the representable’s root view returns `nil`
/// from `hitTest` so AppKit cannot steal clicks from SwiftUI controls on top
/// (same failure mode as `MouseTrackingOverlay` without a passthrough `hitTest`).
struct SidebarGlassBackground: NSViewRepresentable {
    /// `NSGlassEffectView` style — `0` regular (frosted), `1` clear (blur without white wash).
    enum GlassStyle: Int {
        case regular = 0
        case clear = 1
    }

    var cornerRadius: CGFloat = Theme.railCornerRadius
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    var preferLiquidGlass: Bool = true
    var glassStyle: GlassStyle = .regular
    var tintColor: NSColor? = nil

    static var liquidGlassAvailable: Bool {
        NSClassFromString("NSGlassEffectView") != nil
    }

    func makeNSView(context: Context) -> PassthroughContainerView {
        let container = PassthroughContainerView()
        container.autoresizingMask = [.width, .height]

        let chrome: NSView
        if preferLiquidGlass, let glassClass = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let glass = glassClass.init(frame: .zero)
            glass.autoresizingMask = [.width, .height]
            glass.wantsLayer = true
            applyCornerRadius(to: glass)
            applyGlassConfiguration(to: glass)
            chrome = glass
        } else {
            let view = NSVisualEffectView()
            view.autoresizingMask = [.width, .height]
            view.wantsLayer = true
            view.layerContentsRedrawPolicy = .onSetNeedsDisplay
            view.material = material
            view.blendingMode = blendingMode
            view.state = .active
            applyCornerRadius(to: view)
            chrome = view
        }

        chrome.frame = container.bounds
        container.addSubview(chrome)
        container.chromeView = chrome
        return container
    }

    func updateNSView(_ container: PassthroughContainerView, context: Context) {
        guard let chrome = container.chromeView else { return }
        chrome.frame = container.bounds
        applyCornerRadius(to: chrome)
        if chrome.className == "NSGlassEffectView" {
            applyGlassConfiguration(to: chrome)
        } else if let visualEffect = chrome as? NSVisualEffectView {
            visualEffect.material = material
            visualEffect.blendingMode = blendingMode
            visualEffect.state = .active
            visualEffect.needsDisplay = true
        }
    }

    private func applyCornerRadius(to view: NSView) {
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = cornerRadius > 0
    }

    private func applyGlassConfiguration(to glassView: NSView) {
        let tintSelector = NSSelectorFromString("setTintColor:")
        if glassView.responds(to: tintSelector) {
            glassView.perform(tintSelector, with: tintColor)
        }

        let styleSelector = NSSelectorFromString("setStyle:")
        if glassView.responds(to: styleSelector),
           let implementation = glassView.method(for: styleSelector)
        {
            typealias StyleSetter = @convention(c) (AnyObject, Selector, Int) -> Void
            let setter = unsafeBitCast(implementation, to: StyleSetter.self)
            setter(glassView, styleSelector, glassStyle.rawValue)
        }
    }
}

/// Hosts glass / vibrancy chrome but never wins AppKit hit-testing.
final class PassthroughContainerView: NSView {
    var chromeView: NSView?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        chromeView?.frame = bounds
    }
}
