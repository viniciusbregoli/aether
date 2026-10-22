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

