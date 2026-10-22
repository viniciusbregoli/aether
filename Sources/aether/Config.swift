import AetherCore
import AppKit

enum Layout: String, Codable { case dwindle, accordion }

enum Action {
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

// Ported from ~/.aerospace.toml, minus the workspace-to-monitor assignment (aether is single-monitor).
// shortcut: compiled-in settings, load them from a TOML file once they stabilize.
enum Config {
    static let workspaces = (1...9).map(String.init) + "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init)
    static let gapsIn: CGFloat = 10
    static let gapsOut: CGFloat = 10
    static let accordionPadding: CGFloat = 30
    static let floatingApps: Set<String> = ["com.apple.finder", "com.apple.QuickTimePlayerX", "com.TablePro"]
    /// Apps that jump to their existing window when opened from another workspace, instead of
    /// getting a new window on the current one.
    static let reuseWindowApps: Set<String> = ["app.zen-browser.zen"]

    static let animationDuration = 0.22
    static let borderWidth: CGFloat = 3
    static let borderRadius: CGFloat = 12
    static let borderColors: [NSColor] = [.systemCyan, .systemPurple, .systemCyan]
    static let borderRotationSeconds = 6.0

    static let modes: [String: [String: [Action]]] = [
        "main": mainBindings,
        "service": [
            "esc": [.reload, .mode("main")],
            "r": [.resetLayout, .mode("main")],
            "f": [.toggleFloating, .mode("main")],
            "backspace": [.closeAllButCurrent, .mode("main")],
            // Not in the AeroSpace config: alt-shift-e is taken by "move to workspace E" there.
            "q": [.quit],
        ],
    ]

    private static var mainBindings: [String: [Action]] {
        var b: [String: [Action]] = [
            "alt-slash": [.layout(.dwindle)],
            "alt-comma": [.layout(.accordion)],
            "alt-shift-h": [.move(.left)],
            "alt-shift-j": [.move(.down)],
            "alt-shift-k": [.move(.up)],
            "alt-shift-l": [.move(.right)],
            "alt-minus": [.resize(-50)],
            "alt-equal": [.resize(50)],
            "alt-e": [.exec("open -a /System/Library/CoreServices/Finder.app")],
            "alt-f": [.fullscreen],
            "alt-q": [.exec(#"osascript -e 'tell application "System Events" to keystroke "q" using command down'"#)],
            "alt-tab": [.backAndForth],
            "alt-shift-semicolon": [.mode("service")],
        ]
        for name in (1...9).map(String.init) + "abcdghijklmnoprstuvxyz".map(String.init) {
            b["alt-\(name)"] = [.workspace(name.uppercased())]
        }
        for name in (1...9).map(String.init) + "abcdefgimnopqrstuvwxyz".map(String.init) {
            b["alt-shift-\(name)"] = [.moveToWorkspace(name.uppercased())]
        }
        return b
    }
}
