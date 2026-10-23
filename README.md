<div align="center">

<img src="assets/icon.png" width="128" height="128" alt="aether icon: tiled glass panes with a glowing focused pane">

# aether

**A tiling window manager for macOS with AeroSpace's model and Hyprland's look.**

Dwindle tiling, animated windows and a glowing border around the focused one, on a stock Mac with System Integrity Protection left on.

[![CI](https://github.com/viniciusbregoli/aether/actions/workflows/ci.yml/badge.svg)](https://github.com/viniciusbregoli/aether/actions/workflows/ci.yml)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)

</div>

## Why

[AeroSpace](https://github.com/nikitabobko/AeroSpace) gets the model right: workspaces that live in the window manager instead of macOS Spaces, keyboard-driven everything, no SIP changes. It also deliberately does no animations or borders. [Hyprland](https://hyprland.org) on Linux has the look, but only because it is the compositor. On macOS the WindowServer is the compositor, and a normal app can't restyle another app's windows.

aether takes AeroSpace's approach and adds the Hyprland feel within that limit: every effect is either a window move through the Accessibility API or a window aether draws itself. [`docs/blueprint.md`](docs/blueprint.md) has the reverse engineering behind it: how AeroSpace works, how yabai and JankyBorders draw their effects, and which ones are possible with SIP on.

## Features

- **Dwindle tiling**, Hyprland's default layout: each new window splits the focused one along its longer side. Accordion, master and scrolling layouts too, and resizing.
- **Workspaces in memory**, 1-9 and A-Z. Windows of hidden workspaces are parked in a screen corner, the AeroSpace way, so switching is instant and doesn't touch macOS Spaces.
- **Animations**: windows glide to their new place, and switching workspaces slides them sideways.
- **Animated gradient border** around the focused window, and optional dimming of the inactive ones.
- **Menu bar item** with the current workspace and a menu to jump between them.
- **Remembers your layout**: restart aether and every window goes back to its workspace.
- **New window where you are**: opening an app whose windows are all on other workspaces gives it a new window on the current one, instead of yanking you away. Apps can opt out (Zen does by default).
- **AeroSpace-compatible config**: bindings use AeroSpace's command names, so you can copy them from `~/.aerospace.toml`.

## Install

aether builds from source with Swift 6 (Xcode 16 or later).

```sh
git clone https://github.com/viniciusbregoli/aether.git
cd aether
swift build -c release
cp .build/release/aether ~/.local/bin/
```

Quit AeroSpace or any other tiling window manager first, since they would fight over the same windows and keys. Then run `aether`. The first run asks for Accessibility access for the app that launched it (your terminal); grant it and run it again.

To quit, press `alt-shift-semicolon` then `q`, use the menu bar item, or Ctrl-C. aether moves every parked window back on screen before exiting.

## Default keys

| Keys | Action |
|---|---|
| `alt-1..9`, `alt-<letter>` | switch workspace |
| `alt-shift-1..9`, `alt-shift-<letter>` | move the focused window to that workspace |
| `alt-shift-h/j/k/l` | swap with the neighbour in that direction |
| `alt-minus` / `alt-equal` | shrink / grow the focused window |
| `alt-slash` / `alt-comma` | dwindle / accordion layout |
| `alt-f` | fullscreen |
| `alt-tab` | previous workspace |
| `alt-shift-semicolon` | service mode: `esc` reload config, `r` reset layout, `f` toggle floating, `backspace` close other windows, `q` quit |

`alt-e`, `alt-f`, `alt-q` and `alt-w` are left out of the workspace keys: `alt-e` opens Finder and `alt-q` quits the focused app.

## Configuration

aether reads `~/.config/aether/config.toml` and writes the defaults there on first run. Keys you leave out fall back to the defaults, and a `[mode.<name>.binding]` table replaces that mode's default bindings. Reload with `alt-shift-semicolon` then `esc`.

```toml
gaps-inner = 10
gaps-outer = 10
animation-duration = 0.22          # 0 makes window movement immediate
border-width = 3
border-colors = ['#64d2ff', '#bf5af2', '#64d2ff']
floating-apps = ['com.apple.finder']
reuse-window-apps = ['app.zen-browser.zen']

[mode.main.binding]
    alt-1 = 'workspace 1'
    alt-shift-1 = 'move-node-to-workspace 1'
    alt-shift-h = 'move left'
    alt-minus = 'resize smart -50'
    alt-enter = 'exec-and-forget open -n -a Ghostty'
```

Appearance and workspace controls retain the existing defaults:

| Setting | Default | Behavior |
| --- | --- | --- |
| `animations-enabled` | `true` | Enable window movement animations and border rotation. |
| `animation-curve` | `'ease-out-cubic'` | Also accepts `'linear'` and `'ease-in-out-cubic'`. |
| `border-enabled` | `true` | Show the focused-window outline. Width zero also hides it. |
| `border-animation-enabled` | `true` | Rotate the gradient; false keeps it static. |
| `dim-inactive` | `0.0` | Opacity from `0.0` to `1.0` of a layer covering every visible window except the focused one. `0` turns dimming off. |
| `dim-color` | `'#000000'` | Color of that layer, `#rrggbb` or `#rrggbbaa` (the alpha multiplies `dim-inactive`). |
| `default-layout` | `'dwindle'` | Also accepts `'accordion'`, `'master'` and `'scrolling'`. Manual and saved workspace layouts take precedence; reset-layout returns to this default. |
| `dwindle-split-ratio` | `0.5` | First/top/left child's fraction, from `0.1` to `0.9`. Saved and manually resized splits take precedence. |
| `master-ratio` | `0.55` | Master layout: the first window's share of the width, from `0.1` to `0.9`. Saved and manually resized ratios take precedence. |
| `scrolling-column-width` | `0.5` | Scrolling layout: each column's share of the width, from `0.1` to `1.0`. Saved and manually resized widths take precedence. |
| `workspace-auto-back-and-forth` | `false` | Selecting the current workspace returns to the previous one. Focus-driven switches are unaffected. |

`animation-duration = 0` makes window movement immediate. `animations-enabled = false` also stops border rotation. In-flight animations keep their original timing and curve; disabling motion during reload finishes their moves, including parking outgoing windows. `border-colors` accepts a single color for a solid outline; `border-radius` rounds only the overlay, not the app's window. `dim-inactive` must be between 0 and 1, and the overlay corners use `border-radius`. Duration, width and radius must be finite and nonnegative, rotation seconds must be finite and positive, and the color list must not be empty.

These controls take ideas from [Hyprland's configuration](https://wiki.hypr.land/0.56.0/Configuring/), while retaining aether's TOML syntax and defaults. The [configuration reference](docs/hyprland-config-reference.md) maps every documented option family and lists the features that need more macOS work. The [visual references](docs/hyprland-inspiration.md) link to the researched dotfiles setups.

### Window rules

`[[on-window-detected]]` tables use AeroSpace's syntax, so rules can be copied from `~/.aerospace.toml`:

```toml
[[on-window-detected]]
    if.app-id = 'com.mitchellh.ghostty'
    if.app-name-regex-substring = 'ghostty'
    if.window-title-regex-substring = 'picture-in-picture'
    if.workspace = '3'
    run = ['layout floating', 'move-node-to-workspace 5']
    check-further-callbacks = false
```

- Every `if.*` condition is optional and they are ANDed. `app-id` is an exact bundle id; the two `*-regex-substring` conditions are case-insensitive regex searches. `if.workspace` is the workspace the window is about to land on, which is the current one.
- `run` takes `layout floating`, `layout tiling` and `move-node-to-workspace <name>`. Anything else, an unknown workspace or an invalid regex makes the config fail to load, naming the culprit.
- Rules run in order and the first match applies and stops, unless it sets `check-further-callbacks = true`. `floating-apps` is applied first, so a rule can override it with `layout tiling`.
- Rules only run on windows aether sees for the first time, not on windows restored from the saved layout. A window sent to another workspace goes there without switching your workspace.
- A window's title can still be empty when it first appears, so `window-title-regex-substring` rules can miss windows that set their title late.

### Workspace settings

`[workspace.<name>]` overrides `gaps-inner`, `gaps-outer` and `default-layout` for one workspace, like Hyprland's workspace rules. Keys you leave out use the global value, an unknown workspace name is a config error, and a layout chosen by hand on that workspace still wins over `default-layout`.

```toml
[workspace.3]
    gaps-inner = 0
    gaps-outer = 0
    default-layout = 'accordion'
```

### Layouts

Switch with `layout dwindle`, `layout accordion`, `layout master` or `layout scrolling` (the default bindings cover the first two; bind the others in `[mode.main.binding]`). The layout is per workspace.

- **Master** is Hyprland's master layout: the first window fills the left `master-ratio` of the width and the others stack on the right, sharing the height equally. `resize` moves the divider (growing the master or any stack window pushes it the right way) and the ratio is saved per workspace. `move` swaps with the neighbour in that direction.
- **Scrolling** is Hyprland's scrolling layout, as in niri and PaperWM: every window is a full-height column of `scrolling-column-width`, left to right. The view scrolls only as far as needed to show the focused column entirely, and stays put while the focused column is already visible. `move left/right` swaps with the previous/next column. `resize` changes the column width of the whole workspace (not one column), from `0.1` to `1.0` of the width, and it is saved per workspace. The scroll position itself is not saved.

Columns outside the screen keep their position on the strip. macOS may refuse to put a window fully off-screen and clamp it to the screen edge, so those columns can peek in at the sides until they are scrolled to.

Commands: `workspace`, `move-node-to-workspace`, `move`, `resize`, `layout`, `fullscreen`, `workspace-back-and-forth`, `exec-and-forget`, `mode`, `toggle-floating`, `reset-layout`, `close-all-windows-but-current`, `reload-config`, `quit`.

## Command line

`aether` with no arguments runs the window manager. With arguments it talks to the running instance over a Unix socket at `/tmp/aether-<username>.sock` (readable only by you), prints the reply and exits with the server's status. It does not need Accessibility access.

```sh
aether workspace 3                  # any command a binding accepts
aether layout accordion
aether list-workspaces              # every workspace name
aether list-workspaces --focused    # the current one
aether list-workspaces --occupied   # those with windows, plus the current one
aether list-windows                 # <window id> | <workspace> | <app> | <title>
aether list-windows --workspace 2
aether list-windows --focused       # windows of the current workspace
aether --help
```

Unknown commands print an error and exit with status 1, and so does any call while aether is not running. Starting a second aether prints a message and exits.

## How it works

- **Windows** are found and moved with the Accessibility API. The one private call is `_AXUIElementGetWindow`, which AeroSpace uses too, to get stable window ids.
- **Animations** write a window's position every display frame (about 0.2 ms per call) and its size only halfway through and at the end, because a resize makes the app relayout. This is the approach [glide](https://github.com/tmandry/glide) and [rift](https://github.com/acsandmann/rift) take, and it needs no SIP changes.
- **The border** is a transparent click-through window that follows the focused one, like [JankyBorders](https://github.com/FelixKratz/JankyBorders). Its rotating gradient runs in Core Animation, so it costs nothing per frame.
- **Dimming** uses one click-through overlay per inactive window, at normal window level and ordered directly above its window, so dialogs and popups of other windows still show on top. Overlays follow the animation frames and are re-ordered after every layout and focus change. The focus border is ordered the same way.
- **Layout state** is saved to `~/Library/Application Support/aether/state.json` after every change and matched back to live windows by id, then by app and title.

## Limitations

- One monitor: everything happens on the main display for now.
- Effects on other apps' windows (rounded corners, blur, transparency) need SIP partly disabled, so aether doesn't do them.
- A window's own child windows (sheets, attached popovers) are in the same stack group, so an inactive window's overlay is drawn over them too.
- Opening an app on a workspace where it has no windows sends it cmd-N, so Cmd-Tab to such an app also opens a window, and apps where cmd-N means something else get that action.

## Credits

Built on what [AeroSpace](https://github.com/nikitabobko/AeroSpace) figured out about macOS window management, styled after [Hyprland](https://hyprland.org), with techniques from [yabai](https://github.com/asmvik/yabai), [JankyBorders](https://github.com/FelixKratz/JankyBorders), [glide](https://github.com/tmandry/glide) and [rift](https://github.com/acsandmann/rift).
