# Hyprland visual inspiration for aether

Research checked on 2026-10-22. Five real author-provided screenshots were downloaded and individually inspected with `view_image`. These are visual references for the macOS Swift window manager aether. Screenshot appearance may differ from current defaults. Design suggestions below are proposals, not claims that Linux compositor or shell features are available on macOS.

Machine-readable gallery input: `/tmp/aether-hyprland-inspiration/manifest.json`. Images are unmodified originals. Repository licenses below describe the software repositories; separate rights to embedded wallpaper/artwork were not established.

## 1. HyDE: Graphite Mono

- **Repository:** [HyDE-Project/HyDE](https://github.com/HyDE-Project/HyDE). Repository license: [GPL-3.0](https://github.com/HyDE-Project/HyDE/blob/fa2fd57afc7203b1b5653d3271f3a57ea3873f97/LICENSE).
- **Screenshot origin:** author repository asset [`Source/assets/theme_graph_1.png`](https://github.com/HyDE-Project/HyDE/blob/fa2fd57afc7203b1b5653d3271f3a57ea3873f97/Source/assets/theme_graph_1.png). [Exact image URL](https://raw.githubusercontent.com/HyDE-Project/HyDE/fa2fd57afc7203b1b5653d3271f3a57ea3873f97/Source/assets/theme_graph_1.png).
- **Local image:** `/tmp/aether-hyprland-inspiration/hyde-graphite.png`.
- **Observed:** grayscale wallpaper and application surfaces, almost square windows, bright fine outlines, narrow bottom bar. The screenshot names Graphite Mono. This is an existing theme showcase, not evidence that the current default bar sits at the bottom.
- **Verified components:** [Waybar config](https://github.com/HyDE-Project/HyDE/blob/fa2fd57afc7203b1b5653d3271f3a57ea3873f97/Configs/.config/waybar/config.jsonc), [Rofi theme](https://github.com/HyDE-Project/HyDE/blob/fa2fd57afc7203b1b5653d3271f3a57ea3873f97/Configs/.config/rofi/theme.rasi), and [official theme list](https://github.com/HyDE-Project/HyDE#themes), which includes Graphite Mono.
- **Ideas for aether:** a monochrome preset; independent border width and gap controls; bright focus indication against quiet inactive windows. Best reference here for restrained window decoration.

## 2. end-4: illogical impulse

- **Repository:** [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland). Repository license: GPL-3.0, as identified by the repository.
- **Screenshot origin:** the current Quickshell section of the author's [README](https://github.com/end-4/dots-hyprland/blob/2f2a376fdb2ad738bf55f693dd0b474b64bb0ab8/.github/README.md), labeled “Window management.” [Exact image URL](https://github.com/user-attachments/assets/c51bed8b-3670-4d4c-9074-873be224fb8e).
- **Local image:** `/tmp/aether-hyprland-inspiration/end4-window-management.png`.
- **Observed:** a large rounded workspace grid, application thumbnails/icons, a clear selected-tile outline, a slim left rail, and a detached search capsule. Another inspected official image, `end4-illogical-impulse.png`, shows the green Material settings and widget panels.
- **Verified components:** README identifies Quickshell for the bar and sidebars; source includes [overview UI](https://github.com/end-4/dots-hyprland/blob/2f2a376fdb2ad738bf55f693dd0b474b64bb0ab8/dots/.config/quickshell/ii/modules/ii/overview/Overview.qml) and [Matugen color generation](https://github.com/end-4/dots-hyprland/blob/2f2a376fdb2ad738bf55f693dd0b474b64bb0ab8/dots/.config/matugen/config.toml). This screenshot is Quickshell-era, not the older AGS version.
- **Ideas for aether:** keyboard-invoked workspace overview; compact app identities; a separated search capsule. Thumbnail capture, window movement, and workspace control need their own macOS feasibility assessment.

## 3. JaKooLit: KooL dots

- **Repository:** [JaKooLit/Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots). Repository license: GPL-3.0, as identified by the repository.
- **Screenshot origin:** the dots [README](https://github.com/JaKooLit/Hyprland-Dots/blob/c093e836764d62346390ba307c9163ca11d0229b/README.md) links the author's dedicated [screenshot repository](https://github.com/JaKooLit/screenshots/tree/7dbcf00e27f3b712c642c776caffd13b49c57a98/Hyprland-ScreenShots). Selected historical Arch-v2 image: [exact image URL](https://raw.githubusercontent.com/JaKooLit/screenshots/7dbcf00e27f3b712c642c776caffd13b49c57a98/Hyprland-ScreenShots/Arch-v2/Arch-Default-Layout.png).
- **Local image:** `/tmp/aether-hyprland-inspiration/jakoolit.png`.
- **Observed:** three detached top-bar islands, a purple accent shared with the wallpaper and terminal, thin outlines, and ample open space. This is an older showcase, not a representation of current defaults. The current README announces a maintenance handoff to LinuxBeginnings.
- **Verified components:** repository has Waybar layouts, a selectable [Rofi theme](https://github.com/JaKooLit/Hyprland-Dots/blob/c093e836764d62346390ba307c9163ca11d0229b/config/rofi/config.rasi), and [Wallust templates](https://github.com/JaKooLit/Hyprland-Dots/tree/c093e836764d62346390ba307c9163ca11d0229b/config/wallust) for Waybar/Rofi/terminal colors. The current theming pipeline does not establish which generator made this older image.
- **Ideas for aether:** configurable bar groups; one accent linking workspace selection and window focus; a sparse desktop preset. An additional inspected light variant is saved as `jakoolit-light.png` but is not in the five-entry manifest.

## 4. ML4W OS: glass panels

- **Repository:** [mylinuxforwork/dotfiles](https://github.com/mylinuxforwork/dotfiles). Repository license: GPL-3.0, as identified by the repository.
- **Screenshot origin:** embedded directly in the author's [README](https://github.com/mylinuxforwork/dotfiles/blob/d766383cc36092017940fdb9053f39ea4c7dfb21/README.md), hosted on the [official ML4W site](https://ml4w.com/os/). [Exact image URL](https://ml4w.com/os/screen-216.jpg).
- **Local image:** `/tmp/aether-hyprland-inspiration/ml4w.jpg`.
- **Observed:** centered floating status bar, bottom dock, teal outlines, left wallpaper gallery, right settings panel, and a wide translucent two-column launcher. The screenshot explicitly displays “Status Bar Engine Quickshell.”
- **Verified components:** [Quickshell status bar](https://github.com/mylinuxforwork/dotfiles/blob/d766383cc36092017940fdb9053f39ea4c7dfb21/dotfiles/.config/quickshell/StatusbarApp/StatusbarWindow.qml); [launcher script](https://github.com/mylinuxforwork/dotfiles/blob/d766383cc36092017940fdb9053f39ea4c7dfb21/dotfiles/.config/ml4w/scripts/ml4w-launcher) supports Walker and Rofi, with [Walker selected](https://github.com/mylinuxforwork/dotfiles/blob/d766383cc36092017940fdb9053f39ea4c7dfb21/dotfiles/.config/ml4w/settings/launcher) in the inspected revision; [Matugen templates](https://github.com/mylinuxforwork/dotfiles/blob/d766383cc36092017940fdb9053f39ea4c7dfb21/dotfiles/.config/matugen/config.toml) include shell, launcher, and ML4W Dock colors. The displayed launcher is a visual observation; its runtime implementation was not proven from the image.
- **Ideas for aether:** thumbnail-based appearance presets; a compact layout/appearance panel; a centered workspace strip. Use translucent materials with readable text and restrained outlines.

## 5. fufexan: historical AGS design

- **Repository:** [fufexan/dotfiles](https://github.com/fufexan/dotfiles). Repository license: [MIT](https://github.com/fufexan/dotfiles/blob/ffc567f8f3530ccc877c52fb26fa4a577f1794f2/LICENSE).
- **Screenshot origin:** the author's [README, Previous versions > Ags > Dark](https://github.com/fufexan/dotfiles/blob/ffc567f8f3530ccc877c52fb26fa4a577f1794f2/README.md). [Exact image URL](https://github.com/fufexan/dotfiles/assets/36706276/d0cc86c8-39b1-4a49-b9d9-6f161f2420f2). The README's newest Quickshell preview URL returned HTTP 404; this older working image is intentionally labeled historical.
- **Local image:** `/tmp/aether-hyprland-inspiration/fufexan-ags-dark.png`.
- **Observed:** pastel workspace dots, a continuous translucent top bar, centered media identity, readable right-side status, and rounded slate windows with subtle outlines.
- **Verified components:** the historical [AGS config](https://github.com/fufexan/dotfiles/blob/51bd109bca376114670f9d6e5e529b7cca61f249/home/services/ags/config.js) loads bar/music/OSD/system-menu/notification widgets; [dark Sass colors](https://github.com/fufexan/dotfiles/blob/51bd109bca376114670f9d6e5e529b7cca61f249/home/services/ags/style/colors-dark.scss) define the palette and translucent bar. Current main uses Quickshell. No launcher is visible or attributed here.
- **Ideas for aether:** distinguish active, occupied, and empty workspaces with dots; reveal names on hover/focus; keep state colors small and the rest of the bar neutral.

## Useful starting directions

For aether's first visual exploration, compare HyDE Graphite's quiet focus treatment with fufexan's compact workspace dots. Use end-4 to explore an optional workspace overview. ML4W is the stronger reference for appearance controls, while JaKooLit is useful for modular bar composition. These are design proposals only; no code or dotfiles were installed or run.
