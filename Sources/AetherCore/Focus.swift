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
