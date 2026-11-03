import CoreGraphics

/// Selects a window in the destination workspace, ignoring moved or destroyed candidates.
public func windowToFocus(in workspace: [UInt32], preferred: UInt32? = nil, remembered: UInt32? = nil) -> UInt32? {
    if let preferred, workspace.contains(preferred) { return preferred }
    if let remembered, workspace.contains(remembered) { return remembered }
    return workspace.first
}

/// Only explicit workspace commands toggle back; focus-driven switches use their destination.
public func workspaceToActivate(requested: Int, current: Int, previous: Int?, autoBackAndForth: Bool) -> Int {
    if autoBackAndForth, requested == current { return previous ?? current }
    return requested
}

/// Windows that get a dimming overlay: the visible ones of the workspace except the focused one.
/// Nothing is dimmed while focus is outside the workspace (a dialog, another app), so a window is
/// never dimmed just because its own popup took focus.
public func dimTargets(in workspace: [UInt32], focused: UInt32?, parked: Set<UInt32>) -> [UInt32] {
    guard let focused, workspace.contains(focused) else { return [] }
    return workspace.filter { $0 != focused && !parked.contains($0) }
}

/// One entry of `CGWindowListCopyWindowInfo`, front to back, with bounds in top-left space.
public struct ScreenWindow: Equatable, Sendable {
    public let id: UInt32
    public let pid: Int32
    public let layer: Int
    public let alpha: Double
    public let bounds: CGRect

    public init(id: UInt32, pid: Int32, layer: Int, alpha: Double, bounds: CGRect) {
        self.id = id
        self.pid = pid
        self.layer = layer
        self.alpha = alpha
        self.bounds = bounds
    }
}

/// Focus follows mouse: the window to focus when the pointer is at `point`. Only the frontmost
/// window under it counts, so a menu, the Dock or an unmanaged window on top blocks the switch.
/// aether's own overlays (its layer-0 windows) and invisible windows are looked through; its
/// menu bar menu is on another layer, so it blocks like any menu.
public func windowUnderPointer(_ point: CGPoint, in stack: [ScreenWindow], ownPid: Int32,
                               focusable: Set<UInt32>, focused: UInt32?) -> UInt32? {
    guard let top = stack.first(where: { !($0.pid == ownPid && $0.layer == 0) && $0.alpha > 0 && $0.bounds.contains(point) }),
          top.layer == 0, focusable.contains(top.id), top.id != focused else { return nil }
    return top.id
}

/// How long after a workspace switch focus that lands on a hidden workspace is the switch's own
/// fallout. The activation of the app aether focused can be reported after the user already
/// switched again, and macOS hands focus to the app below when the destination is empty. Following
/// either drags the user back, or asks the app for a new window here.
public let switchSettleSeconds = 0.5

public func isSwitchSettling(at now: Double, switchedAt: Double?) -> Bool {
    guard let switchedAt else { return false }
    return now - switchedAt < switchSettleSeconds
}

/// Whether a cmd-N menu item opens a window. In apps like WhatsApp or Slack cmd-N starts a chat or
/// a message instead, so aether must not press it. Titles are localized, hence the word lists. Both
/// words are needed, since a user can bind cmd-N to something like "Close Window".
public func isNewWindowItem(title: String) -> Bool {
    let lowered = title.lowercased()
    let new = ["new", "nov", "nuev", "nouv", "neu", "nuov", "nieuw"]
    let window = ["window", "janela", "ventana", "fenêtre", "fenster", "finestra", "venster"]
    return new.contains { lowered.contains($0) } && window.contains { lowered.contains($0) }
}
