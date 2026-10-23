/// What aether remembers about a window between runs.
public struct WindowKey: Codable, Equatable, Sendable {
    public let id: UInt32
    public let bundleId: String
    public let title: String

    public init(id: UInt32, bundleId: String, title: String) {
        self.id = id
        self.bundleId = bundleId
        self.title = title
    }
}

/// An unreadable AX snapshot cannot prove a window closed. Fresh entries still replace cached ones.
public func reconcileWindowSnapshot<Value>(previous: [UInt32: Value], discovered: [UInt32: Value], isComplete: Bool, excluding excluded: Set<UInt32> = []) -> [UInt32: Value] {
    let snapshot = isComplete ? discovered : previous.merging(discovered) { _, fresh in fresh }
    return snapshot.filter { !excluded.contains($0.key) }
}

/// `match` for a scan where some apps didn't answer. Saved windows of those apps only take exact id
/// matches now; the rest of them are returned as deferred, since the right live window may be one
/// we couldn't read yet and a weaker title or app match would claim the wrong one.
public func matchIncrementally(saved: [WindowKey], alive: [WindowKey], deferring incompleteApps: Set<String>) -> (matched: [Int: UInt32], deferred: [Int]) {
    var matched: [Int: UInt32] = [:]
    var free = alive
    for (i, s) in saved.enumerated() where incompleteApps.contains(s.bundleId) {
        if let j = free.firstIndex(where: { $0.id == s.id && $0.bundleId == s.bundleId }) {
            matched[i] = free.remove(at: j).id
        }
    }
    let ready = saved.indices.filter { !incompleteApps.contains(saved[$0].bundleId) }
    for (k, id) in match(saved: ready.map { saved[$0] }, alive: free) { matched[ready[k]] = id }
    let deferred = saved.indices.filter { matched[$0] == nil && incompleteApps.contains(saved[$0].bundleId) }
    return (matched, deferred)
}

/// Pairs saved windows with live ones. Window ids survive an aether restart but not an app
/// restart, so fall back to same app and title, then same app, each live window used once.
/// Returns saved index -> live window id.
public func match(saved: [WindowKey], alive: [WindowKey]) -> [Int: UInt32] {
    var result: [Int: UInt32] = [:]
    var free = alive
    let passes: [(WindowKey, WindowKey) -> Bool] = [
        { $0.id == $1.id && $0.bundleId == $1.bundleId },
        { $0.bundleId == $1.bundleId && $0.title == $1.title },
        { $0.bundleId == $1.bundleId },
    ]
    for same in passes {
        for (i, s) in saved.enumerated() where result[i] == nil {
            if let j = free.firstIndex(where: { same(s, $0) }) {
                result[i] = free.remove(at: j).id
            }
        }
    }
    return result
}
