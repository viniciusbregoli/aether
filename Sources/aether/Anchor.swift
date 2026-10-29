import AppKit

/// An invisible 1x1 window of aether's own on the desktop Space. Activating aether alone leaves
/// macOS on a native fullscreen Space, so switching from a fullscreen window to an empty workspace
/// would show nothing new; focusing a window that lives on the desktop makes macOS switch back
/// there. AeroSpace has no such fallback and stays on the fullscreen Space.
// shortcut: one anchor, on the main monitor's desktop, where every unpinned workspace opens.
// Upgrade to one per monitor if switching a fullscreen secondary monitor to an empty workspace matters.
final class Anchor {
    private let window: NSWindow

    init() {
        window = KeyableWindow(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1), styleMask: .borderless,
                               backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        // Not canJoinAllSpaces: being on the desktop Space only is what makes macOS switch to it.
        window.collectionBehavior = [.ignoresCycle]
        window.orderFrontRegardless()
    }

    func focus() {
        // The cooperative NSApp.activate() is refused while a fullscreen app is frontmost.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

/// Borderless windows refuse key status by default.
private final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
