import Testing
@testable import AetherCore

@Test func aFullscreenWindowBetweenSpacesIsKeptWhileItStillAnswers() {
    // On another Space: out of sight, not closed.
    #expect(keepsMissingWindow(onSomeSpace: true, inNativeFullscreen: false, elementAlive: true))
    // Mid fullscreen transition WindowServer has it on no Space; dropping it would make it come
    // back as a new window on whatever workspace is focused by then.
    #expect(keepsMissingWindow(onSomeSpace: false, inNativeFullscreen: true, elementAlive: true))
    // Closed while fullscreen, and an ordinary window on no Space: gone.
    #expect(!keepsMissingWindow(onSomeSpace: false, inNativeFullscreen: true, elementAlive: false))
    #expect(!keepsMissingWindow(onSomeSpace: false, inNativeFullscreen: false, elementAlive: true))
}

@Test func focusHoldCoversALateFocusThenLetsGo() {
    var hold = FocusHold()
    hold.hold(2, until: 11)
    // macOS focuses the window once its exit animation ends: still held.
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
