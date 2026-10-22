# Hyprland configuration reference and aether candidates

Verified 2026-10-22. Candidates 1 through 5 are implemented in aether with the defaults below; candidates 6 through 8 remain proposals. See the [README](../README.md#configuration) for the supported configuration.

## Versions and authoritative entry points

- Latest stable release returned by the [official releases API](https://api.github.com/repos/hyprwm/Hyprland/releases/latest): [v0.56.2](https://github.com/hyprwm/Hyprland/releases/tag/v0.56.2), published 2026-08-05. Its source tree resolves to `efb50993780079460b0cbed1363e2166a2de1d9f`.
- Latest release-specific wiki snapshot available in the [version selector](https://wiki.hypr.land/version-selector/): [0.56.0](https://wiki.hypr.land/0.56.0/Configuring/). Use that snapshot for reproducible syntax and the 0.56.2 source for implementation defaults. The unversioned wiki explicitly describes **Latest git**, which can differ from stable.
- [Configuration index](https://wiki.hypr.land/Configuring/), [start and syntax](https://wiki.hypr.land/Configuring/Start/), [all ordinary options](https://wiki.hypr.land/Configuring/Basics/Variables/). There is no single complete example config: rules, binds, monitors, layouts, gestures, and Lua APIs live on separate pages.
- Since [0.55](https://hypr.land/news/update55/), configuration uses Lua, generally `~/.config/hypr/hyprland.lua`. Legacy hyprlang examples belong to the [0.54 reference](https://wiki.hypr.land/0.54.0/Configuring/). Do not propose legacy `windowrulev2` syntax as current syntax.
- Stable typed option schema: [ConfigValues.cpp][schema]. Stable animation inheritance/defaults: [AnimationTree.cpp][animation-source]. These distinguish engine defaults from values chosen by the generated example config.
- Wiki repository inspected at `c66e8de21f5ecdc4bc5e278e7d94800ea10957af`. Its Markdown has a newer directory organization, so [pinned source](https://github.com/hyprwm/hyprland-wiki/tree/c66e8de21f5ecdc4bc5e278e7d94800ea10957af/content/configuring) and deployed wiki paths differ. The URLs below are the deployed official references verified during research.

Current basic syntax is `hl.config({ general = { border_size = 2 } })`, `hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.2, curve = "default" })`, and `hl.window_rule({ match = { class = "example" }, float = true })`. Aether should retain its existing TOML format; matching useful semantics does not require adopting Lua or Hyprland's complete API.

## Complete category inventory

This inventories documented option families, rather than copying every variable. Ordinary option sections link to their exact heading on the [Variables page][variables]. Prefix its URLs with `/0.56.0` for the stable wiki snapshot. New Git-only entries must not be assumed available in 0.56.2.

| Family | Official reference | Coverage |
| --- | --- | --- |
| Syntax and composition | [Start](https://wiki.hypr.land/Configuring/Start/) | Lua values, config files, reload, require/includes, autocompletion, errors, REPL |
| General | [General](https://wiki.hypr.land/Configuring/Basics/Variables/#general), [Snap](https://wiki.hypr.land/Configuring/Basics/Variables/#snap) | Borders/colors, inner/outer/floating/workspace gaps, layout, focus fallback, border resizing, floating snapping, tearing switch |
| Decoration | [Decoration](https://wiki.hypr.land/Configuring/Basics/Variables/#decoration) | Rounding, active/inactive/fullscreen opacity, dimming, screen shader; blur and its variants, shadow, glow, motion blur; Latest git also documents wobble |
| Animations | [Options](https://wiki.hypr.land/Configuring/Basics/Variables/#animations), [animation reference][animations] | Master enable, wraparound; inherited animation tree, speeds, Bézier/spring curves, styles, border/shadow/glow angle loops |
| Input | [Input](https://wiki.hypr.land/Configuring/Basics/Variables/#input) | XKB layouts/repeat, pointer acceleration/scrolling, follow mouse, focus on close, touchpad, touchdevice, virtualkeyboard, tablet and tablettool |
| Per-device input | [Devices](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/), [per-device variables](https://wiki.hypr.land/Configuring/Basics/Variables/#per-device-input-config) | Device matching/tags, configuration overrides |
| Gesture policy and definitions | [Options](https://wiki.hypr.land/Configuring/Basics/Variables/#gestures), [Gestures](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/) | Workspace swipe thresholds/direction, scrolling gestures; finger counts, modifiers, directions, pinch, actions, Lua callbacks and live gestures |
| Key/mouse binds | [Binds](https://wiki.hypr.land/Configuring/Basics/Binds/), [bind policy](https://wiki.hypr.land/Configuring/Basics/Variables/#binds) | Flags, repeat/release, keycodes, wheel, switches, per-device binds, mouse dragging, global shortcuts, submaps, keyboard layout switching, unbind |
| Commands and selectors | [Dispatchers](https://wiki.hypr.land/Configuring/Basics/Dispatchers/) | Window/workspace/group/cursor operations, selectors, special workspaces, fullscreen modes, execution rules and property setters |
| Window and layer rules | [Window Rules][window-rules] | Match properties, RE2 patterns, static versus dynamic effects, rule ordering, tags; **Layer Rules are a section of this page**, covering layer namespace effects |
| Workspace rules | [Workspace Rules][workspace-rules] | Selectors, monitor/default assignment, gaps, decoration, persistence, empty-workspace command, layout/animation overrides, smart-gap examples |
| Shared layout policy | [Layout](https://wiki.hypr.land/Configuring/Basics/Variables/#layout) | Single-window aspect ratio and tolerance |
| Dwindle | [Dwindle][dwindle-doc] | Binary splits, split persistence/direction, default ratio, bias, mouse placement, layout messages |
| Master | [Master](https://wiki.hypr.land/Configuring/Layouts/Master-Layout/) | Master fraction, orientation, insertion policy, stacking, workspace overrides, messages, focus-master-on-close |
| Scrolling | [Scrolling](https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/) | Column widths, focus/fit/fullscreen policy, wrapping, workspace/window rules and layout messages |
| Monocle and custom layouts | [Monocle](https://wiki.hypr.land/Configuring/Layouts/Monocle-Layout/), [Custom](https://wiki.hypr.land/Configuring/Layouts/Custom-Layouts/) | Full-area stacking/cycling; Lua layout API |
| Groups | [Group](https://wiki.hypr.land/Configuring/Basics/Variables/#group), [Groupbar](https://wiki.hypr.land/Configuring/Basics/Variables/#groupbar) | Tabbed-window policy, locking/insertion, groupbar dimensions/fonts/colors/gradients |
| Outputs | [Monitors](https://wiki.hypr.land/Configuring/Basics/Monitors/) | Selection, mode/refresh/modelines, position/scale/transform, disable/mirror, reserved areas, bit depth, color management, ICC, VRR, workspace assignment |
| Cursor | [Cursor](https://wiki.hypr.land/Configuring/Basics/Variables/#cursor) | Themes, hardware/software cursors, inactivity, warping, zoom, VRR interactions |
| Miscellaneous | [Misc](https://wiki.hypr.land/Configuring/Basics/Variables/#misc) | Branding/background, fullscreen/focus behavior, workspace tracking, application responsiveness, size-limit policy |
| XWayland | [Options](https://wiki.hypr.land/Configuring/Basics/Variables/#xwayland), [guide](https://wiki.hypr.land/Configuring/Advanced-and-Cool/XWayland/) | X11 compatibility, scaling and rendering |
| OpenGL and render | [OpenGL](https://wiki.hypr.land/Configuring/Basics/Variables/#opengl), [Render](https://wiki.hypr.land/Configuring/Basics/Variables/#render) | Explicit synchronization, direct scanout, color/HDR pipelines, commit timing, ICC ramps, scheduling |
| Ecosystem and quirks | [Ecosystem](https://wiki.hypr.land/Configuring/Basics/Variables/#ecosystem), [Quirks](https://wiki.hypr.land/Configuring/Basics/Variables/#quirks) | Integration prompts/news and targeted compatibility workarounds |
| Debug and experimental | [Debug](https://wiki.hypr.land/Configuring/Basics/Variables/#debug), [Experimental](https://wiki.hypr.land/Configuring/Basics/Variables/#experimental) | Logs, damage/debug overlays, watchdog, error display, test/experimental switches; `vfr` moved from misc to debug in 0.55 |
| Input capture and permissions | [Input Capture](https://wiki.hypr.land/Configuring/Basics/Variables/#input-capture), [Permissions](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/) | Capture modifiers/barriers; application permission modes and sensitive protocol grants |
| Startup and environment | [Autostart](https://wiki.hypr.land/Configuring/Basics/Autostart/), [Environment](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/) | Startup/reload/exit commands, environment variables, Hyprland/Aquamarine and toolkit settings |
| Runtime extension and control | [Lua utilities/events/timers](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Expanding-functionality/), [hyprctl](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Using-hyprctl/), [notifications](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Notifications/), [IPC](https://wiki.hypr.land/IPC/), [plugins](https://wiki.hypr.land/Plugins/) | Dynamic configuration/objects, events, timers, sockets, commands and plugins |
| Hardware/session guidance | [Tearing](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/), [Multi-GPU](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Multi-GPU/), [Virtual GPU](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Virtual-GPU/), [Performance](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Performance/), [tips](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Uncommon-tips-and-tricks/), [examples](https://wiki.hypr.land/Configuring/Example-configurations/) | Circumstance-specific settings and operational examples |

Separate programs have their own configuration; they are not additional `hl.config` sections. The [ecosystem index](https://wiki.hypr.land/Hypr-Ecosystem/) links [hyprpaper](https://wiki.hypr.land/Hypr-Ecosystem/hyprpaper/), [hypridle](https://wiki.hypr.land/Hypr-Ecosystem/hypridle/), [hyprlock](https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/), [hyprsunset](https://wiki.hypr.land/Hypr-Ecosystem/hyprsunset/), [hyprlauncher](https://wiki.hypr.land/Hypr-Ecosystem/hyprlauncher/), [hyprcursor](https://wiki.hypr.land/Hypr-Ecosystem/hyprcursor/), [hyprpicker](https://wiki.hypr.land/Hypr-Ecosystem/hyprpicker/), [portal](https://wiki.hypr.land/Hypr-Ecosystem/xdg-desktop-portal-hyprland/), [polkit agent](https://wiki.hypr.land/Hypr-Ecosystem/hyprpolkitagent/), [Qt support](https://wiki.hypr.land/Hypr-Ecosystem/hyprland-qt-support/), [hyprqt6engine](https://wiki.hypr.land/Hypr-Ecosystem/hyprqt6engine/), [system info](https://wiki.hypr.land/Hypr-Ecosystem/hyprsysteminfo/), [password center](https://wiki.hypr.land/Hypr-Ecosystem/hyprpwcenter/), [shutdown](https://wiki.hypr.land/Hypr-Ecosystem/hyprshutdown/), toolkit and development libraries. Packaging configuration also lives under [Nix options](https://wiki.hypr.land/Nix/Options-Overrides/).

## Existing aether equivalents and constraints

Read-only baseline: `/Users/viniciusbregoli/.t3/projects/aether/.claude/worktrees/stack`, clean at `45fb6e8a2563687d018cd2d411eac256f73ffc96`. All local paths below are relative to that checkout.

| Existing setting/behavior | Current implementation and implication |
| --- | --- |
| `gaps-inner = 10`, `gaps-outer = 10` | `WindowManager.workArea/tiledFrames` and `Geometry.dwindle`; real AX geometry. Unlike Hyprland's CSS gaps, aether currently accepts one scalar per key. Do not add duplicate gap aliases. |
| `animation-duration = 0.22`; zero disables movement animation | `Animator.animate/tick` uses AX position every frame, size halfway and at completion. Easing is hardcoded `easeOutCubic`. Duration currently reads mutable global config during flight. |
| `border-width = 3`, `border-radius = 12`, `border-colors`, `border-rotation-seconds = 6` | `Border` owns one click-through floating NSWindow with a conic gradient around the focused window. Radius rounds **only the border path**, not the other application's pixels. Rotation is currently always added, even with a zero duration. |
| `floating-apps`, `reuse-window-apps` | Exact bundle-ID lists. Floating classification runs when windows are first discovered. Reuse list controls activation of an app whose windows are elsewhere; it is not a general rule engine. |
| `workspaces`, bindings, binding modes | Fixed logical workspace slots allocated on startup, parked windows, last-focus memory, explicit back-and-forth action, main/service Carbon hotkeys. Reload retains the startup workspace list. |
| Layouts | Dwindle and accordion already implemented. Default is hardcoded dwindle; dwindle recursively divides the remaining rectangle, not a persistent arbitrary binary tree. Default ratio is hardcoded 0.5. |

Evidence: `Settings.swift:72`, `DefaultConfig.swift:12`, `Animator.swift:16`, `Border.swift:35`, `WindowManager.swift:92/213/217/230/269/351/416`, `Hotkeys.swift:33`, and `Geometry.swift:10/30/81`. Existing pure tests are `SettingsTests.swift`, `GeometryTests.swift`, and `FocusTests.swift`.

SIP-on scope: moving/resizing/focusing accessible windows is plausible through the existing AX code. AX writes can fail or be unsupported by an app, as [Apple documents](https://developer.apple.com/documentation/applicationservices/1460434-axuielementsetattributevalue). Aether's own NSWindow can have [opacity](https://developer.apple.com/documentation/appkit/nswindow/alphavalue) and be [transparent to mouse events](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents). These APIs do not confer compositor control over other applications. Treat third-party opacity, background blur, corner clipping, shaders, shadows, and motion blur as unsupported by this architecture. An overlay can draw a border or dim an area, but does not implement true transparency/blur/rounding of the underlying window. No private app state was read.

## Ranked candidates

All candidates require matching optional fields/CodingKeys in `Settings.swift`, fallback values/comments in `DefaultConfig.swift`, and parser/default/error checks in `SettingsTests.swift`. Defaults below preserve existing behavior, including defaults intentionally different from Hyprland. Adopt a small subset first, preferably 1 through 5.

### 1. Explicit animation switch and selectable easing

- **Hyprland:** `animations.enabled = true`; each `hl.animation` leaf has enabled/speed/curve/style and inherits from its parent. Speed is duration in deciseconds. Engine root defaults: enabled, speed `8` (0.8 s), curve `default`; angle leaves start disabled. Generated example settings can override these. Sources: [stable schema][schema], [tree][animation-source], [syntax][animations].
- **Aether:** propose `animations-enabled = true`, `animation-curve = 'ease-out-cubic'`; retain `animation-duration = 0.22` and its zero-disables contract. Initially support only `linear`, `ease-out-cubic`, and `ease-in-out-cubic`. Disabled means immediate placement, completion and border synchronization still happen. The curve names are aether presets, not Hyprland curve-name compatibility.
- **Changes:** `Animator.Animation` captures effective duration and curve at creation; `animate` handles disabled/zero; `tick` and `rect` use captured values. Add interpolation selection near `Geometry.easeOutCubic`. On reload-to-disabled, finish active animations and run their required completions so outgoing windows get parked.
- **Validation/tests:** finite nonnegative duration; reject unknown curves. Check endpoints, monotonicity and clamping for each preset, disabled/zero placement and completion once, replacement cancellation, and reload during an outgoing workspace animation. Do not divide by zero or change an active animation's clock by reloading duration. Defer arbitrary spring/Bézier configuration and compositor-only fades.

### 2. Border visibility and static versus rotating gradient

- **Hyprland:** `general.border_size = 1`, allowed `0...20`; zero removes its width. `general.col.active_border` defaults opaque white. Workspace `no_border` is an optional override; absent means inherited behavior. `borderangle` defaults disabled, speed `1`, curve `default`; enabled angle style defaults `once`, with explicit `loop` available. Sources: [schema][schema], [tree][animation-source], [workspace rules][workspace-rules], [animations][animations].
- **Aether:** propose `border-enabled = true`, `border-animation-enabled = true`. Keep existing width/colors/radius and six-second rotation unchanged. `border-animation-enabled = false` leaves a static conic gradient; `border-enabled = false` hides the overlay independently of width. Make width zero hide it too. One color should produce a solid border, without requiring arbitrary app-window modification.
- **Changes:** `Border.applyStyle` removes existing `spin` before deciding whether to add it; `Border.show` enforces visibility and width; `WindowManager.updateBorder` and the animator callback must not resurrect a disabled border.
- **Validation/tests:** finite nonnegative width/radius, finite positive rotation seconds, nonempty color list; handle single color explicitly. Check disable/re-enable/reload, no animation when disabled, widths 0/1/3, edge clamping, floating/fullscreen focus, click-through. Keep existing positive rotation speed separate from the new enable switch. Defer inactive-window borders because they require multiple overlays and occlusion handling.

### 3. Default layout

- **Hyprland:** `general.layout = 'dwindle'`; stable choices include dwindle/master/scrolling/monocle and Lua custom layouts in the source. [Schema][schema] and [layout index](https://wiki.hypr.land/Configuring/Layouts/).
- **Aether:** propose `default-layout = 'dwindle'`; accepted values only `dwindle` or `accordion`. Manual/persisted per-workspace layout wins; the default applies when no override exists.
- **Changes:** replace all `layouts[current] ?? .dwindle` and equivalent layout decisions in `WindowManager.tiledFrames`, `resize`, and `swap` with the same effective-layout resolution. Ensure reset-layout returns to the configured default rather than hardcoded dwindle.
- **Validation/tests:** missing key preserves dwindle; accordion actually affects startup, resize eligibility, neighbor selection and reset. Unknown/unsupported layout must error. Verify saved override precedence and reload. Defer adding master or scrolling until their geometry and navigation actually exist.

### 4. Default dwindle split ratio

- **Hyprland:** `dwindle.default_split_ratio = 1.0`, range `0.1...1.9`; `1` represents 50/50. `split_bias = 0` assigns the ratio directionally; its alternative favors the current window. [Stable dwindle reference][dwindle-doc].
- **Aether:** propose `dwindle-split-ratio = 0.5`, meaning the first/top/left child's fraction of the available split after the gap. Accept `0.1...0.9` to match existing interactive resize limits. This is deliberately a fraction, not Hyprland's doubled ratio unit. Saved/user-resized ratios win.
- **Changes:** thread a default ratio through `Geometry.dwindle` recursion and `resized` padding; use it in `WindowManager.tiledFrames/resize`. Only absent ratio entries should use the new default. Do not merely change drawing while leaving interactive resize initialized at 0.5.
- **Validation/tests:** 0.1/0.5/0.9, invalid/nonfinite values, horizontal/vertical splits, gaps, exact area conservation, ratios after repeated resize, saved partial ratio lists, reset/reload. Defer preserve-split/smart-split because this implementation lacks Hyprland's persistent split-tree model.

### 5. Automatic workspace back-and-forth

- **Hyprland 0.56.2:** `binds.workspace_back_and_forth = false`; selecting the current workspace can select the previous one instead. Latest Git docs have expanded this to integer modes; do not import that newer type into a stable comparison. [Stable source][schema].
- **Aether:** propose `workspace-auto-back-and-forth = false`; affects only explicit `workspace NAME` commands targeting the current workspace. Retain the existing `workspace-back-and-forth` action.
- **Changes:** resolve this in `WindowManager.execute(.workspace)` before calling `switchTo`. Do not modify generic `switchTo` to toggle during focus-driven app activation, restore or other internal operations.
- **Validation/tests:** no previous workspace, initial workspace, A→B→B→A, repeated toggles, disabled same-workspace no-op, invalid name, empty workspaces, unchanged move-to-workspace behavior. Existing hotkey infrastructure needs no change.

### 6. Per-workspace gaps and layout defaults

- **Hyprland:** `hl.workspace_rule` can override `gaps_in`, `gaps_out`, layout, border size and decorations. Unspecified values inherit global policy; these optional rule fields have no independent scalar default. [Stable reference][workspace-rules].
- **Aether:** propose optional `[workspace."1"]` tables with `gaps-inner`, `gaps-outer`, `layout`; no tables by default. Initially omit conditional selectors and per-workspace border styles. Effective precedence: explicit manual/persisted layout, workspace layout default, global default.
- **Changes:** parse/validate workspace names; resolve effective values in `WindowManager.workArea/tiledFrames/resize/swap`. Keep fullscreen and reset semantics consistent with those resolutions. Workspace names remain restart-only; values for existing names can reload.
- **Validation/tests:** inheritance, explicit zero, unknown workspace, invalid layout/negative gaps, tiny work areas, tiled-only behavior, manual override/reset and persisted precedence. Test gap values too large for the screen; prevent negative geometry rather than sending invalid AX sizes. Defer smart-gap selectors until a specific policy is defined and tested.

### 7. New-window app placement rules

- **Hyprland:** `hl.window_rule` combines matching props with effects; all supplied props must match. Rules run in order. Static `float`, `workspace`, size and position effects run when a window opens; dynamic effects re-evaluate later. A workspace value can include `silent`. No rules means normal placement. [Stable reference][window-rules].
- **Aether:** propose optional `[[window-rule]]` entries with exact `app-id`, optional `workspace`, optional `floating`; default empty. Apply to newly discovered windows only, silently assigning the logical workspace. Let matching entries apply in order with later specified fields winning. Existing floating-app classification remains the fallback; an explicit floating rule can override it except when AX size is not settable.
- **Changes:** evaluate during `WindowManager.refresh` new-window insertion, using `Window.bundleId`. Preserve restored assignments and manual movement; prevent activation-follow logic from immediately undoing silent placement. Do not reclassify every existing window on reload.
- **Validation/tests:** multiple matches, absent versus explicit false, invalid workspace/app-id, no-match fallback, nonresizable windows, restore precedence, parked/floating placement and pending cmd-N activation. Defer title regex, dynamic rules and arbitrary shell callbacks initially. This is useful but larger than candidates 1 through 5.

### 8. Opt-in focus follows mouse

- **Hyprland:** `input.follow_mouse = 1` by default. Modes: `0` movement leaves focus unchanged; `1` focus follows pointer; `2` keyboard focus changes only on click; `3` pointer and keyboard focus remain separate even on click. Threshold defaults to zero. [Stable variable reference](https://wiki.hypr.land/0.56.0/Configuring/Basics/Variables/#input).
- **Aether:** propose `focus-follows-mouse = false`, implementing only opt-in mode-1-like keyboard focus. Do not expose Hyprland's 0...3 API because independent pointer/keyboard delivery requires compositor control.
- **Changes:** a throttled mouse-move observer in `WindowManager.start`, frontmost-window hit testing followed by existing `focus`, current-workspace/parked filtering, and suppression during animation/drag. Global event monitors alone observe events; they do not change system pointer routing. [Apple hit-testing reference](https://developer.apple.com/documentation/appkit/nswindow/windownumber(at:belowwindowwithwindownumber:)).
- **Validation/tests:** disabled means no focus change or extra AX traffic; overlapping floating/accordion windows, gap traversal, overlays, menus/dialogs, parked 1px slivers, destroyed windows, drag, fullscreen and focus-triggered refresh loops. Feasible with SIP on, but defer from the first small implementation unless interactive verification is available.

## Explicit deferrals

- Third-party active/inactive opacity, blur, true rounding, window shaders, motion blur, wobble and direct scanout/HDR/render scheduling require capabilities aether does not have. Do not add inert TOML keys for them.
- Native macOS Spaces creation/reassignment, per-monitor workspace ownership, XWayland, DRM/GPU selection, Wayland layer/input capture protocols, lockscreen/portal configuration and XKB input policy are not small ports of this single-monitor AX manager.
- Global trackpad gesture interception and 1:1 workspace gestures need separate macOS feasibility work; do not claim Hyprland gesture parity based on an NSEvent monitor.
- Existing configurable gaps, width, colors and duration already change real behavior. Strengthen their boundary validation when touched; avoid duplicating them merely to resemble upstream naming.

## Delivery verification

Compared all six requested Swift files, plus the connected geometry, AX and settings-test code; read no application state/config files. Checked official release metadata, deployed latest/stable wiki navigation and family pages, and stable source defaults. This note changes no source and requires no build. Implementation should use the existing Swift test suite for pure policy/geometry/config behavior and targeted manual AX/overlay checks for runtime effects.

[variables]: https://wiki.hypr.land/Configuring/Basics/Variables/
[schema]: https://github.com/hyprwm/Hyprland/blob/efb50993780079460b0cbed1363e2166a2de1d9f/src/config/values/ConfigValues.cpp
[animation-source]: https://github.com/hyprwm/Hyprland/blob/efb50993780079460b0cbed1363e2166a2de1d9f/src/config/shared/animation/AnimationTree.cpp
[animations]: https://wiki.hypr.land/0.56.0/Configuring/Advanced-and-Cool/Animations/
[window-rules]: https://wiki.hypr.land/0.56.0/Configuring/Basics/Window-Rules/
[workspace-rules]: https://wiki.hypr.land/0.56.0/Configuring/Basics/Workspace-Rules/
[dwindle-doc]: https://wiki.hypr.land/0.56.0/Configuring/Layouts/Dwindle-Layout/
