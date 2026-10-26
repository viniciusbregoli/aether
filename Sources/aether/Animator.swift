import AetherCore
import AppKit

/// Animates windows by writing AX position every display frame (~0.2 ms per call) and the size
/// only at the halfway point and the end, since a resize makes the app relayout (~7-20 ms).
/// Same approach as glide and rift; needs no SIP changes.
final class Animator: NSObject {
    private struct Animation {
        let window: Window
        let from: CGRect
        let to: CGRect
        let start: CFTimeInterval
        let duration: Double
        let curve: AnimationCurve
        var resized = false
        let completion: (() -> Void)?

        func rect(at now: CFTimeInterval) -> CGRect {
            lerp(from, to, curve.value(at: (now - start) / duration))
        }
    }

    private var animations: [CGWindowID: Animation] = [:]
    /// Apps that had AXEnhancedUserInterface on when one of their windows started moving.
    /// Assistive tools turn it on (Zen and Finder had it), and then the app animates every position
    /// write itself, trailing behind ours; it stays off until the app's last animation ends.
    private var enhanced: Set<pid_t> = []
    private var link: CADisplayLink?
    /// Called with every frame a window is moved to, so overlays (the border) can follow.
    var onFrame: ((CGWindowID, CGRect) -> Void)?

    func isAnimating(_ id: CGWindowID) -> Bool { animations[id] != nil }

    /// `from` pre-positions the window (used for slide-ins); nil starts from where it is now.
    /// A new animation on the same window replaces the old one and drops its completion.
    func animate(_ window: Window, from: CGRect? = nil, to: CGRect, completion: (() -> Void)? = nil) {
        let now = CACurrentMediaTime()
        let inFlight = animations[window.id]?.rect(at: now)
        guard let start = from ?? inFlight ?? window.frame, start != to,
              config.animationsEnabled, config.animationDuration > 0 else {
            animations[window.id] = nil
            restoreEnhanced(window.pid)
            // Every relayout lands here for windows that didn't move; skip the AX writes for those.
            if from != nil || inFlight != nil || window.frame != to { window.setFrame(to) }
            onFrame?(window.id, to)
            completion?()
            return
        }
        disableEnhanced(window.pid)
        // A parked window can have another size than the one it slides in with; sizing it while it is
        // still off screen leaves only position writes for the slide.
        if let from { window.setFrame(from) }
        animations[window.id] = Animation(window: window, from: start, to: to, start: now,
                                           duration: config.animationDuration, curve: config.animationCurve, completion: completion)
        if link == nil, let screen = NSScreen.screens.first {
            link = screen.displayLink(target: self, selector: #selector(tick))
            link?.add(to: .main, forMode: .common)
        }
    }

    func cancel(_ id: CGWindowID) {
        guard let animation = animations.removeValue(forKey: id) else { return }
        restoreEnhanced(animation.window.pid)
    }

    private func disableEnhanced(_ pid: pid_t) {
        guard !enhanced.contains(pid) else { return }
        let app = AXUIElementCreateApplication(pid)
        guard app.get("AXEnhancedUserInterface") == true,
              AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse) == .success else { return }
        enhanced.insert(pid)
    }

    private func restoreEnhanced(_ pid: pid_t) {
        guard enhanced.contains(pid), !animations.values.contains(where: { $0.window.pid == pid }) else { return }
        // A failed write keeps the app listed, so the end of its next animation tries again.
        guard AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid), "AXEnhancedUserInterface" as CFString,
                                           kCFBooleanTrue) == .success else { return }
        enhanced.remove(pid)
    }

    /// Disabling motion on reload still completes outgoing workspace moves so they get parked.
    func finishAll() {
        let pending = Array(animations.values)
        animations.removeAll()
        link?.invalidate()
        link = nil
        for animation in pending {
            animation.window.setFrame(animation.to)
            onFrame?(animation.window.id, animation.to)
            animation.completion?()
        }
        for pid in enhanced { restoreEnhanced(pid) }
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        for (id, var a) in animations {
            let t = (now - a.start) / a.duration
            if t >= 1 {
                animations[id] = nil
                a.window.setFrame(a.to)
                restoreEnhanced(a.window.pid)
                onFrame?(id, a.to)
                a.completion?()
                continue
            }
            if !a.resized && t >= 0.5 && a.from.size != a.to.size {
                a.window.setSize(a.to.size)
                a.resized = true
                animations[id] = a
            }
            let r = a.rect(at: now)
            a.window.setPosition(r.origin)
            onFrame?(id, CGRect(origin: r.origin, size: a.resized ? a.to.size : a.from.size))
        }
        if animations.isEmpty {
            link?.invalidate()
            link = nil
        }
    }
}
