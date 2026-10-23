import Testing
@testable import AetherCore

private let ghostty = WindowFacts(appId: "com.mitchellh.ghostty", appName: "Ghostty", title: "zsh")

@Test func parsesEveryRuleCondition() throws {
    let settings = try Settings.parse("""
    [[on-window-detected]]
        if.app-id = 'com.mitchellh.ghostty'
        if.app-name-regex-substring = 'ghost'
        if.window-title-regex-substring = 'picture-in-picture'
        if.workspace = '3'
        run = ['layout floating', 'move-node-to-workspace 5']
        check-further-callbacks = true

    [[on-window-detected]]
        run = 'layout tiling'
    """)
    #expect(settings.windowRules == [
        try WindowRule(appId: "com.mitchellh.ghostty", appNameRegex: "ghost", titleRegex: "picture-in-picture", workspace: "3",
                       commands: [.floating(true), .moveToWorkspace("5")], checkFurtherCallbacks: true),
        try WindowRule(commands: [.floating(false)]),
    ])
}

@Test func noRulesByDefault() throws {
    #expect(try Settings.parse(defaultConfig).windowRules.isEmpty)
}

@Test(arguments: [
    "[[on-window-detected]]\nif.app-id = 'a'",
    "[[on-window-detected]]\nrun = 'layout accordion'",
    "[[on-window-detected]]\nrun = ['layout floating', 'exec-and-forget say hi']",
    "[[on-window-detected]]\nrun = 'layout floating tiling'",
    "[[on-window-detected]]\nrun = 'move-node-to-workspace nowhere'",
    "[[on-window-detected]]\nif.app-name-regex-substring = '('\nrun = 'layout floating'",
    "[[on-window-detected]]\nif.window-title-regex-substring = '[a'\nrun = 'layout floating'",
]) func invalidRulesAreReported(_ toml: String) {
    #expect(throws: ConfigError.self) { try Settings.parse("workspaces = ['1', '2']\n" + toml) }
}

@Test func unsupportedRuleCommandIsNamed() {
    do {
        _ = try Settings.parse("[[on-window-detected]]\nrun = 'layout accordion'")
        Issue.record("expected a ConfigError")
    } catch {
        #expect("\(error)".contains("layout accordion"))
    }
}

@Test func conditionsAreAnded() throws {
    let both = try WindowRule(appId: "com.mitchellh.ghostty", titleRegex: "zsh", commands: [.floating(true)])
    #expect(both.matches(ghostty, workspace: "1"))
    #expect(!both.matches(WindowFacts(appId: "com.mitchellh.ghostty", appName: "Ghostty", title: "vim"), workspace: "1"))
    #expect(!both.matches(WindowFacts(appId: "other", appName: "Ghostty", title: "zsh"), workspace: "1"))
    #expect(!(try WindowRule(workspace: "2", commands: []).matches(ghostty, workspace: "1")))
    #expect(try WindowRule(commands: []).matches(ghostty, workspace: "1"))
}

@Test func appIdIsExactAndRegexConditionsAreCaseInsensitiveSubstrings() throws {
    #expect(!(try WindowRule(appId: "com.mitchellh", commands: []).matches(ghostty, workspace: "1")))
    #expect(try WindowRule(appNameRegex: "HOST", commands: []).matches(ghostty, workspace: "1"))
    #expect(try WindowRule(appNameRegex: "^gh.*ty$", commands: []).matches(ghostty, workspace: "1"))
    #expect(try WindowRule(titleRegex: "ZS", commands: []).matches(ghostty, workspace: "1"))
    #expect(!(try WindowRule(titleRegex: "^s", commands: []).matches(ghostty, workspace: "1")))
    #expect(!(try WindowRule(titleRegex: "x", commands: []).matches(WindowFacts(appId: "", appName: "", title: ""), workspace: "1")))
}

@Test func firstMatchingRuleWins() throws {
    let rules = [
        try WindowRule(appId: "nope", commands: [.floating(true)]),
        try WindowRule(appId: ghostty.appId, commands: [.moveToWorkspace("2")]),
        try WindowRule(commands: [.moveToWorkspace("3"), .floating(true)]),
    ]
    #expect(evaluateRules(rules, for: ghostty, workspace: "1", floating: false) == RuleOutcome(floating: false, workspace: "2"))
}

@Test func checkFurtherCallbacksContinuesTheWalk() throws {
    let rules = [
        try WindowRule(commands: [.floating(true)], checkFurtherCallbacks: true),
        try WindowRule(appId: ghostty.appId, commands: [.moveToWorkspace("2")]),
        try WindowRule(commands: [.floating(false)]),
    ]
    #expect(evaluateRules(rules, for: ghostty, workspace: "1", floating: false) == RuleOutcome(floating: true, workspace: "2"))
}

@Test func laterRulesSeeTheWorkspaceEarlierOnesChose() throws {
    let rules = [
        try WindowRule(commands: [.moveToWorkspace("2")], checkFurtherCallbacks: true),
        try WindowRule(workspace: "2", commands: [.floating(true)]),
    ]
    #expect(evaluateRules(rules, for: ghostty, workspace: "1", floating: false) == RuleOutcome(floating: true, workspace: "2"))
}

@Test func rulesCanOverrideFloatingApps() throws {
    let tiling = [try WindowRule(commands: [.floating(false)])]
    #expect(evaluateRules(tiling, for: ghostty, workspace: "1", floating: true).floating == false)
    #expect(evaluateRules([], for: ghostty, workspace: "1", floating: true) == RuleOutcome(floating: true, workspace: "1"))
}
