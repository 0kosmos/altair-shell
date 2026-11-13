# Project: Altair (repo: altair-shell) — a Hyprland desktop shell built with Quickshell

This file is read by Claude Code at the start of every session in this repo.
It holds the goals, the rules and the current state of the project.

Public repo (to be created): https://github.com/0kosmos/altair-shell — use this URL in
the README and install.sh. Never put my real name, email or other personal data in
files or commits; git commits use my GitHub noreply email.

## Goal
A clean, fast, good-looking desktop shell for Hyprland, written in Quickshell (QML),
released as open source on GitHub. v0.1 should be small but polished: fewer features
done well beats many features done badly. Build for a public release from day one.

## Target platform
The developer's own machine (hardware, driver, monitor, measurements) is described in
`CLAUDE.local.md`, which is gitignored. Read it, keep it updated, never commit it.
- Hyprland 0.57+ — NOTE: Hyprland 0.55+ uses a Lua config (~/.config/hypr/hyprland.lua)
  and 0.57 removed the old hyprland.conf format entirely. Never write hyprlang/.conf
  syntax. Check the wiki for the installed version. `hyprctl repl '<lua>'` runs Lua in
  the live compositor (useful for testing; changes are lost on reload).
  0.57 advertises ext-background-effect-v1, ext-session-lock-v1, zwlr_layer_shell_v1.
- Quickshell 0.3+ — 0.3 added networking and polkit APIs; prefer those over shell
  commands where they exist. Type definitions: /usr/lib/qt6/qml/Quickshell/**.qmltypes.
  Blur: `BackgroundEffect.blurRegion` (ext-background-effect), Region has per-corner radius.
- Must also work on non-NVIDIA and laptop setups (battery, hybrid graphics).

## Decisions made
- Licence: GPL-3.0-or-later (Quickshell itself is LGPL-3.0).
- Fonts: Inter (UI text, OFL-1.1) and Material Symbols Rounded (icons, Apache-2.0).
- Imports use `qs.<folder>` (e.g. `import qs.core`). Singletons: Config, ShellState
  (not `State` — that name clashes with QtQuick's State type), Theme.
- Hyprland module is `hypr/init.lua`, symlinked as ~/.config/hypr/altair/ and loaded
  with `require("altair").setup({...})`.
- Measure with `scripts/perf.sh [seconds]`.
- Hyprland look (blur strength, window borders) is changed at runtime with
  `hyprctl eval`, never in hyprland.lua and never via `hyprctl reload` (a reload
  re-applies window rules and makes windows jump). The user's original values are
  read first and stored per Hyprland session (services/Hypr.qml).
  Changing `border_size` resizes every window (wobble with spring animations):
  "no borders" = transparent colours, not 0 px.
- Settings is a FloatingWindow (class org.quickshell, title "Altair Settings")
  with a window rule in hypr/init.lua (float, centre, rounding 18, no_anim; it
  fades itself in). Panels (launcher, notification centre) are layer surfaces.
- Live (video) wallpapers play in a separate Quickshell process (video/shell.qml),
  started only while a video wallpaper is set: decoding costs ~250–350 MB, which
  must never live in the main shell. Paused via IPC (0 % CPU). It exits by itself
  if the main shell dies. Hyprland originals are read only right after a config
  reload (never while our overrides may be active).
- Liquid glass = static shader (shaders/glass.frag, rebuild with
  scripts/build-shaders.sh). Real refraction is not possible (compositor only
  offers blur).

## How we work (rules)
1. Start every new feature by checking the environment and the docs, not by guessing.
   Use only documented Quickshell APIs; if unsure an API exists in the installed version,
   look it up in the official docs (quickshell.org) or the installed type definitions
   before writing code.
2. You (Claude) can run commands here. Run `hyprctl`, `qs`, read logs and test things
   yourself. Only ask me when something needs my eyes (how it looks/feels) or my password.
3. One feature at a time. After each: tell me how to reload/test it, what to look at,
   and wait for my feedback before moving on.
4. One clean git commit per feature (conventional style, e.g. `feat(bar): workspaces`).
5. Before the very first line of code: propose the folder structure and architecture
   and wait for my approval.
6. Be honest about limits. If something can't be done well (e.g. real refraction),
   say so and propose the best honest approximation.

## Safety rules (I must never get locked out of my own PC)
- Never overwrite my hyprland.lua. The shell ships its own Lua module
  (`hypr/init.lua`) that I `require()` from my config with one line.
  install.sh adds that line only after making a backup and asking.
- Always keep a working escape hatch: a keybind that restarts the shell, and a keybind
  that opens a terminal, both defined in Hyprland itself (not in Quickshell).
- Lock screen comes LAST. It must use Quickshell's session-lock support with PAM,
  must be tested in a way that can't lock me out (document the TTY recovery:
  Ctrl+Alt+F3 → log in → `pkill quickshell` / `loginctl unlock-session`), and
  must fail open to an error message, never to a frozen screen.
- install.sh never runs `rm -rf` on anything outside its own install directory,
  never uses sudo except for pacman installs it lists first, and has a `--dry-run`.

## Style
- Clean, minimal, modern. Mostly monochrome with ONE accent colour the user can change.
- Frosted-glass panels, rounded corners, consistent spacing and type scale.
- Smooth animations on every open/close/hover (short, eased, never laggy).
- Must still look good with all effects off (solid, slightly translucent panels).

## Visual options (all toggles in the Settings app)
- Blur: on by default, adjustable strength, toggleable at runtime. Blur for layer
  surfaces is applied by Hyprland, not by Quickshell. Find out how the INSTALLED
  Hyprland version does it (Lua layer rules, new blur variants in 0.57, and whether
  ext-background-effect is supported) and implement the cleanest documented way.
  Do not copy syntax from old blog posts.
- Liquid glass: off by default. iPhone-style look: gradient tint, specular edge
  highlight, inner glow, subtle depth. True refraction of what's behind a panel needs
  compositor support; approximate with gradients/highlights/light shaders on our own
  content and tell me exactly what is real and what is faked.
- Low-power mode: disables animations, blur and shaders in one click.

## Performance is a feature
- Idle CPU near 0%, small RAM. Measure (process CPU/RAM of quickshell at idle, with
  panels open, and with effects on/off) and report numbers after each feature.
- Panels are created lazily with Loader and unloaded when hidden.
- Use Quickshell's built-in services (audio/PipeWire, tray, battery/UPower, network,
  notifications, MPRIS, Hyprland IPC) instead of polling shell commands.
- Unavoidable polling (e.g. nvidia-smi for GPU stats) only while the panel showing it
  is visible, with long intervals.
- No always-running shaders or animations. Cache wallpaper thumbnails on disk.
- One Theme singleton (colours, sizes, fonts, effect flags) and one State/Config
  singleton. Cheap bindings, no binding loops.
- A documented way to check performance (debug overlay or a command) .

## Features (build in this order)
1. Skeleton: config loading (~/.config/altair/config.json), Theme singleton,
   IPC handlers so Hyprland keybinds can toggle panels (`qs ipc call ...`)
2. Top bar: workspaces, clock, tray, volume / network / battery
3. App launcher with fuzzy search
4. Notification popups (+ simple history)
5. Settings app with sidebar: theme, accent colour, bar position, blur on/off and
   strength, liquid glass, animations, notification sound, performance mode
6. Wallpaper: rendered by Quickshell itself (background layer) + picker with
   cached thumbnails — no extra wallpaper daemon needed
7. Dashboard: clock, calendar, weather (Open-Meteo, no API key), CPU/RAM/GPU,
   media controls
8. Lock screen (see safety rules)
9. Release: install.sh (Arch-based, with --dry-run and uninstall), README with
   features / screenshots / dependencies / keybinds / install, LICENSE, CREDITS,
   CONTRIBUTING

v0.1 can ship after step 6 if the rest isn't polished yet. Dashboard and lock
screen can be v0.2.

## Open-source requirements
- One QML file per component, clear folders (e.g. bar/, launcher/, notifications/,
  settings/, dashboard/, lock/, services/, theme/, assets/).
- No hardcoded paths or usernames. User settings live in ~/.config/altair/, never in
  the repo. Use XDG paths.
- Only assets with free licences, each listed in CREDITS.
- Comments on non-obvious code.
- Quickshell is LGPL-3.0; our code is GPL-3.0-or-later (see LICENSE).
- Keep the README's dependency list in sync with install.sh.
