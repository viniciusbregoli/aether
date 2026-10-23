import Carbon.HIToolbox
import CoreGraphics
import Testing
@testable import AetherCore

let screen = CGRect(x: 0, y: 0, width: 1000, height: 600)

@Test func dwindleFillsAreaWithoutOverlap() {
    for count in 1...6 {
        let frames = dwindle(count: count, in: screen, gap: 10)
        #expect(frames.count == count)
        for (i, a) in frames.enumerated() {
            #expect(screen.contains(a))
            for b in frames[(i + 1)...] { #expect(!a.intersects(b)) }
        }
    }
    #expect(dwindle(count: 0, in: screen, gap: 10).isEmpty)
}

@Test func dwindleSplitsLongerSideFirst() {
    let f = dwindle(count: 3, in: screen, gap: 0)
    #expect(f[0] == CGRect(x: 0, y: 0, width: 500, height: 600))
    #expect(f[1] == CGRect(x: 500, y: 0, width: 500, height: 300))
    #expect(f[2] == CGRect(x: 500, y: 300, width: 500, height: 300))
}

@Test func neighborFollowsGeometry() {
    let f = dwindle(count: 3, in: screen, gap: 10)
    #expect(neighbor(of: 0, in: f, .right) == 1)
    #expect(neighbor(of: 0, in: f, .left) == nil)
    #expect(neighbor(of: 1, in: f, .down) == 2)
    #expect(neighbor(of: 2, in: f, .up) == 1)
    #expect(neighbor(of: 2, in: f, .left) == 0)
}

@Test func easingAndLerpHitEndpoints() {
    let a = CGRect(x: 0, y: 0, width: 100, height: 100)
    let b = CGRect(x: 100, y: 50, width: 200, height: 300)
    #expect(easeOutCubic(0) == 0)
    #expect(easeOutCubic(1) == 1)
    #expect(easeOutCubic(2) == 1)
    #expect(lerp(a, b, 0) == a)
    #expect(lerp(a, b, 1) == b)
    #expect(lerp(a, b, 0.5) == CGRect(x: 50, y: 25, width: 150, height: 200))
}

@Test func resizeGrowsFocusedWindow() {
    let before = dwindle(count: 2, in: screen, gap: 10)
    let grow = resized([], index: 0, delta: 50, count: 2, in: screen, gap: 10)
    let after = dwindle(count: 2, in: screen, gap: 10, ratios: grow)
    #expect(abs(after[0].width - (before[0].width + 50)) < 0.001)
    // The last window owns the second half of the last split, so growing it shrinks its sibling.
    let growLast = resized([], index: 1, delta: 50, count: 2, in: screen, gap: 10)
    #expect(abs(dwindle(count: 2, in: screen, gap: 10, ratios: growLast)[1].width - (before[1].width + 50)) < 0.001)
    #expect(resized([0.85], index: 0, delta: 500, count: 2, in: screen, gap: 10) == [0.9])
}

@Test func accordionPeeksNeighbours() {
    let f = accordion(count: 3, focused: 1, in: screen, padding: 30)
    #expect(f[0] == CGRect(x: 0, y: 0, width: 970, height: 600))
    #expect(f[1] == CGRect(x: 30, y: 0, width: 940, height: 600))
    #expect(f[2] == CGRect(x: 30, y: 0, width: 970, height: 600))
    #expect(accordion(count: 1, focused: 0, in: screen, padding: 30) == [screen])
}

@Test func parsesAerospaceBindings() {
    #expect(parseBinding("alt-shift-h")?.modifiers == optionKey | shiftKey)
    #expect(parseBinding("alt-shift-h")?.keyCode == kVK_ANSI_H)
    #expect(parseBinding("esc")?.modifiers == 0)
    #expect(parseBinding("alt-semicolon")?.keyCode == kVK_ANSI_Semicolon)
    #expect(parseBinding("hyper-h") == nil)
    #expect(parseBinding("alt-nope") == nil)
}

@Test func restoreMatchesByIdThenTitleThenApp() {
    let saved = [
        WindowKey(id: 1, bundleId: "term", title: "a"),
        WindowKey(id: 2, bundleId: "web", title: "docs"),
        WindowKey(id: 3, bundleId: "web", title: "mail"),
        WindowKey(id: 4, bundleId: "gone", title: "x"),
    ]
    let alive = [
        WindowKey(id: 1, bundleId: "term", title: "renamed"),
        WindowKey(id: 20, bundleId: "web", title: "other"),
        WindowKey(id: 30, bundleId: "web", title: "docs"),
    ]
    #expect(match(saved: saved, alive: alive) == [0: 1, 1: 30, 2: 20])
    // A recycled id from another app must not steal the slot.
    #expect(match(saved: [WindowKey(id: 9, bundleId: "a", title: "")], alive: [WindowKey(id: 9, bundleId: "b", title: "")]).isEmpty)
}

@Test func unreadableSnapshotsPreserveWindowsUntilDiscoveryRecovers() {
    var windows: [UInt32: String] = [1: "workspace 1", 2: "workspace 2"]
    windows = reconcileWindowSnapshot(previous: windows, discovered: [:], isComplete: false)
    #expect(windows == [1: "workspace 1", 2: "workspace 2"])
    windows = reconcileWindowSnapshot(previous: windows, discovered: [1: "updated", 3: "new"], isComplete: false)
    #expect(windows == [1: "updated", 2: "workspace 2", 3: "new"])
    windows = reconcileWindowSnapshot(previous: windows, discovered: [1: "updated", 3: "new"], isComplete: true)
    #expect(windows == [1: "updated", 3: "new"])
    #expect(reconcileWindowSnapshot(previous: windows, discovered: [:], isComplete: true).isEmpty)
}

@Test func partialSnapshotsRemoveKnownUnmanageableWindows() {
    let previous: [UInt32: String] = [1: "visible", 2: "minimized", 3: "unreadable"]
    let discovered: [UInt32: String] = [1: "updated", 4: "new"]
    #expect(reconcileWindowSnapshot(previous: previous, discovered: discovered, isComplete: false, excluding: [2])
            == [1: "updated", 3: "unreadable", 4: "new"])
    #expect(reconcileWindowSnapshot(previous: previous, discovered: discovered, isComplete: true, excluding: [2])
            == discovered)
}

@Test func easingPresetsAreClampedMonotonicAndDistinct() {
    for curve in AnimationCurve.allCases {
        #expect(curve.value(at: -1) == 0)
        #expect(curve.value(at: 0) == 0)
        #expect(curve.value(at: 1) == 1)
        #expect(curve.value(at: 2) == 1)
        var previous = 0.0
        for step in 0...100 {
            let value = curve.value(at: Double(step) / 100)
            #expect((0...1).contains(value))
            #expect(value >= previous)
            previous = value
        }
    }
    #expect(AnimationCurve.linear.value(at: 0.25) == 0.25)
    #expect(AnimationCurve.easeOutCubic.value(at: 0.25) == 0.578125)
    #expect(AnimationCurve.easeInOutCubic.value(at: 0.25) == 0.0625)
    #expect(AnimationCurve.easeInOutCubic.value(at: 0.75) == 0.9375)
}

@Test func configuredSplitRatioAppliesToEveryMissingSplit() {
    for ratio: CGFloat in [0.1, 0.5, 0.9] {
        for area in [screen, CGRect(x: 20, y: 30, width: 600, height: 1000)] {
            let frames = dwindle(count: 3, in: area, gap: 10, defaultRatio: ratio)
            let (first, rest) = split(area, gap: 10, ratio: ratio)
            let (second, third) = split(rest, gap: 10, ratio: ratio)
            #expect(frames == [first, second, third])
            for (i, frame) in frames.enumerated() {
                #expect(area.contains(frame))
                for other in frames[(i + 1)...] { #expect(!frame.intersects(other)) }
            }
        }
    }
    let frames = dwindle(count: 3, in: screen, gap: 0, ratios: [0.4], defaultRatio: 0.7)
    #expect(frames[0].width == 400)
    #expect(frames[1].width == 420)
    #expect(frames[1].height == 600)
    #expect(frames[2].width == 180)
}

@Test func resizingStartsFromConfiguredRatioAndPreservesOverrides() {
    let initial = dwindle(count: 2, in: screen, gap: 10, defaultRatio: 0.7)
    let ratios = resized([], index: 0, delta: 50, count: 2, in: screen, gap: 10, defaultRatio: 0.7)
    let frames = dwindle(count: 2, in: screen, gap: 10, ratios: ratios, defaultRatio: 0.7)
    #expect(abs(frames[0].width - initial[0].width - 50) < 0.001)
    #expect(resized([0.4], index: 2, delta: 0, count: 3, in: screen, gap: 10, defaultRatio: 0.7) == [0.4, 0.7])
    #expect(resized([], index: 0, delta: 5000, count: 2, in: screen, gap: 10, defaultRatio: 0.7) == [0.9])
}

@Test func parkedWindowsAreRepairedAfterTheirPositionChanges() {
    let corner = CGPoint(x: 999, y: 599)
    #expect(needsParking(origin: CGPoint(x: 40, y: 40), corner: corner, isAnimating: false))
    #expect(!needsParking(origin: CGPoint(x: 999, y: 300), corner: corner, isAnimating: false))
    #expect(!needsParking(origin: CGPoint(x: 300, y: 599), corner: corner, isAnimating: false))
    #expect(!needsParking(origin: CGPoint(x: 1000, y: 400), corner: corner, isAnimating: false))
    #expect(!needsParking(origin: corner, corner: corner, isAnimating: false))
    #expect(!needsParking(origin: CGPoint(x: 998.5, y: 599.5), corner: corner, isAnimating: false))
    #expect(!needsParking(origin: CGPoint(x: 40, y: 40), corner: corner, isAnimating: true))
    #expect(!needsParking(origin: nil, corner: corner, isAnimating: false))
}

@Test func incrementalRestoreDefersUnreadableApps() {
    let saved = [
        WindowKey(id: 1, bundleId: "term", title: "a"),
        WindowKey(id: 2, bundleId: "web", title: "docs"),
        WindowKey(id: 3, bundleId: "web", title: "mail"),
    ]
    // "web" answered only partly: window 2 by id, and an unknown window that must not take slot 3.
    let alive = [
        WindowKey(id: 1, bundleId: "term", title: "a"),
        WindowKey(id: 2, bundleId: "web", title: "docs"),
        WindowKey(id: 40, bundleId: "web", title: "other"),
    ]
    let partial = matchIncrementally(saved: saved, alive: alive, deferring: ["web"])
    #expect(partial.matched == [0: 1, 1: 2])
    #expect(partial.deferred == [2])
    // Once "web" answers fully, the leftover entry falls back to the usual matching.
    let full = matchIncrementally(saved: [saved[2]], alive: [alive[2]], deferring: [])
    #expect(full.matched == [0: 40])
    #expect(full.deferred.isEmpty)
}

@Test func masterFillsAreaWithoutOverlap() {
    for count in 1...6 {
        let frames = master(count: count, in: screen, gap: 10, ratio: 0.55)
        #expect(frames.count == count)
        for (i, a) in frames.enumerated() {
            #expect(screen.contains(a))
            for b in frames[(i + 1)...] { #expect(!a.intersects(b)) }
        }
    }
    #expect(master(count: 0, in: screen, gap: 10, ratio: 0.55).isEmpty)
}

@Test func masterTakesRatioOfWidthAndStacksTheRest() {
    #expect(master(count: 1, in: screen, gap: 10, ratio: 0.55) == [screen])
    #expect(master(count: 2, in: screen, gap: 0, ratio: 0.6) == [
        CGRect(x: 0, y: 0, width: 600, height: 600),
        CGRect(x: 600, y: 0, width: 400, height: 600),
    ])
    let f = master(count: 5, in: screen, gap: 10, ratio: 0.5)
    #expect(f[0] == CGRect(x: 0, y: 0, width: 495, height: 600))
    #expect(f[1...].allSatisfy { $0.minX == 505 && $0.maxX == 1000 && $0.height == 142.5 })
    #expect(f[1...].map(\.minY) == [0, 152.5, 305, 457.5])
}

@Test func masterResizeMovesDividerTowardGrowingWindow() {
    let grown = resizedMasterRatio(0.5, index: 0, delta: 99, count: 3, in: screen, gap: 10)
    #expect(abs(grown - 0.6) < 1e-9)
    let shrunk = resizedMasterRatio(0.5, index: 2, delta: 99, count: 3, in: screen, gap: 10)
    #expect(abs(shrunk - 0.4) < 1e-9)
    #expect(resizedMasterRatio(0.5, index: 0, delta: 5000, count: 3, in: screen, gap: 10) == 0.9)
    #expect(resizedMasterRatio(0.5, index: 0, delta: -5000, count: 3, in: screen, gap: 10) == 0.1)
    #expect(resizedMasterRatio(0.5, index: 0, delta: 99, count: 1, in: screen, gap: 10) == 0.5)
}

@Test func scrollingLaysColumnsOutLeftToRight() {
    #expect(scrolling(count: 0, focused: 0, offset: 0, columnWidth: 0.5, in: screen, gap: 10).frames.isEmpty)
    let one = scrolling(count: 1, focused: 0, offset: 0, columnWidth: 0.5, in: screen, gap: 10)
    #expect(one.frames == [CGRect(x: 0, y: 0, width: 500, height: 600)])
    let four = scrolling(count: 4, focused: 0, offset: 0, columnWidth: 0.5, in: screen, gap: 10)
    #expect(four.frames.map(\.minX) == [0, 510, 1020, 1530])
    #expect(four.frames.allSatisfy { $0.width == 500 && $0.height == 600 })
    let full = scrolling(count: 2, focused: 1, offset: 0, columnWidth: 1, in: screen, gap: 10)
    #expect(full.frames.map(\.minX) == [-1010, 0])
}

@Test func scrollingKeepsViewWhenFocusedColumnIsVisible() {
    let start = scrolling(count: 3, focused: 2, offset: 0, columnWidth: 0.4, in: screen, gap: 10)
    #expect(start.offset == 220)
    let same = scrolling(count: 3, focused: 1, offset: start.offset, columnWidth: 0.4, in: screen, gap: 10)
    #expect(same.offset == 220)
    #expect(same.frames[1].minX == 190)
}

@Test func scrollingMovesAsLittleAsNeeded() {
    // Focus right of the view: the column's right edge lands on the area's edge.
    let right = scrolling(count: 4, focused: 3, offset: 0, columnWidth: 0.5, in: screen, gap: 10)
    #expect(right.offset == 1030)
    #expect(right.frames[3].maxX == 1000)
    // Focus left of the view: the column's left edge lands on the area's edge.
    let left = scrolling(count: 4, focused: 1, offset: right.offset, columnWidth: 0.5, in: screen, gap: 10)
    #expect(left.offset == 510)
    #expect(left.frames[1].minX == 0)
}

@Test func scrollingOffsetStaysOnTheStrip() {
    #expect(scrolling(count: 2, focused: 0, offset: 800, columnWidth: 0.5, in: screen, gap: 10).offset == 0)
    #expect(scrolling(count: 4, focused: 3, offset: 5000, columnWidth: 0.5, in: screen, gap: 10).offset == 1030)
    #expect(scrolling(count: 4, focused: 0, offset: -5, columnWidth: 0.5, in: screen, gap: 10).offset == 0)
    #expect(scrolling(count: 3, focused: 9, offset: 0, columnWidth: 0.5, in: screen, gap: 10).offset == 520)
}

@Test func scrollingRespectsAreaOrigin() {
    let area = CGRect(x: 10, y: 20, width: 1000, height: 600)
    let f = scrolling(count: 3, focused: 2, offset: 0, columnWidth: 0.5, in: area, gap: 10).frames
    #expect(f[2].maxX == area.maxX)
    #expect(f.allSatisfy { $0.minY == 20 && $0.height == 600 })
}

@Test func columnResizeIsClamped() {
    #expect(abs(resizedColumnWidth(0.5, delta: 100, in: screen) - 0.6) < 1e-9)
    #expect(abs(resizedColumnWidth(0.5, delta: -100, in: screen) - 0.4) < 1e-9)
    #expect(resizedColumnWidth(0.5, delta: 5000, in: screen) == 1)
    #expect(resizedColumnWidth(0.5, delta: -5000, in: screen) == 0.1)
}
