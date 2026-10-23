import Foundation

public enum RuleCommand: Equatable, Sendable {
    case floating(Bool)
    case moveToWorkspace(String)
}

/// One AeroSpace `[[on-window-detected]]` table. A condition left unset matches every window.
/// Regexes stay as strings (the type is Equatable); parsing already proved they compile.
public struct WindowRule: Equatable, Sendable {
    public var appId: String?
    public var appNameRegex: String?
    public var titleRegex: String?
    public var workspace: String?
    public var commands: [RuleCommand]
    public var checkFurtherCallbacks: Bool

    public init(appId: String? = nil, appNameRegex: String? = nil, titleRegex: String? = nil, workspace: String? = nil,
                commands: [RuleCommand], checkFurtherCallbacks: Bool = false) throws {
        for pattern in [appNameRegex, titleRegex].compactMap({ $0 }) {
            do { _ = try NSRegularExpression(pattern: pattern) } catch {
                throw ConfigError(description: "bad regex '\(pattern)'")
            }
        }
        self.appId = appId
        self.appNameRegex = appNameRegex
        self.titleRegex = titleRegex
        self.workspace = workspace
        self.commands = commands
        self.checkFurtherCallbacks = checkFurtherCallbacks
    }

    func matches(_ window: WindowFacts, workspace current: String) -> Bool {
        (appId.map { $0 == window.appId } ?? true)
            && (workspace.map { $0 == current } ?? true)
            && (appNameRegex.map { contains($0, in: window.appName) } ?? true)
            && (titleRegex.map { contains($0, in: window.title) } ?? true)
    }
}

/// What the rules can see of a newly detected window.
public struct WindowFacts: Equatable, Sendable {
    public var appId: String
    public var appName: String
    public var title: String

    public init(appId: String, appName: String, title: String) {
        self.appId = appId
        self.appName = appName
        self.title = title
    }
}

public struct RuleOutcome: Equatable, Sendable {
    public var floating: Bool
    public var workspace: String
}

/// Parses one `run` command. Only the commands that make sense for a window that just appeared
/// are accepted, so a typo fails at load time instead of being ignored.
public func parseRuleCommand(_ command: String, workspaces: [String]) throws -> RuleCommand {
    let words = command.split(separator: " ").map(String.init)
    switch (words.first, words.count) {
    case ("layout", 2) where words[1] == "floating": return .floating(true)
    case ("layout", 2) where words[1] == "tiling": return .floating(false)
    case ("move-node-to-workspace", 2):
        guard workspaces.contains(words[1]) else { throw ConfigError(description: "unknown workspace '\(words[1])' in '\(command)'") }
        return .moveToWorkspace(words[1])
    default:
        throw ConfigError(description: "unsupported run command '\(command)', use 'layout floating', 'layout tiling' or 'move-node-to-workspace <name>'")
    }
}

/// The first matching rule applies and stops the walk unless it sets `check-further-callbacks`.
/// `if.workspace` sees the workspace as earlier rules left it.
public func evaluateRules(_ rules: [WindowRule], for window: WindowFacts, workspace: String, floating: Bool) -> RuleOutcome {
    var outcome = RuleOutcome(floating: floating, workspace: workspace)
    for rule in rules where rule.matches(window, workspace: outcome.workspace) {
        for command in rule.commands {
            switch command {
            case .floating(let value): outcome.floating = value
            case .moveToWorkspace(let name): outcome.workspace = name
            }
        }
        if !rule.checkFurtherCallbacks { break }
    }
    return outcome
}

private func contains(_ pattern: String, in text: String) -> Bool {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return false }
    return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
}
