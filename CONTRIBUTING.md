# Contributing to Altair

Thanks for helping! Altair aims to be small, fast and polished, so changes are
judged on those three things as much as on features.

## Development setup

```sh
git clone https://github.com/0kosmos/altair-shell
cd altair-shell
./install.sh --dev        # links this checkout instead of copying it
```

Quickshell reloads QML files live when you save them. New folders (new
`qs.<folder>` modules) need a restart: `SUPER + SHIFT + R`.
Logs: `qs -c altair log -f`.

## Layout

```
shell.qml        entry point
core/            Config (config.json), ShellState (runtime state), Ipc
theme/           Theme singleton, palettes
services/        thin wrappers: Hyprland, audio, network, battery, apps,
                 notifications, wallpapers
components/      shared building blocks (panels, buttons, toggles, ...)
bar/ launcher/ notifications/ settings/ wallpaper/   one folder per feature
video/           the live-wallpaper player (runs as its own process)
hypr/init.lua    Hyprland side: keybinds, window rules, autostart
shaders/         .frag sources and compiled .qsb (scripts/build-shaders.sh)
scripts/         perf.sh, build-shaders.sh
```

## Rules

- **One QML file per component**, comments on anything non-obvious.
- **Visuals go through `Theme`**, never read `Config` for colours or sizes.
- **Only documented Quickshell APIs.** Check the installed type definitions
  (`/usr/lib/qt6/qml/Quickshell/**.qmltypes`) or quickshell.org.
- **Performance is a feature:**
  - idle CPU must stay at ~0 %: no polling (use Quickshell's services), no
    animation or shader that runs while nothing changes;
  - panels are created when opened and destroyed when closed;
  - measure before and after: `scripts/perf.sh 30` (idle, panel open,
    effects on/off) and mention the numbers in your PR.
- **Never break the user's Hyprland:** `hypr/init.lua` only adds things; look
  changes are applied at runtime (`hyprctl eval`) and restorable; never call
  `hyprctl reload` casually (it re-applies window rules and makes windows jump).
- **No hardcoded paths or user names.** Use `$HOME`/XDG paths.
- **Assets** must have a free licence and be listed in `CREDITS.md`.
- **Keep the dependency list in `README.md` in sync with `install.sh`.**
- `install.sh` must keep its promises: sudo only for `pacman -S` after listing
  packages, `rm -rf` only on its own install directory, `--dry-run` changes
  nothing, nothing of the user's is deleted.

## Shaders

Edit `shaders/*.frag`, then run `scripts/build-shaders.sh` (needs `qsb` from
`qt6-shadertools`) and commit both the source and the `.qsb`.

## Commits

One feature or fix per commit, conventional style:
`feat(bar): workspaces`, `fix(launcher): keep selection while scrolling`.

## Before opening a PR

- `qs -c altair log` shows no new warnings or errors.
- `./install.sh --dry-run` still works.
- Try it with effects off and in low-power mode.
- Try both bar positions and both a dark and a light palette.
