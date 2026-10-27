import CoreGraphics
import Foundation

/// One `workspace-to-monitor-force-assignment` pattern, in AeroSpace's syntax.
public enum MonitorPattern: Equatable, Sendable {
    /// 1-based, counting monitors left to right.
    case index(Int)
    case main
    /// The monitor that isn't the main one, when there are exactly two.
    case secondary
    /// A case-insensitive regex searched for in the monitor's name.
    case name(String)
}

/// The monitor picked by the first of `patterns` that matches a connected one. `monitors` are
/// ordered left to right.
public func forcedMonitor(_ patterns: [MonitorPattern], monitors: [(id: UInt32, name: String)], main: UInt32) -> UInt32? {
    for pattern in patterns {
        switch pattern {
        case .index(let n):
            if monitors.indices.contains(n - 1) { return monitors[n - 1].id }
        case .main:
            if monitors.contains(where: { $0.id == main }) { return main }
        case .secondary:
            if monitors.count == 2, let other = monitors.first(where: { $0.id != main }) { return other.id }
        case .name(let regex):
            if let match = monitors.first(where: { $0.name.range(of: regex, options: [.regularExpression, .caseInsensitive]) != nil }) {
                return match.id
            }
        }
    }
    return nil
}

/// What `focus-monitor` and `move-node-to-monitor` point at.
public enum MonitorTarget: Equatable, Sendable {
    case direction(Direction)
    case next, prev
}

/// Index of the monitor `target` points at from monitor `index`. `frames` are ordered left to
/// right; next and prev wrap around.
public func monitor(_ target: MonitorTarget, from index: Int, in frames: [CGRect]) -> Int? {
    guard frames.count > 1, frames.indices.contains(index) else { return nil }
    switch target {
    case .direction(let direction): return neighbor(of: index, in: frames, direction)
    case .next: return (index + 1) % frames.count
    case .prev: return (index + frames.count - 1) % frames.count
    }
}

/// Which workspace each monitor shows, as display id -> workspace index. Assignments in `kept`
/// stay, then the `preferred` (saved) ones apply, and `focused` is always shown: on its
/// `forced` monitor, else on `focusedMonitor`, unless it already is. The other monitors get the
/// first hidden empty workspace, else the first hidden one. A workspace in `forced` (workspace ->
/// display id) only ever goes to that monitor.
public func assignWorkspaces(monitors: [UInt32], kept: [UInt32: Int], preferred: [UInt32: Int] = [:],
                             focused: Int, focusedMonitor: UInt32, count: Int, occupied: Set<Int>,
                             forced: [Int: UInt32] = [:]) -> [UInt32: Int] {
    var result: [UInt32: Int] = [:]
    func allowed(_ ws: Int, on monitor: UInt32) -> Bool {
        (0..<count).contains(ws) && !result.values.contains(ws) && (forced[ws].map { $0 == monitor } ?? true)
    }
    func take(_ monitor: UInt32, _ ws: Int?) {
        guard let ws, result[monitor] == nil, allowed(ws, on: monitor) else { return }
        result[monitor] = ws
    }
    for m in monitors { take(m, kept[m]) }
    for m in monitors { take(m, preferred[m]) }
    let target = forced[focused] ?? focusedMonitor
    if !result.values.contains(focused), monitors.contains(target), (0..<count).contains(focused) {
        result[target] = focused
    }
    for m in monitors {
        take(m, (0..<count).first { allowed($0, on: m) && !occupied.contains($0) })
        take(m, (0..<count).first { allowed($0, on: m) })
    }
    return result
}

/// The monitor a hidden workspace opens on, the AeroSpace way: its `forced` one, else the one it
/// was last shown on while that monitor is connected, else the main one.
public func homeMonitor(forced: UInt32? = nil, lastShownOn last: UInt32?, monitors: [UInt32], main: UInt32) -> UInt32 {
    forced ?? last.flatMap { monitors.contains($0) ? $0 : nil } ?? main
}

/// Where a hidden window of `size` waits: macOS won't put a window fully off-screen, so it hangs
/// off the bottom-right corner of `monitor` with a 1px sliver left on it, or off the bottom-left
/// one when hanging right would cover one of the `others` monitors.
public func parkingSpot(size: CGSize, monitor: CGRect, others: [CGRect]) -> CGPoint {
    let right = CGPoint(x: monitor.maxX - 1, y: monitor.maxY - 1)
    let left = CGPoint(x: monitor.minX + 1 - size.width, y: monitor.maxY - 1)
    let coversOther = { (origin: CGPoint) in others.contains { $0.intersects(CGRect(origin: origin, size: size)) } }
    return coversOther(right) && !coversOther(left) ? left : right
}

/// WindowServer can move a parked window back onscreen while its workspace stays inactive. A
/// parked window shows at most a sliver; apps may clamp one coordinate to keep their title bar
/// onscreen, which leaves a strip one point wide or tall, so only more than that counts.
public func needsParking(frame: CGRect?, monitors: [CGRect], isAnimating: Bool) -> Bool {
    guard !isAnimating, let frame else { return false }
    return monitors.contains { screen in
        let visible = frame.intersection(screen)
        return !visible.isNull && visible.width > 2 && visible.height > 2
    }
}

/// How far windows slide when `monitor` switches workspace: its width sideways, or its height
/// vertically when another monitor would see them pass on the side, or nothing when both would.
public func slideDistance(for monitor: CGRect, others: [CGRect]) -> CGSize {
    func clear(_ dx: CGFloat, _ dy: CGFloat) -> Bool {
        !others.contains { $0.intersects(monitor.offsetBy(dx: dx, dy: dy)) || $0.intersects(monitor.offsetBy(dx: -dx, dy: -dy)) }
    }
    if clear(monitor.width, 0) { return CGSize(width: monitor.width, height: 0) }
    if clear(0, monitor.height) { return CGSize(width: 0, height: monitor.height) }
    return .zero
}
