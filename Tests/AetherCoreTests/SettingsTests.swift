import CoreGraphics
import Testing
@testable import AetherCore

@Test func defaultConfigParsesWithEveryKey() throws {
    let settings = try Settings.parse(defaultConfig)
    #expect(settings.workspaces.count == 35)
    #expect(settings.gapsInner == 10)
    #expect(settings.reuseWindowApps == ["app.zen-browser.zen"])
    #expect(settings.borderColors.count == 3)
    #expect(settings.modes["main"]?["alt-1"] == [.workspace("1")])
    #expect(settings.modes["main"]?["alt-h"] == [.workspace("H")])
    #expect(settings.modes["main"]?["alt-shift-e"] == [.moveToWorkspace("E")])
    #expect(settings.modes["main"]?["alt-q"] == [.exec(#"osascript -e 'tell application "System Events" to keystroke "q" using command down'"#)])
    #expect(settings.modes["service"]?["esc"] == [.reload, .mode("main")])
}

@Test func missingKeysFallBackToDefaults() throws {
    let settings = try Settings.parse("gaps-inner = 4\nanimation-duration = 0")
    #expect(settings.gapsInner == 4)
    #expect(settings.animationDuration == 0)
    #expect(settings.gapsOuter == 10)
    #expect(settings.modes == (try Settings.parse(defaultConfig)).modes)
}

@Test func modeTablesReplaceDefaultBindings() throws {
    let settings = try Settings.parse("""
    [mode.main.binding]
    alt-enter = 'exec-and-forget open -n -a Ghostty'
    """)
    #expect(settings.modes == ["main": ["alt-enter": [.exec("open -n -a Ghostty")]]])
}

@Test func invalidConfigIsReported() {
    #expect(throws: ConfigError.self) { try Settings.parse("[mode.main.binding]\nalt-x = 'teleport'") }
    #expect(throws: ConfigError.self) { try Settings.parse("[mode.service.binding]\nesc = 'mode main'") }
    #expect(throws: ConfigError.self) { try Settings.parse("border-colors = ['blue']") }
    #expect(throws: ConfigError.self) { try Settings.parse("gaps-inner = ") }
}

@Test func workspaceNamesMustBeNonemptyAndUnique() throws {
    #expect(throws: ConfigError.self) { try Settings.parse("workspaces = []") }
    #expect(throws: ConfigError.self) { try Settings.parse("workspaces = ['1', '1']") }
    #expect(throws: ConfigError.self) { try Settings.parse("workspaces = ['1', '2', '1']") }
    #expect(try Settings.parse("workspaces = ['code']").workspaces == ["code"])
    #expect(try Settings.parse("workspaces = ['code', 'Code']").workspaces == ["code", "Code"])
}

@Test func parsesAerospaceCommands() {
    #expect(parseCommand("resize smart -50") == .resize(-50))
    #expect(parseCommand("resize +50") == .resize(50))
    #expect(parseCommand("layout tiles horizontal vertical") == .layout(.dwindle))
    #expect(parseCommand("layout accordion horizontal vertical") == .layout(.accordion))
    #expect(parseCommand("layout floating tiling") == .toggleFloating)
    #expect(parseCommand("flatten-workspace-tree") == .resetLayout)
    #expect(parseCommand("move sideways") == nil)
    #expect(parseCommand("") == nil)
}

@Test func parsesHexColors() {
    #expect(parseHexColor("#ff0000") == [1, 0, 0, 1])
    #expect(parseHexColor("00ff0080")?[3] == CGFloat(0x80) / 255)
    #expect(parseHexColor("#fff") == nil)
    #expect(parseHexColor("#gggggg") == nil)
}
