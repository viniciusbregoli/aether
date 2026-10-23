/// Written to ~/.config/aether/config.toml on first run, and the fallback for missing keys.
public let defaultConfig = #"""
# aether config. Missing keys fall back to the built-in defaults; a [mode.*] table
# replaces that mode's default bindings as a whole. Reload with alt-shift-semicolon then esc.
# Commands use AeroSpace's names, so bindings can be copied from ~/.aerospace.toml.

# Changing the workspace list needs a restart.
workspaces = ['1', '2', '3', '4', '5', '6', '7', '8', '9',
              'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
              'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z']

gaps-inner = 10
gaps-outer = 10
# No outer gaps while a workspace has a single tiled window.
smart-gaps = false
accordion-padding = 30
# Manual and saved workspace layouts override this default.
default-layout = 'dwindle' # dwindle, accordion, master or scrolling
# First child's fraction; manual and saved split ratios take precedence.
dwindle-split-ratio = 0.5 # 0.1 to 0.9
# Master layout: the first window's share of the width; manual and saved resizes take precedence.
master-ratio = 0.55 # 0.1 to 0.9
# Scrolling layout: each column's share of the width; manual and saved resizes take precedence.
scrolling-column-width = 0.5 # 0.1 to 1.0
# Selecting the current workspace returns to the previous one when enabled.
workspace-auto-back-and-forth = false

# Movement duration in seconds; 0 places windows immediately.
animations-enabled = true # Includes border rotation.
animation-duration = 0.22
animation-curve = 'ease-out-cubic' # linear, ease-out-cubic, ease-in-out-cubic

border-enabled = true
border-width = 3
# Rounds the overlay outline, not the application's window.
border-radius = 12
# Conic gradient around the focused window, #rrggbb or #rrggbbaa.
border-colors = ['#64d2ff', '#bf5af2', '#64d2ff']
border-animation-enabled = true # false leaves the gradient static.
border-rotation-seconds = 6
# Hide the border while the focused window is the only tiled one on its workspace.
smart-border = false

# Covers every visible window except the focused one with a translucent layer of dim-color.
dim-inactive = 0.0 # 0 is off; 0.0 to 1.0 is the layer's opacity.
dim-color = '#000000' # #rrggbb or #rrggbbaa

# Bundle ids of apps whose windows float instead of tiling.
floating-apps = ['com.apple.finder', 'com.apple.QuickTimePlayerX', 'com.TablePro']

# Opening an app whose windows are all on other workspaces gives it a new window on the
# current one (cmd-N). Apps listed here jump to their existing window instead.
reuse-window-apps = ['app.zen-browser.zen']

# AeroSpace's [[on-window-detected]] rules run on newly detected windows, in order. The first
# match applies and stops unless check-further-callbacks = true. All if.* keys are optional;
# the regex ones are case-insensitive substring searches. The window title can still be empty
# when the window appears, so title rules may miss. run takes 'layout floating',
# 'layout tiling' and 'move-node-to-workspace <name>'; floating-apps applies first.
# [[on-window-detected]]
#     if.app-id = 'com.mitchellh.ghostty'
#     if.app-name-regex-substring = 'ghostty'
#     if.window-title-regex-substring = 'picture-in-picture'
#     if.workspace = '1'
#     run = ['layout floating', 'move-node-to-workspace 2']
#     check-further-callbacks = false

# Per-workspace overrides, like Hyprland's workspace rules. The name must be in workspaces;
# keys left out use the global value, and a manually chosen layout still wins.
# [workspace.3]
#     gaps-inner = 0
#     gaps-outer = 0
#     default-layout = 'accordion'

[mode.main.binding]
    alt-slash = 'layout dwindle'
    alt-comma = 'layout accordion'

    alt-shift-h = 'move left'
    alt-shift-j = 'move down'
    alt-shift-k = 'move up'
    alt-shift-l = 'move right'

    alt-minus = 'resize -50'
    alt-equal = 'resize +50'

    alt-f = 'fullscreen'
    alt-tab = 'workspace-back-and-forth'
    alt-e = 'exec-and-forget open -a /System/Library/CoreServices/Finder.app'
    alt-q = '''exec-and-forget osascript -e 'tell application "System Events" to keystroke "q" using command down''''
    alt-shift-semicolon = 'mode service'
    alt-1 = 'workspace 1'
    alt-2 = 'workspace 2'
    alt-3 = 'workspace 3'
    alt-4 = 'workspace 4'
    alt-5 = 'workspace 5'
    alt-6 = 'workspace 6'
    alt-7 = 'workspace 7'
    alt-8 = 'workspace 8'
    alt-9 = 'workspace 9'
    alt-a = 'workspace A'
    alt-b = 'workspace B'
    alt-c = 'workspace C'
    alt-d = 'workspace D'
    alt-g = 'workspace G'
    alt-h = 'workspace H'
    alt-i = 'workspace I'
    alt-j = 'workspace J'
    alt-k = 'workspace K'
    alt-l = 'workspace L'
    alt-m = 'workspace M'
    alt-n = 'workspace N'
    alt-o = 'workspace O'
    alt-p = 'workspace P'
    alt-r = 'workspace R'
    alt-s = 'workspace S'
    alt-t = 'workspace T'
    alt-u = 'workspace U'
    alt-v = 'workspace V'
    alt-x = 'workspace X'
    alt-y = 'workspace Y'
    alt-z = 'workspace Z'

    alt-shift-1 = 'move-node-to-workspace 1'
    alt-shift-2 = 'move-node-to-workspace 2'
    alt-shift-3 = 'move-node-to-workspace 3'
    alt-shift-4 = 'move-node-to-workspace 4'
    alt-shift-5 = 'move-node-to-workspace 5'
    alt-shift-6 = 'move-node-to-workspace 6'
    alt-shift-7 = 'move-node-to-workspace 7'
    alt-shift-8 = 'move-node-to-workspace 8'
    alt-shift-9 = 'move-node-to-workspace 9'
    alt-shift-a = 'move-node-to-workspace A'
    alt-shift-b = 'move-node-to-workspace B'
    alt-shift-c = 'move-node-to-workspace C'
    alt-shift-d = 'move-node-to-workspace D'
    alt-shift-e = 'move-node-to-workspace E'
    alt-shift-f = 'move-node-to-workspace F'
    alt-shift-g = 'move-node-to-workspace G'
    alt-shift-i = 'move-node-to-workspace I'
    alt-shift-m = 'move-node-to-workspace M'
    alt-shift-n = 'move-node-to-workspace N'
    alt-shift-o = 'move-node-to-workspace O'
    alt-shift-p = 'move-node-to-workspace P'
    alt-shift-q = 'move-node-to-workspace Q'
    alt-shift-r = 'move-node-to-workspace R'
    alt-shift-s = 'move-node-to-workspace S'
    alt-shift-t = 'move-node-to-workspace T'
    alt-shift-u = 'move-node-to-workspace U'
    alt-shift-v = 'move-node-to-workspace V'
    alt-shift-w = 'move-node-to-workspace W'
    alt-shift-x = 'move-node-to-workspace X'
    alt-shift-y = 'move-node-to-workspace Y'
    alt-shift-z = 'move-node-to-workspace Z'

[mode.service.binding]
    esc = ['reload-config', 'mode main']
    r = ['reset-layout', 'mode main']
    f = ['toggle-floating', 'mode main']
    backspace = ['close-all-windows-but-current', 'mode main']
    q = 'quit'
"""#
