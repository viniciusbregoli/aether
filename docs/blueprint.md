# aether blueprint

A tiling window manager for macOS: AeroSpace's model, Hyprland's look. Built from a source read of AeroSpace v0.21.3-Beta (commit `d56e1637`), the installed binary, and code reads of yabai, JankyBorders, glide, rift, paneru and Loop. Probes ran on macOS 27.0.1 (26A434), Apple Silicon, with SIP enabled.

## Constraint that shapes everything

macOS WindowServer is the compositor. On macOS 27, a normal process can read another app's window (bounds, alpha, transform), capture it, get notified when it moves, and stack its own windows relative to it. Write calls on foreign windows (`SLSSetWindowAlpha`, `SLSSetWindowTransform`) return 0 but change nothing; read the value back to verify. So every visual effect is drawn by windows aether owns, layered over or around the real ones. The only way to change foreign windows directly is yabai's Dock scripting addition, which needs SIP partially disabled.

Target: **everything works with SIP on**. A SIP-off tier stays optional.

## Core (copy AeroSpace)

| Area | What AeroSpace does | Where |
|---|---|---|
| Window discovery | `NSWorkspace.runningApplications` (regular policy) then `kAXWindowsAttribute` per app; window id via private `_AXUIElementGetWindow`, its only private API | `tree/MacApp.swift:260-318`, `PrivateApi/include/private.h:26` |
| Window layer | `CGWindowListCopyWindowInfo` only to read `kCGWindowLayer` | `windowLevelCache.swift:12-26` |
| Set frame | size, then position, then size again, wrapped in toggling app-level `AXEnhancedUserInterface` off | `MacApp.swift:411-436` |
| Threading | one thread + `CFRunLoop` per app; AX observers live there; cancellable jobs; no AX timeout | `MacApp.swift:65-96`, `runLoop.swift` |
| Events | AX: window created, focused window changed, destroyed, (de)miniaturized, moved, resized. NSWorkspace: launch, activate, hide, unhide, terminate, space change. Global `leftMouseUp` as a backstop because destroy notifications are unreliable | `MacApp.swift:69,376-380`, `GlobalObserver.swift` |
| Refresh | cancellable "heavy" reconcile (focus, windows, normalize, layout) plus "light" sessions for commands | `layout/refresh.swift` |
| Workspaces | in-memory only, no macOS Spaces; hidden windows pushed to a bottom corner (1px stays visible), corner chosen to avoid neighbouring monitors | `tree/MacWindow.swift:123-183`, `refresh.swift:164-201` |
| Tree | Workspace, TilingContainer (h/v, tiles/accordion), Window; weights relative to parent orientation; single-child containers flattened | `tree/`, `layout/layoutRecursive.swift` |
| Popup/dialog detection | heuristics on subrole, window buttons, layer, plus per-app exceptions, regression-tested against AX dumps | `model/AxUiElementWindowType.swift`, `axDumps/` |
| IPC | Unix socket `/tmp/<bundleId>-<user>.sock`, UInt32 version handshake, UInt32 length + JSON frames | `Common/util/NWConnectionEx.swift`, `server.swift` |
| Config | TOML, modes of keybindings, Carbon hotkeys (soffes/HotKey) | `config/` |

Paths are relative to the AeroSpace repo. Things to do differently: add an AX messaging timeout (`AXUIElementSetMessagingTimeout`) so one hung app cannot stall a refresh.

## Effects (the Hyprland part)

| Effect | Technique, SIP on | Reference |
|---|---|---|
| Borders, gradients | owned SkyLight window per target; `SLSRequestNotificationsForWindows` + `SLSRegisterNotifyProc` for move/resize/order/close; one transaction per update that moves, copies level, orders relative to target | JankyBorders `border.c:118-256`, `events.c:113-127` |
| Animated tiling moves | write AX position every display-link tick (0.18 ms avg); resize only at t>=0.5 and at the end (7 ms avg, up to 22 ms); coalesce queued frames | glide `actor/reactor/animation.rs`, rift `animation.rs` |
| Dim inactive | translucent owned overlay ordered above each inactive window, tracked like borders | design idea, not built anywhere found |
| Blur | `SLSSetWindowBackgroundBlurRadius` on owned windows (bar, launcher, overlays) | Loop `SkyLightToolBelt.swift:176` |
| Workspace slide | fullscreen owned overlay showing captures (`SLSHWCaptureWindowList`, needs Screen Recording) sliding while the real windows are swapped instantly underneath | design idea, not built anywhere found |
| Gaps | layout math | AeroSpace |

Not possible with SIP on: rounded corners or opacity on other apps' windows, hiding the real window under a proxy (yabai's animation path). These need the Dock scripting addition and SIP partially disabled.

## Open questions to test before committing to a design

1. Does `SLSHWCaptureWindowList` capture a window that is corner-hidden? The workspace slide depends on it.
2. Are those captures fresh, or do apps stop rendering while offscreen?
3. AX resize cost on slow apps (Electron, Java). The timings above come from one Firefox-based browser.
4. Does the Screen Recording re-approval prompt on recent macOS apply to `SLSHWCaptureWindowList`?
5. Private SkyLight symbols and message ids change between major releases (yabai already branches for Tahoe); plan for a version-checked shim layer.
