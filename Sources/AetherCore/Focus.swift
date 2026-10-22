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
