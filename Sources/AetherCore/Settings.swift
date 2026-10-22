import CoreGraphics
import Foundation
import TOMLDecoder

public enum Layout: String, Codable, Sendable {
    case dwindle, accordion
}

public enum Action: Equatable, Sendable {
    case workspace(String)
    case moveToWorkspace(String)
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
        let directions: [String: Direction] = ["left": .left, "right": .right, "up": .up, "down": .down]
        return directions[args[0]].map(Action.move)
    case ("resize", 1...2):
        // `resize smart -50` in AeroSpace; aether always resizes along the window's split.
        return Double(args.last!).map { .resize(CGFloat($0)) }
    case ("layout", 1...):
        if args.contains("floating") { return .toggleFloating }
        if args[0] == "accordion" { return .layout(.accordion) }
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

public struct Settings: Equatable, Sendable {
    public var workspaces: [String]
    public var gapsInner: CGFloat
    public var gapsOuter: CGFloat
    public var accordionPadding: CGFloat
    public var animationDuration: Double
    public var borderWidth: CGFloat
    public var borderRadius: CGFloat
    public var borderColors: [[CGFloat]]
    public var borderRotationSeconds: Double
    public var floatingApps: Set<String>
    public var reuseWindowApps: Set<String>
    /// mode -> binding ("alt-shift-h") -> actions run in order.
    public var modes: [String: [String: [Action]]]

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

        return Settings(
            workspaces: user.workspaces ?? base.workspaces!,
            gapsInner: CGFloat(user.gapsInner ?? base.gapsInner!),
            gapsOuter: CGFloat(user.gapsOuter ?? base.gapsOuter!),
            accordionPadding: CGFloat(user.accordionPadding ?? base.accordionPadding!),
            animationDuration: user.animationDuration ?? base.animationDuration!,
            borderWidth: CGFloat(user.borderWidth ?? base.borderWidth!),
            borderRadius: CGFloat(user.borderRadius ?? base.borderRadius!),
            borderColors: parsedColors,
            borderRotationSeconds: user.borderRotationSeconds ?? base.borderRotationSeconds!,
            floatingApps: Set(user.floatingApps ?? base.floatingApps!),
            reuseWindowApps: Set(user.reuseWindowApps ?? base.reuseWindowApps!),
            modes: modes)
    }
}

private struct RawConfig: Decodable {
    var workspaces: [String]?
    var gapsInner: Double?
    var gapsOuter: Double?
    var accordionPadding: Double?
    var animationDuration: Double?
    var borderWidth: Double?
    var borderRadius: Double?
    var borderColors: [String]?
    var borderRotationSeconds: Double?
    var floatingApps: [String]?
    var reuseWindowApps: [String]?
    var mode: [String: RawMode]?

    enum CodingKeys: String, CodingKey {
        case workspaces, mode
        case gapsInner = "gaps-inner", gapsOuter = "gaps-outer", accordionPadding = "accordion-padding"
        case animationDuration = "animation-duration"
        case borderWidth = "border-width", borderRadius = "border-radius", borderColors = "border-colors"
        case borderRotationSeconds = "border-rotation-seconds"
        case floatingApps = "floating-apps", reuseWindowApps = "reuse-window-apps"
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
