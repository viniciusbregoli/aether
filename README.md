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

- **Dwindle tiling**, Hyprland's default layout: each new window splits the focused one along its longer side. Accordion layout too, and per-window resizing.
- **Workspaces in memory**, 1-9 and A-Z. Windows of hidden workspaces are parked in a screen corner, the AeroSpace way, so switching is instant and doesn't touch macOS Spaces.
- **Animations**: windows glide to their new place, and switching workspaces slides them sideways.
- **Animated gradient border** around the focused window.
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
animation-duration = 0.22          # 0 turns animations off
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

Commands: `workspace`, `move-node-to-workspace`, `move`, `resize`, `layout`, `fullscreen`, `workspace-back-and-forth`, `exec-and-forget`, `mode`, `toggle-floating`, `reset-layout`, `close-all-windows-but-current`, `reload-config`, `quit`.

## How it works

- **Windows** are found and moved with the Accessibility API. The one private call is `_AXUIElementGetWindow`, which AeroSpace uses too, to get stable window ids.
- **Animations** write a window's position every display frame (about 0.2 ms per call) and its size only halfway through and at the end, because a resize makes the app relayout. This is the approach [glide](https://github.com/tmandry/glide) and [rift](https://github.com/acsandmann/rift) take, and it needs no SIP changes.
- **The border** is a transparent click-through window that follows the focused one, like [JankyBorders](https://github.com/FelixKratz/JankyBorders). Its rotating gradient runs in Core Animation, so it costs nothing per frame.
- **Layout state** is saved to `~/Library/Application Support/aether/state.json` after every change and matched back to live windows by id, then by app and title.

## Limitations

- One monitor: everything happens on the main display for now.
- Effects on other apps' windows (rounded corners, blur, transparency) need SIP partly disabled, so aether doesn't do them.
- Opening an app on a workspace where it has no windows sends it cmd-N, so Cmd-Tab to such an app also opens a window, and apps where cmd-N means something else get that action.

## Credits

Built on what [AeroSpace](https://github.com/nikitabobko/AeroSpace) figured out about macOS window management, styled after [Hyprland](https://hyprland.org), with techniques from [yabai](https://github.com/asmvik/yabai), [JankyBorders](https://github.com/FelixKratz/JankyBorders), [glide](https://github.com/tmandry/glide) and [rift](https://github.com/acsandmann/rift).
