import CoreGraphics
import Foundation
import TOMLDecoder

public enum Layout: String, Codable, Sendable {
    case dwindle, accordion, master, scrolling
}

public enum Action: Equatable, Sendable {
    case workspace(String)
    case moveToWorkspace(String)
    case focusMonitor(MonitorTarget)
    case moveToMonitor(MonitorTarget)
    case move(Direction)
    case resize(CGFloat)
    case layout(Layout)
    case fullscreen
    case backAndForth
    case exec(String)
    case mode(String)
    case toggleFloating
    case resetLayout
    case closeAllButCurrent
    case reload
    case quit
}

public struct ConfigError: Error, CustomStringConvertible {
    public let description: String
}

private let directions: [String: Direction] = ["left": .left, "right": .right, "up": .up, "down": .down]
private let monitorTargets = directions.mapValues(MonitorTarget.direction).merging(["next": .next, "prev": .prev]) { $1 }

/// Parses one binding command. AeroSpace's spellings are accepted too, so bindings can be
/// copied from ~/.aerospace.toml as-is.
public func parseCommand(_ command: String) -> Action? {
    let words = command.split(separator: " ").map(String.init)
    guard let name = words.first else { return nil }
    let args = Array(words.dropFirst())
    switch (name, args.count) {
    case ("workspace", 1): return .workspace(args[0])
    case ("move-node-to-workspace", 1): return .moveToWorkspace(args[0])
    case ("move", 1):
        return directions[args[0]].map(Action.move)
    case ("focus-monitor", 1...), ("move-node-to-monitor", 1...):
        // AeroSpace's --wrap-around is accepted; next and prev always wrap.
        let names = args.filter { $0 != "--wrap-around" }
        guard names.count == 1, let target = monitorTargets[names[0]] else { return nil }
        return name == "focus-monitor" ? .focusMonitor(target) : .moveToMonitor(target)
    case ("resize", 1...2):
        // `resize smart -50` in AeroSpace; aether always resizes along the window's split.
        return Double(args.last!).map { .resize(CGFloat($0)) }
    case ("layout", 1...):
        if args.contains("floating") { return .toggleFloating }
        if args[0] == "accordion" { return .layout(.accordion) }
        if args[0] == "master" { return .layout(.master) }
        if args[0] == "scrolling" { return .layout(.scrolling) }
        if args[0] == "dwindle" || args[0] == "tiles" { return .layout(.dwindle) }
        return nil
    case ("exec-and-forget", 1...):
        return .exec(String(command.dropFirst("exec-and-forget ".count)))
    case ("mode", 1): return .mode(args[0])
    case ("fullscreen", 0): return .fullscreen
    case ("workspace-back-and-forth", 0): return .backAndForth
    case ("toggle-floating", 0): return .toggleFloating
    case ("reset-layout", 0), ("flatten-workspace-tree", 0): return .resetLayout
    case ("close-all-windows-but-current", 0): return .closeAllButCurrent
    case ("reload-config", 0): return .reload
    case ("quit", 0): return .quit
    default: return nil
    }
}

/// Parses "#rrggbb" or "#rrggbbaa" into components in 0...1.
public func parseHexColor(_ hex: String) -> [CGFloat]? {
    let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
    guard digits.count == 6 || digits.count == 8, let value = UInt64(digits, radix: 16) else { return nil }
    let bytes = digits.count == 6 ? (value << 8) | 0xFF : value
    return [24, 16, 8, 0].map { CGFloat((bytes >> $0) & 0xFF) / 255 }
}

/// A `[workspace.<name>]` table: keys left out inherit the global value.
public struct WorkspaceOverride: Equatable, Sendable {
    public var gapsInner: CGFloat?
    public var gapsOuter: CGFloat?
    public var defaultLayout: Layout?
}

public struct Settings: Equatable, Sendable {
    public var workspaces: [String]
    public var gapsInner: CGFloat
    public var gapsOuter: CGFloat
    public var smartGaps: Bool
    public var accordionPadding: CGFloat
    public var defaultLayout: Layout
    public var dwindleSplitRatio: CGFloat
    public var masterRatio: CGFloat
    public var scrollingColumnWidth: CGFloat
    public var workspaceAutoBackAndForth: Bool
    public var focusFollowsMouse: Bool
    public var animationsEnabled: Bool
    public var animationDuration: Double
    public var animationCurve: AnimationCurve
    public var borderEnabled: Bool
    public var borderAnimationEnabled: Bool
    public var borderWidth: CGFloat
    public var borderRadius: CGFloat
    public var borderColors: [[CGFloat]]
    public var borderRotationSeconds: Double
    public var smartBorder: Bool
    public var dimInactive: CGFloat
    public var dimColor: [CGFloat]
    public var floatingApps: Set<String>
    public var reuseWindowApps: Set<String>
    public var windowRules: [WindowRule]
    public var workspaceOverrides: [String: WorkspaceOverride]
    /// mode -> binding ("alt-shift-h") -> actions run in order.
    public var modes: [String: [String: [Action]]]

    public func gapsInner(in workspace: String) -> CGFloat { workspaceOverrides[workspace]?.gapsInner ?? gapsInner }
    public func gapsOuter(in workspace: String) -> CGFloat { workspaceOverrides[workspace]?.gapsOuter ?? gapsOuter }
    public func defaultLayout(in workspace: String) -> Layout { workspaceOverrides[workspace]?.defaultLayout ?? defaultLayout }

    /// Keys missing from `toml` fall back to `defaultConfig`; `[mode.*]` tables replace the
    /// default bindings as a whole, like AeroSpace.
    public static func parse(_ toml: String) throws -> Settings {
        let user: RawConfig
        do {
            user = try TOMLDecoder().decode(RawConfig.self, from: toml)
        } catch {
            throw ConfigError(description: "\(error)")
        }
        // The built-in config is covered by a test, so its keys are all present.
        let base = try! TOMLDecoder().decode(RawConfig.self, from: defaultConfig)

        var modes: [String: [String: [Action]]] = [:]
        for (mode, table) in user.mode ?? base.mode! {
            for (binding, commands) in table.binding {
                modes[mode, default: [:]][binding] = try commands.values.map { command in
                    guard let action = parseCommand(command) else {
                        throw ConfigError(description: "unknown command '\(command)' for \(binding) in mode \(mode)")
                    }
                    return action
                }
            }
        }
        guard modes["main"] != nil else { throw ConfigError(description: "[mode.main.binding] is required") }

        let colors = user.borderColors ?? base.borderColors!
        let parsedColors = try colors.map { hex in
            guard let rgba = parseHexColor(hex) else { throw ConfigError(description: "bad color '\(hex)', use #rrggbb or #rrggbbaa") }
            return rgba
        }

        let workspaces = user.workspaces ?? base.workspaces!
        guard !workspaces.isEmpty else { throw ConfigError(description: "workspaces must not be empty") }
        guard Set(workspaces).count == workspaces.count else { throw ConfigError(description: "workspaces must be unique") }

        let windowRules = try (user.onWindowDetected ?? []).enumerated().map { index, raw in
            do { return try raw.rule(workspaces: workspaces) } catch let error as ConfigError {
                throw ConfigError(description: "on-window-detected #\(index + 1): \(error)")
            }
        }

        var overrides: [String: WorkspaceOverride] = [:]
        for (name, raw) in user.workspace ?? [:] {
            guard workspaces.contains(name) else { throw ConfigError(description: "[workspace.\(name)] is not in workspaces") }
            for (key, value) in [("gaps-inner", raw.gapsInner), ("gaps-outer", raw.gapsOuter)] {
                guard value.map({ $0.isFinite && $0 >= 0 }) ?? true else {
                    throw ConfigError(description: "\(key) in [workspace.\(name)] must be finite and nonnegative")
                }
            }
            overrides[name] = WorkspaceOverride(gapsInner: raw.gapsInner.map { CGFloat($0) }, gapsOuter: raw.gapsOuter.map { CGFloat($0) },
                                                defaultLayout: raw.defaultLayout)
        }

        let duration = user.animationDuration ?? base.animationDuration!
        let width = user.borderWidth ?? base.borderWidth!
        let radius = user.borderRadius ?? base.borderRadius!
        let rotation = user.borderRotationSeconds ?? base.borderRotationSeconds!
        let ratio = user.dwindleSplitRatio ?? base.dwindleSplitRatio!
        for (key, value) in [("animation-duration", duration), ("border-width", width), ("border-radius", radius)] {
            guard value.isFinite, value >= 0 else { throw ConfigError(description: "\(key) must be finite and nonnegative") }
        }
        guard rotation.isFinite, rotation > 0 else { throw ConfigError(description: "border-rotation-seconds must be finite and positive") }
        let masterRatio = user.masterRatio ?? base.masterRatio!
        let columnWidth = user.scrollingColumnWidth ?? base.scrollingColumnWidth!
        guard ratio.isFinite, (0.1...0.9).contains(ratio) else { throw ConfigError(description: "dwindle-split-ratio must be between 0.1 and 0.9") }
        guard masterRatio.isFinite, (0.1...0.9).contains(masterRatio) else { throw ConfigError(description: "master-ratio must be between 0.1 and 0.9") }
        guard columnWidth.isFinite, (0.1...1).contains(columnWidth) else { throw ConfigError(description: "scrolling-column-width must be between 0.1 and 1.0") }
        guard !parsedColors.isEmpty else { throw ConfigError(description: "border-colors must not be empty") }

        let dim = user.dimInactive ?? base.dimInactive!
        guard dim.isFinite, (0...1).contains(dim) else { throw ConfigError(description: "dim-inactive must be between 0 and 1") }
        let dimHex = user.dimColor ?? base.dimColor!
        guard let dimColor = parseHexColor(dimHex) else { throw ConfigError(description: "bad color '\(dimHex)', use #rrggbb or #rrggbbaa") }

        return Settings(
            workspaces: workspaces,
            gapsInner: CGFloat(user.gapsInner ?? base.gapsInner!),
            gapsOuter: CGFloat(user.gapsOuter ?? base.gapsOuter!),
            smartGaps: user.smartGaps ?? base.smartGaps!,
            accordionPadding: CGFloat(user.accordionPadding ?? base.accordionPadding!),
            defaultLayout: user.defaultLayout ?? base.defaultLayout!,
            dwindleSplitRatio: CGFloat(ratio),
            masterRatio: CGFloat(masterRatio),
            scrollingColumnWidth: CGFloat(columnWidth),
            workspaceAutoBackAndForth: user.workspaceAutoBackAndForth ?? base.workspaceAutoBackAndForth!,
            focusFollowsMouse: user.focusFollowsMouse ?? base.focusFollowsMouse!,
            animationsEnabled: user.animationsEnabled ?? base.animationsEnabled!,
            animationDuration: duration,
            animationCurve: user.animationCurve ?? base.animationCurve!,
            borderEnabled: user.borderEnabled ?? base.borderEnabled!,
            borderAnimationEnabled: user.borderAnimationEnabled ?? base.borderAnimationEnabled!,
            borderWidth: CGFloat(width),
            borderRadius: CGFloat(radius),
            borderColors: parsedColors,
            borderRotationSeconds: rotation,
            smartBorder: user.smartBorder ?? base.smartBorder!,
            dimInactive: CGFloat(dim),
            dimColor: dimColor,
            floatingApps: Set(user.floatingApps ?? base.floatingApps!),
            reuseWindowApps: Set(user.reuseWindowApps ?? base.reuseWindowApps!),
            windowRules: windowRules,
            workspaceOverrides: overrides,
            modes: modes)
    }
}

private struct RawConfig: Decodable {
    var workspaces: [String]?
    var gapsInner: Double?
    var gapsOuter: Double?
    var smartGaps: Bool?
    var accordionPadding: Double?
    var defaultLayout: Layout?
    var dwindleSplitRatio: Double?
    var masterRatio: Double?
    var scrollingColumnWidth: Double?
    var workspaceAutoBackAndForth: Bool?
    var focusFollowsMouse: Bool?
    var animationsEnabled: Bool?
    var animationDuration: Double?
    var animationCurve: AnimationCurve?
    var borderEnabled: Bool?
    var borderAnimationEnabled: Bool?
    var borderWidth: Double?
    var borderRadius: Double?
    var borderColors: [String]?
    var borderRotationSeconds: Double?
    var smartBorder: Bool?
    var dimInactive: Double?
    var dimColor: String?
    var floatingApps: [String]?
    var reuseWindowApps: [String]?
    var onWindowDetected: [RawRule]?
    var workspace: [String: RawWorkspace]?
    var mode: [String: RawMode]?

    enum CodingKeys: String, CodingKey {
        case workspaces, workspace, mode
        case onWindowDetected = "on-window-detected"
        case gapsInner = "gaps-inner", gapsOuter = "gaps-outer", accordionPadding = "accordion-padding"
        case smartGaps = "smart-gaps", smartBorder = "smart-border"
        case defaultLayout = "default-layout", dwindleSplitRatio = "dwindle-split-ratio"
        case masterRatio = "master-ratio", scrollingColumnWidth = "scrolling-column-width"
        case workspaceAutoBackAndForth = "workspace-auto-back-and-forth"
        case focusFollowsMouse = "focus-follows-mouse"
        case animationsEnabled = "animations-enabled", animationDuration = "animation-duration", animationCurve = "animation-curve"
        case borderEnabled = "border-enabled", borderAnimationEnabled = "border-animation-enabled"
        case borderWidth = "border-width", borderRadius = "border-radius", borderColors = "border-colors"
        case borderRotationSeconds = "border-rotation-seconds"
        case dimInactive = "dim-inactive", dimColor = "dim-color"
        case floatingApps = "floating-apps", reuseWindowApps = "reuse-window-apps"
    }
}

private struct RawWorkspace: Decodable {
    var gapsInner: Double?
    var gapsOuter: Double?
    var defaultLayout: Layout?

    enum CodingKeys: String, CodingKey {
        case gapsInner = "gaps-inner", gapsOuter = "gaps-outer", defaultLayout = "default-layout"
    }
}

private struct RawRule: Decodable {
    var condition: RawCondition?
    var run: Commands
    var checkFurtherCallbacks: Bool?

    enum CodingKeys: String, CodingKey {
        case condition = "if", run
        case checkFurtherCallbacks = "check-further-callbacks"
    }

    func rule(workspaces: [String]) throws -> WindowRule {
        try WindowRule(appId: condition?.appId, appNameRegex: condition?.appNameRegex, titleRegex: condition?.titleRegex,
                       workspace: condition?.workspace,
                       commands: run.values.map { try parseRuleCommand($0, workspaces: workspaces) },
                       checkFurtherCallbacks: checkFurtherCallbacks ?? false)
    }
}

private struct RawCondition: Decodable {
    var appId: String?
    var appNameRegex: String?
    var titleRegex: String?
    var workspace: String?

    enum CodingKeys: String, CodingKey {
        case appId = "app-id", appNameRegex = "app-name-regex-substring"
        case titleRegex = "window-title-regex-substring", workspace
    }
}

private struct RawMode: Decodable {
    var binding: [String: Commands]
}

/// A binding's value: one command or a list run in order.
private struct Commands: Decodable {
    var values: [String]

    init(from decoder: Decoder) throws {
        // TOMLDecoder can't open a single-value container on an array, so try the list first.
        if var list = try? decoder.unkeyedContainer() {
            values = []
            while !list.isAtEnd { values.append(try list.decode(String.self)) }
        } else {
            values = [try decoder.singleValueContainer().decode(String.self)]
        }
    }
}
