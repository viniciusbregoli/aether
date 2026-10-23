import CoreGraphics

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
/// stay, then the `preferred` (saved) ones apply, and `focused` is always shown: on
/// `focusedMonitor` unless it already is. The other monitors get the first hidden empty
/// workspace, else the first hidden one.
public func assignWorkspaces(monitors: [UInt32], kept: [UInt32: Int], preferred: [UInt32: Int] = [:],
                             focused: Int, focusedMonitor: UInt32, count: Int, occupied: Set<Int>) -> [UInt32: Int] {
    var result: [UInt32: Int] = [:]
    func take(_ monitor: UInt32, _ ws: Int?) {
        guard let ws, result[monitor] == nil, (0..<count).contains(ws), !result.values.contains(ws) else { return }
        result[monitor] = ws
    }
    for m in monitors { take(m, kept[m]) }
    for m in monitors { take(m, preferred[m]) }
    if !result.values.contains(focused), monitors.contains(focusedMonitor), (0..<count).contains(focused) {
        result[focusedMonitor] = focused
    }
    for m in monitors {
        take(m, (0..<count).first { !result.values.contains($0) && !occupied.contains($0) })
        take(m, (0..<count).first { !result.values.contains($0) })
    }
    return result
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
