/// Whether a window missing from its app's AX window list is still there. AX only lists windows
/// of the Spaces on screen, so one on another Space is out of sight, not closed. On the way in
/// and out of a native fullscreen Space WindowServer can briefly put the window on no Space at
/// all, so a fullscreen one counts as there while its AX element still answers.
public func keepsMissingWindow(onSomeSpace: Bool, inNativeFullscreen: Bool, elementAlive: Bool) -> Bool {
    onSomeSpace || (inNativeFullscreen && elementAlive)
}

/// Windows focus must not follow for a moment. macOS focuses a window once its fullscreen exit
/// animation ends, which can come after the user switched away from its workspace; that focus is
/// not the user asking to go back there.
public struct FocusHold: Sendable {
    private var deadlines: [UInt32: Double] = [:]

    public init() {}

    public mutating func hold(_ id: UInt32, until deadline: Double) {
        deadlines[id] = deadline
    }

    /// Whether `id` is still held at `now`. Expired holds are forgotten, so later focus changes,
    /// the user's own included, follow as usual.
    public mutating func isHeld(_ id: UInt32, at now: Double) -> Bool {
        deadlines = deadlines.filter { $0.value > now }
        return deadlines[id] != nil
    }
}
