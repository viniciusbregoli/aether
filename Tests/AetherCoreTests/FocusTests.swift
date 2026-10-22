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
