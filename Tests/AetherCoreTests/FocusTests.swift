import Testing
@testable import AetherCore

@Test func focusUsesOnlyDestinationWindows() {
    #expect(windowToFocus(in: [1, 2, 3], preferred: 3, remembered: 2) == 3)
    #expect(windowToFocus(in: [1, 2], preferred: 9, remembered: 2) == 2)
    #expect(windowToFocus(in: [1, 2], remembered: 2) == 2)
    #expect(windowToFocus(in: [1, 2], remembered: 9) == 1)
    #expect(windowToFocus(in: [1, 2]) == 1)
    #expect(windowToFocus(in: [], preferred: 1, remembered: 2) == nil)
}

@Test func movedOrClosedRememberedWindowFallsBackWithinWorkspace() {
    var source: [UInt32] = [1, 2]
    var destination: [UInt32] = [3]
    let remembered: UInt32 = 2
    source.removeAll { $0 == remembered }
    destination.append(remembered)
    #expect(windowToFocus(in: source, remembered: remembered) == 1)
    #expect(windowToFocus(in: destination, remembered: remembered) == 2)
    destination.removeAll { $0 == remembered }
    #expect(windowToFocus(in: destination, remembered: remembered) == 3)
    source.removeAll()
    #expect(windowToFocus(in: source, remembered: remembered) == nil)
}

@Test func automaticBackAndForthOnlyTogglesTheRequestedCurrentWorkspace() {
    #expect(workspaceToActivate(requested: 0, current: 0, previous: nil, autoBackAndForth: true) == 0)
    #expect(workspaceToActivate(requested: 1, current: 0, previous: nil, autoBackAndForth: true) == 1)
    #expect(workspaceToActivate(requested: 1, current: 1, previous: 0, autoBackAndForth: true) == 0)
    #expect(workspaceToActivate(requested: 0, current: 0, previous: 1, autoBackAndForth: true) == 1)
    #expect(workspaceToActivate(requested: 1, current: 1, previous: 0, autoBackAndForth: false) == 1)
    #expect(workspaceToActivate(requested: 2, current: 1, previous: 0, autoBackAndForth: true) == 2)
}
