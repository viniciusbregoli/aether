import Testing
@testable import AetherCore

@Test func emptyWorkspaceShowsOnlyItsName() {
    #expect(trayTitle(workspace: "1", apps: []) == "1")
    #expect(trayTitle(workspace: "1", apps: [""]) == "1")
}

@Test func listsEachAppOnceInWindowOrder() {
    #expect(trayTitle(workspace: "F", apps: ["Ghostty", "Arc", "Ghostty"]) == "F - Ghostty, Arc")
}

@Test func truncatesLongAppLists() {
    let title = trayTitle(workspace: "2", apps: ["Safari", "Slack", "Mail"], limit: 12)
    #expect(title == "2 - Safari, Sla…")
}

@Test func noRoomForAppsShowsOnlyTheName() {
    #expect(trayTitle(workspace: "3", apps: ["Safari"], limit: 0) == "3")
}
