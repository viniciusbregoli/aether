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
