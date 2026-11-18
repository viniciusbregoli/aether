/// A tray menu entry like AeroSpace's: the workspace name followed by the apps on it, each app once,
/// in window order. The app list is cut at `limit` characters so one busy workspace can't widen the menu.
public func trayTitle(workspace: String, apps: [String], limit: Int = 40) -> String {
    var seen = Set<String>()
    let unique = apps.filter { !$0.isEmpty && seen.insert($0).inserted }
    guard !unique.isEmpty else { return workspace }
    let list = unique.joined(separator: ", ")
    return "\(workspace) - " + (list.count > limit ? String(list.prefix(limit - 1)) + "…" : list)
}
