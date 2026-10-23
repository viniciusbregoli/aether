import CoreGraphics
import Testing
@testable import AetherCore

private let own: Int32 = 1
private let full = CGRect(x: 0, y: 0, width: 100, height: 100)

private func entry(_ id: UInt32, pid: Int32 = 2, layer: Int = 0, alpha: Double = 1, _ bounds: CGRect = full) -> ScreenWindow {
    ScreenWindow(id: id, pid: pid, layer: layer, alpha: alpha, bounds: bounds)
}

private func pick(_ stack: [ScreenWindow], at point: CGPoint = CGPoint(x: 50, y: 50),
                  focusable: Set<UInt32> = [10, 11], focused: UInt32? = nil) -> UInt32? {
    windowUnderPointer(point, in: stack, ownPid: own, focusable: focusable, focused: focused)
}

@Test func frontmostWindowUnderThePointerWins() {
    #expect(pick([entry(10), entry(11)]) == 10)
    #expect(pick([entry(10, CGRect(x: 0, y: 0, width: 40, height: 40)), entry(11)]) == 11)
}

@Test func ownOverlaysAndInvisibleWindowsAreLookedThrough() {
    #expect(pick([entry(90, pid: own, layer: 3), entry(11)]) == 11)
    #expect(pick([entry(91, alpha: 0), entry(10)]) == 10)
}

@Test func otherLayersAndUnmanagedWindowsOnTopBlock() {
    #expect(pick([entry(20, layer: 101), entry(10)]) == nil)
    #expect(pick([entry(21), entry(10)]) == nil)
}

@Test func nothingUnderThePointerOrAlreadyFocusedGivesNil() {
    #expect(pick([entry(10)], at: CGPoint(x: 500, y: 500)) == nil)
    #expect(pick([]) == nil)
    #expect(pick([entry(10)], focused: 10) == nil)
}
