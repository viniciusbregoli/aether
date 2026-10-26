import Testing
@testable import AetherCore

@Test func fullscreenHomeRecordsTheSlotAWindowLeaves() {
    let workspaces: [[UInt32]] = [[1, 2, 3], [4]]
    #expect(fullscreenHome(of: 2, in: workspaces, floating: false) == FullscreenHome(workspace: 0, index: 1, floating: false))
    #expect(fullscreenHome(of: 4, in: workspaces, floating: true) == FullscreenHome(workspace: 1, index: 0, floating: true))
    // Already dropped by an earlier refresh: the first record stands.
    #expect(fullscreenHome(of: 9, in: workspaces, floating: false) == nil)
}

@Test func windowBackFromFullscreenReturnsToItsWorkspaceNotTheFocusedOne() {
    // The browser on workspace 0 goes fullscreen and the user switches to workspace 1 meanwhile.
    var workspaces: [[UInt32]] = [[1, 2, 3], [4]]
    let home = fullscreenHome(of: 2, in: workspaces, floating: false)!
    workspaces[0].removeAll { $0 == 2 }
    returnFromFullscreen(2, to: home, in: &workspaces)
    #expect(workspaces == [[1, 2, 3], [4]])
}

@Test func windowBackFromFullscreenFitsAShrunkWorkspace() {
    var workspaces: [[UInt32]] = [[1], [4]]
    returnFromFullscreen(3, to: FullscreenHome(workspace: 0, index: 2, floating: false), in: &workspaces)
    #expect(workspaces == [[1, 3], [4]])
    var emptied: [[UInt32]] = [[], [4]]
    returnFromFullscreen(3, to: FullscreenHome(workspace: 0, index: 2, floating: false), in: &emptied)
    #expect(emptied == [[3], [4]])
}

@Test func windowAlreadyPlacedIsNotReturnedTwice() {
    var workspaces: [[UInt32]] = [[1], [3, 4]]
    returnFromFullscreen(3, to: FullscreenHome(workspace: 0, index: 1, floating: false), in: &workspaces)
    #expect(workspaces == [[1], [3, 4]])
    returnFromFullscreen(5, to: FullscreenHome(workspace: 7, index: 0, floating: false), in: &workspaces)
    #expect(workspaces == [[1], [3, 4]])
}

@Test func focusHoldCoversALateFocusThenLetsGo() {
    var hold = FocusHold()
    hold.hold(2, until: 11)
    // macOS focuses the window after it was put back: still held.
    let late = hold.isHeld(2, at: 10.5)
    let other = hold.isHeld(3, at: 10.5)
    // The user focusing it later switches workspaces as usual, and the hold is gone for good.
    let expired = hold.isHeld(2, at: 11)
    let afterExpiry = hold.isHeld(2, at: 10.5)
    #expect(late)
    #expect(!other)
    #expect(!expired)
    #expect(!afterExpiry)
}
