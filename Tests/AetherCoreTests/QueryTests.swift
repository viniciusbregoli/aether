import Testing
@testable import AetherCore

@Test func parsesWorkspaceQueries() {
    #expect(parseQuery("list-workspaces") == .workspaces)
    #expect(parseQuery("list-workspaces --focused") == .focusedWorkspace)
    #expect(parseQuery("list-workspaces --occupied") == .occupiedWorkspaces)
}

@Test func parsesWindowQueries() {
    #expect(parseQuery("list-windows") == .windows)
    #expect(parseQuery("list-windows --focused") == .focusedWindows)
    #expect(parseQuery("list-windows --workspace 3") == .windowsIn("3"))
    #expect(parseQuery("  list-windows   --workspace   B ") == .windowsIn("B"))
}

@Test func rejectsMalformedQueries() {
    #expect(parseQuery("") == nil)
    #expect(parseQuery("list-workspaces --bogus") == nil)
    #expect(parseQuery("list-workspaces --focused --occupied") == nil)
    #expect(parseQuery("list-windows --workspace") == nil)
    #expect(parseQuery("list-windows --workspace 1 2") == nil)
    #expect(parseQuery("list-windows 1") == nil)
    #expect(parseQuery("workspace 1") == nil)
}
