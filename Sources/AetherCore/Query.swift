/// Read-only requests the command line can make, as opposed to `Action`s that change state.
public enum Query: Equatable, Sendable {
    case workspaces
    case focusedWorkspace
    case occupiedWorkspaces
    case windows
    case windowsIn(String)
    case focusedWindows
}

/// Parses `list-workspaces` and `list-windows` with their flags. Anything else is nil.
public func parseQuery(_ command: String) -> Query? {
    let words = command.split(separator: " ").map(String.init)
    guard let name = words.first else { return nil }
    let args = Array(words.dropFirst())
    switch (name, args) {
    case ("list-workspaces", []): return .workspaces
    case ("list-workspaces", ["--focused"]): return .focusedWorkspace
    case ("list-workspaces", ["--occupied"]): return .occupiedWorkspaces
    case ("list-windows", []): return .windows
    case ("list-windows", ["--focused"]): return .focusedWindows
    case ("list-windows", _) where args.count == 2 && args[0] == "--workspace": return .windowsIn(args[1])
    default: return nil
    }
}
