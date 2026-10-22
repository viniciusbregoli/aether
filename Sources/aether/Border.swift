import AppKit

/// Hyprland-style gradient border around the focused window. With SIP on we can't draw on other
/// apps' windows, so this is our own transparent click-through window laid over the target.
final class Border {
    private let window: NSWindow
    private let gradient = CAGradientLayer()
    private let shape = CAShapeLayer()

    init() {
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        // Tiled windows never overlap, so sitting above all normal windows is enough for now.
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let view = NSView()
        view.wantsLayer = true
        window.contentView = view

        gradient.type = .conic
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        shape.fillColor = nil
        shape.strokeColor = NSColor.black.cgColor
        gradient.mask = shape
        view.layer?.addSublayer(gradient)
        applyStyle()
    }

    /// Picks up border colors, width and rotation speed from the config (also after a reload).
    func applyStyle() {
        gradient.colors = config.borderColors.map { CGColor(red: $0[0], green: $0[1], blue: $0[2], alpha: $0[3]) }
        shape.lineWidth = config.borderWidth

        // Rotating the conic gradient's angle gives the animated Hyprland border; Core Animation
        // runs it in the render server, so it costs us nothing per frame.
        let spin = CAKeyframeAnimation(keyPath: "endPoint")
        spin.values = stride(from: 0.0, through: 2 * .pi, by: .pi / 16).map {
            NSValue(point: CGPoint(x: 0.5 + 0.5 * sin($0), y: 0.5 + 0.5 * cos($0)))
        }
        spin.duration = config.borderRotationSeconds
        spin.repeatCount = .infinity
        gradient.add(spin, forKey: "spin")
    }

    /// `frame` and `screen` are in AX (top-left origin) coordinates. The border sits outside the
    /// window but is clamped to the screen, so on windows touching the screen edges it is drawn
    /// just inside them instead of vanishing off-screen.
    func show(around frame: CGRect, within screen: CGRect) {
        let w = config.borderWidth
        let rect = frame.insetBy(dx: -w, dy: -w).intersection(screen)
        guard !rect.isNull else { return hide() }
        window.setFrame(flip(rect), display: false)
        let bounds = CGRect(origin: .zero, size: window.frame.size)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        shape.frame = bounds
        let radius = config.borderRadius + w / 2
        shape.path = CGPath(roundedRect: bounds.insetBy(dx: w / 2, dy: w / 2), cornerWidth: radius, cornerHeight: radius, transform: nil)
        CATransaction.commit()
        if !window.isVisible { window.orderFrontRegardless() }
    }

    func hide() { window.orderOut(nil) }
}
