<img src="assets/icon.png" width="96" height="96" alt="aether icon">

# aether

A tiling window manager for macOS with AeroSpace's model and Hyprland's look, built to work with SIP enabled. See [docs/blueprint.md](docs/blueprint.md) for how it works and what is possible on macOS.

## What it does

- Dwindle tiling (Hyprland's default layout) with inner and outer gaps, plus an accordion layout
- Workspaces 1-9 and A-Z kept in memory; hidden windows are parked in the screen corner, like AeroSpace
- Animated layout changes and a sliding workspace switch
- Rotating gradient border around the focused window
- Current workspace shown in the menu bar

## Run

Quit AeroSpace first: both bind the same keys and both move windows.

```sh
swift run aether
```

The first run asks for Accessibility access for the app that launches it (your terminal). Grant it and run again. Ctrl-C restores every parked window before exiting.

## Keys

Ported from `~/.aerospace.toml`, except the workspace-to-monitor assignment (aether is single-monitor for now).

| Keys | Action |
|---|---|
| `alt-1..9`, `alt-<letter>` | switch workspace (`alt-e`, `alt-f`, `alt-q`, `alt-w` do other things) |
| `alt-shift-1..9`, `alt-shift-<letter>` | move the focused window to that workspace |
| `alt-shift-h/j/k/l` | swap with the neighbour in that direction |
| `alt-minus` / `alt-equal` | shrink / grow the focused window by 50px |
| `alt-slash` / `alt-comma` | dwindle / accordion layout |
| `alt-f` | fullscreen (inside the outer gaps) |
| `alt-tab` | previous workspace |
| `alt-e` | open Finder |
| `alt-q` | send cmd-q to the focused app |
| `alt-shift-semicolon` | service mode: `esc` reload, `r` reset layout, `f` toggle floating, `backspace` close other windows, `q` quit aether |

Finder, QuickTime and TablePro windows float (Ghostty tiles, unlike the AeroSpace config). Settings live in `Sources/aether/Config.swift`.
