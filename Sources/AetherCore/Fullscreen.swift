/// Where a window was when it left for a native fullscreen Space. macOS takes a moment to bring it
/// back, and the user may have switched workspaces by then, so it can't be placed like a new window.
public struct FullscreenHome: Equatable, Sendable {
    public let workspace: Int
    public let index: Int
    public let floating: Bool

    public init(workspace: Int, index: Int, floating: Bool) {
        self.workspace = workspace
        self.index = index
        self.floating = floating
    }
}

/// The slot `id` holds in `workspaces`, or nil when no workspace holds it.
public func fullscreenHome(of id: UInt32, in workspaces: [[UInt32]], floating: Bool) -> FullscreenHome? {
    for (ws, ids) in workspaces.enumerated() {
        if let index = ids.firstIndex(of: id) { return FullscreenHome(workspace: ws, index: index, floating: floating) }
    }
    return nil
}

/// Puts a window back from a native fullscreen Space in the slot it left, or at the end when that
/// workspace lost windows meanwhile. A window some workspace already holds stays where it is.
public func returnFromFullscreen(_ id: UInt32, to home: FullscreenHome, in workspaces: inout [[UInt32]]) {
    guard workspaces.indices.contains(home.workspace), !workspaces.contains(where: { $0.contains(id) }) else { return }
    workspaces[home.workspace].insert(id, at: min(max(home.index, 0), workspaces[home.workspace].count))
}
