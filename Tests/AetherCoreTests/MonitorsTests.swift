import CoreGraphics
import Testing
@testable import AetherCore

// A 1920x1080 monitor with a laptop screen below it, shifted right (top-left origin).
private let top = CGRect(x: 0, y: 0, width: 1920, height: 1080)
private let below = CGRect(x: 202, y: 1080, width: 1470, height: 956)
private let window = CGSize(width: 800, height: 600)

@Test func monitorTargetsFollowGeometryAndWrap() {
    let side = [CGRect(x: 0, y: 0, width: 100, height: 100), CGRect(x: 100, y: 0, width: 100, height: 100),
                CGRect(x: 200, y: 0, width: 100, height: 100)]
    #expect(monitor(.direction(.right), from: 0, in: side) == 1)
    #expect(monitor(.direction(.left), from: 0, in: side) == nil)
    #expect(monitor(.next, from: 2, in: side) == 0)
    #expect(monitor(.prev, from: 0, in: side) == 2)
    #expect(monitor(.direction(.down), from: 0, in: [top, below]) == 1)
    #expect(monitor(.direction(.up), from: 1, in: [top, below]) == 0)
    #expect(monitor(.next, from: 0, in: [top]) == nil)
}

@Test func workspacesKeepTheirMonitorsAndFillNewOnes() {
    // A monitor that appears gets the first hidden empty workspace.
    #expect(assignWorkspaces(monitors: [1, 2], kept: [1: 0], focused: 0, focusedMonitor: 1, count: 9, occupied: [0, 1, 2])
        == [1: 0, 2: 3])
    // Every workspace occupied: the first hidden one.
    #expect(assignWorkspaces(monitors: [1, 2], kept: [1: 0], focused: 0, focusedMonitor: 1, count: 2, occupied: [0, 1])
        == [1: 0, 2: 1])
    // A monitor that went away takes its workspace with it, and focus lands on the main one.
    #expect(assignWorkspaces(monitors: [1], kept: [1: 0, 2: 3], focused: 3, focusedMonitor: 1, count: 9, occupied: [])
        == [1: 3])
    // Saved assignments come back, and a saved one for a missing monitor is ignored.
    #expect(assignWorkspaces(monitors: [1, 2], kept: [:], preferred: [1: 4, 2: 6, 3: 7], focused: 4, focusedMonitor: 1,
                             count: 9, occupied: [])
        == [1: 4, 2: 6])
    // The focused workspace wins over a saved one on its monitor, which then goes elsewhere.
    #expect(assignWorkspaces(monitors: [1, 2], kept: [:], preferred: [1: 4], focused: 2, focusedMonitor: 1, count: 9,
                             occupied: [0])
        == [1: 2, 2: 1])
    // More monitors than workspaces leaves the extra one without a workspace.
    #expect(assignWorkspaces(monitors: [1, 2], kept: [:], focused: 0, focusedMonitor: 1, count: 1, occupied: []) == [1: 0])
}

@Test func hiddenWorkspacesOpenWhereTheyWereLastShown() {
    #expect(homeMonitor(lastShownOn: 2, monitors: [1, 2], main: 1) == 2)
    // Never shown, or shown on a monitor that is gone: the main one.
    #expect(homeMonitor(lastShownOn: nil, monitors: [1, 2], main: 1) == 1)
    #expect(homeMonitor(lastShownOn: 3, monitors: [1, 2], main: 1) == 1)
}

@Test func parkingHangsOffACornerNoOtherMonitorSees() {
    let visibleTop = CGRect(x: 0, y: 25, width: 1920, height: 1025)
    #expect(parkingSpot(size: window, monitor: visibleTop, others: [below]) == CGPoint(x: 1919, y: 1049))
    #expect(parkingSpot(size: window, monitor: below, others: [top]) == CGPoint(x: 1671, y: 2035))
    // A monitor to the bottom right sends windows off the bottom-left corner instead.
    let right = CGRect(x: 1920, y: 500, width: 1000, height: 1000)
    #expect(parkingSpot(size: window, monitor: top, others: [right]) == CGPoint(x: 1 - 800, y: 1079))
    // Both corners covered: the bottom-right one is the fallback.
    let left = CGRect(x: -1000, y: 500, width: 1000, height: 1000)
    #expect(parkingSpot(size: window, monitor: top, others: [left, right]) == CGPoint(x: 1919, y: 1079))
}

@Test func parkedWindowsAreRepairedOnlyWhenTheyShowMoreThanASliver() {
    let screen = CGRect(x: 0, y: 0, width: 1000, height: 600)
    let parked = { (x: CGFloat, y: CGFloat) in CGRect(x: x, y: y, width: 400, height: 300) }
    #expect(needsParking(frame: parked(40, 40), monitors: [screen], isAnimating: false))
    #expect(needsParking(frame: parked(1200, 40), monitors: [screen, CGRect(x: 1000, y: 0, width: 800, height: 600)],
                         isAnimating: false))
    #expect(!needsParking(frame: parked(999, 599), monitors: [screen], isAnimating: false))
    // An app clamped one coordinate to keep its title bar onscreen.
    #expect(!needsParking(frame: parked(999, 300), monitors: [screen], isAnimating: false))
    #expect(!needsParking(frame: parked(300, 599), monitors: [screen], isAnimating: false))
    #expect(!needsParking(frame: parked(1000, 400), monitors: [screen], isAnimating: false))
    #expect(!needsParking(frame: parked(40, 40), monitors: [screen], isAnimating: true))
    #expect(!needsParking(frame: nil, monitors: [screen], isAnimating: false))
}

@Test func slidesAvoidCrossingOtherMonitors() {
    #expect(slideDistance(for: top, others: []) == CGSize(width: 1920, height: 0))
    #expect(slideDistance(for: top, others: [below]) == CGSize(width: 1920, height: 0))
    #expect(slideDistance(for: below, others: [top]) == CGSize(width: 1470, height: 0))
    let right = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
    #expect(slideDistance(for: top, others: [right]) == CGSize(width: 0, height: 1080))
    #expect(slideDistance(for: right, others: [top]) == CGSize(width: 0, height: 1080))
    #expect(slideDistance(for: top, others: [right, below]) == .zero)
}
