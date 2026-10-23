import CoreGraphics
import Foundation
import Testing
@testable import AetherCore

@Test func defaultConfigParsesWithEveryKey() throws {
    let settings = try Settings.parse(defaultConfig)
    #expect(settings.workspaces.count == 35)
    #expect(settings.gapsInner == 10)
    #expect(settings.reuseWindowApps == ["app.zen-browser.zen"])
    #expect(settings.borderColors.count == 3)
    #expect(settings.animationsEnabled)
    #expect(settings.animationCurve == .easeOutCubic)
    #expect(settings.borderEnabled && settings.borderAnimationEnabled)
    #expect(settings.defaultLayout == .dwindle)
    #expect(settings.dwindleSplitRatio == 0.5)
    #expect(settings.masterRatio == 0.55)
    #expect(settings.scrollingColumnWidth == 0.5)
    #expect(!settings.workspaceAutoBackAndForth)
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

@Test func parsesHyprlandInspiredControls() throws {
    let settings = try Settings.parse("""
    animations-enabled = false
    animation-curve = 'ease-in-out-cubic'
    border-enabled = false
    border-animation-enabled = false
    border-width = 0
    border-radius = 0
    border-colors = ['#ffffff']
    default-layout = 'accordion'
    dwindle-split-ratio = 0.7
    workspace-auto-back-and-forth = true
    """)
    #expect(!settings.animationsEnabled)
    #expect(settings.animationCurve == .easeInOutCubic)
    #expect(!settings.borderEnabled && !settings.borderAnimationEnabled)
    #expect(settings.borderWidth == 0 && settings.borderRadius == 0)
    #expect(settings.borderColors == [[1, 1, 1, 1]])
    #expect(settings.defaultLayout == .accordion)
    #expect(settings.dwindleSplitRatio == 0.7)
    #expect(settings.workspaceAutoBackAndForth)
    for ratio in [0.1, 0.9] {
        #expect(try Settings.parse("dwindle-split-ratio = \(ratio)").dwindleSplitRatio == CGFloat(ratio))
    }
}

@Test(arguments: [
    "animation-duration = -0.1", "animation-duration = inf", "animation-duration = nan",
    "animation-curve = 'spring'", "default-layout = 'spiral'",
    "master-ratio = 0.09", "master-ratio = 0.91", "master-ratio = nan",
    "scrolling-column-width = 0.09", "scrolling-column-width = 1.01", "scrolling-column-width = nan",
    "dwindle-split-ratio = 0.09", "dwindle-split-ratio = 0.91", "dwindle-split-ratio = nan",
    "border-width = -1", "border-radius = inf", "border-rotation-seconds = 0",
    "border-rotation-seconds = -1", "border-rotation-seconds = nan", "border-colors = []",
]) func invalidAppearanceValuesAreReported(_ toml: String) {
    #expect(throws: ConfigError.self) { try Settings.parse(toml) }
}

@Test func parsesWorkspaceOverrides() throws {
    let settings = try Settings.parse("""
    [workspace.3]
        gaps-inner = 0
        gaps-outer = 2
        default-layout = 'accordion'

    [workspace.A]
        gaps-inner = 4
    """)
    #expect(settings.workspaceOverrides == [
        "3": WorkspaceOverride(gapsInner: 0, gapsOuter: 2, defaultLayout: .accordion),
        "A": WorkspaceOverride(gapsInner: 4),
    ])
    #expect(try Settings.parse(defaultConfig).workspaceOverrides.isEmpty)
}

@Test func effectiveValuesFallBackToGlobalKeys() throws {
    let settings = try Settings.parse("""
    gaps-inner = 8
    gaps-outer = 6
    [workspace.3]
        gaps-inner = 0
        default-layout = 'accordion'
    """)
    #expect(settings.gapsInner(in: "3") == 0)
    #expect(settings.gapsOuter(in: "3") == 6)
    #expect(settings.defaultLayout(in: "3") == .accordion)
    #expect(settings.gapsInner(in: "4") == 8)
    #expect(settings.gapsOuter(in: "4") == 6)
    #expect(settings.defaultLayout(in: "4") == .dwindle)
    #expect(settings.gapsInner(in: "missing") == 8)
}

@Test(arguments: [
    "[workspace.nowhere]\ngaps-inner = 1",
    "[workspace.3]\ngaps-inner = -1",
    "[workspace.3]\ngaps-outer = inf",
    "[workspace.3]\ngaps-outer = nan",
    "[workspace.3]\ndefault-layout = 'master'",
    "workspaces = ['a']\n[workspace.3]\ngaps-inner = 1",
]) func invalidWorkspaceOverridesAreReported(_ toml: String) {
    #expect(throws: ConfigError.self) { try Settings.parse(toml) }

@Test func parsesMasterAndScrollingSettings() throws {
    for layout in [Layout.master, .scrolling] {
        #expect(try Settings.parse("default-layout = '\(layout.rawValue)'").defaultLayout == layout)
    }
    let settings = try Settings.parse("master-ratio = 0.7\nscrolling-column-width = 1.0")
    #expect(settings.masterRatio == 0.7)
    #expect(settings.scrollingColumnWidth == 1)
    #expect(try Settings.parse("master-ratio = 0.1").masterRatio == 0.1)
    #expect(try Settings.parse("master-ratio = 0.9").masterRatio == 0.9)
    #expect(try Settings.parse("scrolling-column-width = 0.1").scrollingColumnWidth == 0.1)
}

@Test func layoutRawValuesStayStableInSavedState() throws {
    let old = try JSONDecoder().decode([String: Layout].self, from: Data(#"{"1":"dwindle","2":"accordion"}"#.utf8))
    #expect(old == ["1": .dwindle, "2": .accordion])
    #expect(Layout.master.rawValue == "master" && Layout.scrolling.rawValue == "scrolling")
}

@Test func parsesAerospaceCommands() {
    #expect(parseCommand("resize smart -50") == .resize(-50))
    #expect(parseCommand("resize +50") == .resize(50))
    #expect(parseCommand("layout tiles horizontal vertical") == .layout(.dwindle))
    #expect(parseCommand("layout accordion horizontal vertical") == .layout(.accordion))
    #expect(parseCommand("layout master") == .layout(.master))
    #expect(parseCommand("layout scrolling") == .layout(.scrolling))
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
