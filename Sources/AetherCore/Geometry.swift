import CoreGraphics

public enum Direction: CaseIterable, Sendable {
    case left, right, up, down
}

/// Hyprland's dwindle layout: each window takes a share of the remaining area (`ratios[k]` of
/// split k, default half), splitting along the longer side, and the rest recurses into the
/// other part. Coordinates are top-left origin (Accessibility API space).
public func dwindle(count: Int, in rect: CGRect, gap: CGFloat, ratios: [CGFloat] = [], defaultRatio: CGFloat = 0.5) -> [CGRect] {
    guard count > 0 else { return [] }
    if count == 1 { return [rect] }
    let (first, rest) = split(rect, gap: gap, ratio: ratios.first ?? defaultRatio)
    return [first] + dwindle(count: count - 1, in: rest, gap: gap, ratios: Array(ratios.dropFirst()), defaultRatio: defaultRatio)
}

func split(_ r: CGRect, gap: CGFloat, ratio: CGFloat) -> (CGRect, CGRect) {
    if r.width >= r.height {
        let w = (r.width - gap) * ratio
        return (CGRect(x: r.minX, y: r.minY, width: w, height: r.height),
                CGRect(x: r.minX + w + gap, y: r.minY, width: r.width - w - gap, height: r.height))
    }
    let h = (r.height - gap) * ratio
    return (CGRect(x: r.minX, y: r.minY, width: r.width, height: h),
            CGRect(x: r.minX, y: r.minY + h + gap, width: r.width, height: r.height - h - gap))
}

/// Ratios after growing window `index` by `delta` points ("resize smart" in AeroSpace terms).
/// Window k owns the first part of split k; the last window owns the second part of the last split.
public func resized(_ ratios: [CGFloat], index: Int, delta: CGFloat, count: Int, in rect: CGRect, gap: CGFloat, defaultRatio: CGFloat = 0.5) -> [CGFloat] {
    guard count > 1, index < count else { return ratios }
    var ratios = ratios + Array(repeating: defaultRatio, count: max(0, count - 1 - ratios.count))
    let k = min(index, count - 2)
    let frames = dwindle(count: count, in: rect, gap: gap, ratios: ratios)
    let area = frames[k...].reduce(frames[k]) { $0.union($1) }
    let length = (area.width >= area.height ? area.width : area.height) - gap
    let sign: CGFloat = index == k ? 1 : -1
    ratios[k] = min(max(ratios[k] + sign * delta / length, 0.1), 0.9)
    return ratios
}

/// Hyprland's master layout: the first window takes `ratio` of the width on the left, the rest
/// share the right side's height equally.
public func master(count: Int, in rect: CGRect, gap: CGFloat, ratio: CGFloat) -> [CGRect] {
    guard count > 0 else { return [] }
    if count == 1 { return [rect] }
    let width = (rect.width - gap) * ratio
    let stackX = rect.minX + width + gap
    let height = (rect.height - gap * CGFloat(count - 2)) / CGFloat(count - 1)
    return [CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height)]
        + (0..<count - 1).map { i in
            CGRect(x: stackX, y: rect.minY + CGFloat(i) * (height + gap), width: rect.maxX - stackX, height: height)
        }
}

/// Master ratio after growing window `index` by `delta` points: growing the master moves the
/// divider right, growing a stack window moves it left.
public func resizedMasterRatio(_ ratio: CGFloat, index: Int, delta: CGFloat, count: Int, in rect: CGRect, gap: CGFloat) -> CGFloat {
    guard count > 1 else { return ratio }
    let sign: CGFloat = index == 0 ? 1 : -1
    return min(max(ratio + sign * delta / (rect.width - gap), 0.1), 0.9)
}

/// Hyprland's scrolling layout: full-height columns of `columnWidth` (a fraction of the area)
/// laid out left to right on a strip that is shifted left by `offset`. The returned offset is
/// the given one moved as little as needed to show column `focused` entirely. Columns outside
/// the area keep their position on the strip, so their frames can lie off-screen.
public func scrolling(count: Int, focused: Int, offset: CGFloat, columnWidth: CGFloat, in rect: CGRect, gap: CGFloat) -> (frames: [CGRect], offset: CGFloat) {
    guard count > 0 else { return ([], 0) }
    let width = rect.width * columnWidth
    let column = { (i: Int) in rect.minX + CGFloat(i) * (width + gap) }
    let strip = column(count - 1) + width - rect.minX
    var offset = min(max(offset, 0), max(strip - rect.width, 0))
    let focusedX = column(min(max(focused, 0), count - 1))
    if focusedX - offset < rect.minX {
        offset = focusedX - rect.minX
    } else if focusedX + width - offset > rect.maxX {
        offset = focusedX + width - rect.maxX
    }
    return ((0..<count).map { CGRect(x: column($0) - offset, y: rect.minY, width: width, height: rect.height) }, offset)
}

/// Column width fraction after growing the focused column by `delta` points.
public func resizedColumnWidth(_ width: CGFloat, delta: CGFloat, in rect: CGRect) -> CGFloat {
    min(max(width + delta / rect.width, 0.1), 1)
}

/// AeroSpace's accordion: every window gets the whole area, and the ones before/after the
/// focused one peek out by `padding` on the left/right.
public func accordion(count: Int, focused: Int, in rect: CGRect, padding: CGFloat) -> [CGRect] {
    (0..<count).map { i in
        let left: CGFloat = i > focused || (i == focused && i > 0) ? padding : 0
        let right: CGFloat = i < focused || (i == focused && i < count - 1) ? padding : 0
        return CGRect(x: rect.minX + left, y: rect.minY, width: rect.width - left - right, height: rect.height)
    }
}

/// Index of the closest frame in `direction` from `frames[index]` that overlaps it
/// on the perpendicular axis, or nil at the edge.
public func neighbor(of index: Int, in frames: [CGRect], _ direction: Direction) -> Int? {
    let cur = frames[index]
    let tolerance: CGFloat = 1
    func distance(_ f: CGRect) -> CGFloat? {
        switch direction {
        case .left where f.maxX <= cur.minX + tolerance && overlaps(f.minY, f.maxY, cur.minY, cur.maxY):
            return cur.minX - f.maxX
        case .right where f.minX >= cur.maxX - tolerance && overlaps(f.minY, f.maxY, cur.minY, cur.maxY):
            return f.minX - cur.maxX
        case .up where f.maxY <= cur.minY + tolerance && overlaps(f.minX, f.maxX, cur.minX, cur.maxX):
            return cur.minY - f.maxY
        case .down where f.minY >= cur.maxY - tolerance && overlaps(f.minX, f.maxX, cur.minX, cur.maxX):
            return f.minY - cur.maxY
        default:
            return nil
        }
    }
    return frames.indices
        .filter { $0 != index }
        .compactMap { i in distance(frames[i]).map { (i, $0) } }
        .min { $0.1 < $1.1 }?.0
}

private func overlaps(_ a0: CGFloat, _ a1: CGFloat, _ b0: CGFloat, _ b1: CGFloat) -> Bool {
    min(a1, b1) - max(a0, b0) > 1
}

public func easeOutCubic(_ t: Double) -> Double {
    let p = 1 - min(max(t, 0), 1)
    return 1 - p * p * p
}

/// WindowServer can move a parked window back onscreen while its workspace stays inactive.
public func needsParking(origin: CGPoint?, corner: CGPoint, isAnimating: Bool) -> Bool {
    guard !isAnimating, let origin else { return false }
    // Apps may clamp the other coordinate to keep their title bar vertically onscreen.
    return origin.x < corner.x - 1 && origin.y < corner.y - 1
}

public enum AnimationCurve: String, Codable, CaseIterable, Sendable {
    case linear
    case easeOutCubic = "ease-out-cubic"
    case easeInOutCubic = "ease-in-out-cubic"

    public func value(at progress: Double) -> Double {
        let t = min(max(progress, 0), 1)
        switch self {
        case .linear: return t
        case .easeOutCubic: return AetherCore.easeOutCubic(t)
        case .easeInOutCubic: return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
        }
    }
}

public func lerp(_ a: CGRect, _ b: CGRect, _ t: Double) -> CGRect {
    let t = CGFloat(t)
    return CGRect(x: a.minX + (b.minX - a.minX) * t,
                  y: a.minY + (b.minY - a.minY) * t,
                  width: a.width + (b.width - a.width) * t,
                  height: a.height + (b.height - a.height) * t)
}
