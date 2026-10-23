import AppKit

/// Dims inactive windows. With SIP on we can't change another app's window opacity, so each dimmed
/// window gets our own click-through overlay at normal level, ordered directly above it. A
/// floating-level overlay would also cover dialogs and popups that sit above the window.
final class Dimmer {
    private var overlays: [CGWindowID: NSWindow] = [:]
    private var spare: [NSWindow] = []

    /// `frames` are in AX coordinates and name exactly the windows to dim; every other overlay goes away.
    /// Called after every layout and focus change, since raising a window changes the stack.
    func show(_ frames: [CGWindowID: CGRect]) {
        for id in overlays.keys where frames[id] == nil { release(id) }
        for (id, frame) in frames {
            let overlay = overlays[id] ?? makeOverlay(for: id)
            overlay.setFrame(flip(frame), display: false)
            overlay.order(.above, relativeTo: Int(id))
        }
    }

    /// Cheap enough for every animation frame: no AX calls and no reordering.
    func move(_ id: CGWindowID, to frame: CGRect) {
        overlays[id]?.setFrame(flip(frame), display: false)
    }

    func hideAll() {
        for id in overlays.keys { release(id) }
    }

    /// Picks up color and opacity after a config reload.
    func applyStyle() {
        for overlay in overlays.values + spare { style(overlay) }
    }

    /// The fill lives on a layer so its corners can follow the border radius, like the window underneath.
    private func style(_ overlay: NSWindow) {
        let c = config.dimColor
        overlay.contentView?.layer?.backgroundColor = CGColor(red: c[0], green: c[1], blue: c[2], alpha: c[3] * config.dimInactive)
        overlay.contentView?.layer?.cornerRadius = config.borderRadius
    }

    private func makeOverlay(for id: CGWindowID) -> NSWindow {
        let overlay = spare.popLast() ?? newWindow()
        style(overlay)
        overlays[id] = overlay
        return overlay
    }

    private func release(_ id: CGWindowID) {
        guard let overlay = overlays.removeValue(forKey: id) else { return }
        overlay.orderOut(nil)
        spare.append(overlay)
    }

    private func newWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let view = NSView()
        view.wantsLayer = true
        window.contentView = view
        return window
    }
}
