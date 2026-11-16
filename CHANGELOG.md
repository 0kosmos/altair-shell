# Changelog

All notable changes to Altair. Versions follow [semantic versioning](https://semver.org).

## [Unreleased]

### Lock screen
- **Lock screen** (`SUPER + L`, *Settings → Lock screen*): blurred
  wallpaper, clock, music controls and a password field with six typing
  animations (Pop, Wave, Glow, Shapes, Bars, Minimal) and a live preview.
- Locks when idle (respects apps that keep the screen awake), before sleep
  and on `loginctl lock-session`; screen off while locked.
- Safe by design: a crashed lock screen comes back locked
  (`SUPER + SHIFT + R` works on it), `loginctl unlock-session(s)` from a
  console unlocks, and a broken password check shows an error instead of
  freezing. See README, "If the lock screen breaks".

### Power menu
- **Power menu** (`SUPER + Escape`): lock, suspend, hibernate (if
  available), log out, restart, shut down; keyboard letters; a cancellable
  countdown before log out / restart / shut down. The desktop menu opens it.

### Look
- **Moving panel backgrounds**: Flow, Nebula, Waves, Prism, Stars, Pulse,
  Lava, Ripple, Snow and Plasma, animated only while a panel, menu or
  Settings is open; intensity, colours
  (accent or palette), speed, on/off; live preview in Settings.
- **Panel motion**: Glide, Spring, Zoom, Drop, Fade, Pop, Flip, Unfold or
  Swing, for panels, menus and the Settings window.
- **Corners**: one setting from square to very round (presets or a
  slider) for every panel, menu, card, bar, dock, widget and Settings;
  optionally Hyprland's window corners too (your rounding × the setting).

### Sounds
- Five new, clearly different UI sound families: **Retro** (8-bit
  beeps), **Bell** (chimes), **Mechanical** (keyboard-switch clicks),
  **Sci-fi** (sweeps and zaps) and **Air** (soft whooshes).

### Workspaces
- Four more switching animations: Slide + fade, Vertical + fade, Bouncy
  and Smooth (the bar's indicator follows the same curve).

### Recorder
- **Recorder menu**: right-click the record button (left click still
  records): screen or a dragged region, sound, frame rate, quality, codec
  (what your GPU supports), mouse pointer, latest clips.

### Clipboard
- **Clipboard history** (opt-in, `SUPER + SHIFT + V`, needs `cliphist`):
  search, image thumbnails, paste into the previous window, delete, clear;
  password-manager secrets are never stored.

### Pop-ups
- **Volume and brightness pop-up**: shows volume, mute, microphone mute
  and brightness changes for a moment, whatever made them (keys, apps,
  the bar). Bottom or top; *Settings → Notifications*.

## [0.2.0] — 2026-11-16

A big update: desktop widgets, a dock, Alt+Tab, sounds, network and display
controls, and a lot of polish.

### Desktop
- **Widgets** with an edit mode (`SUPER + D`): clock, round clock, music,
  visualizer, equalizer, lyrics, weather and system. Many styles each, any
  size, opacity, a font for widgets, undo, select and clear all.
- **Magnetic groups**: widgets snap together on any side and move as one;
  groups stay on screen and glide clear of the bar and dock.
- **Music**: player volume, "Playing on", seekable song bar, a built-in
  visualizer (ring, glow, bars, wave, mirror) and **karaoke lyrics**
  (LRCLIB). The visualizer hears only the music player, not other sounds.
- **Music equalizer** with presets (PipeWire filter, only the player's audio).
- **Weather** (Open-Meteo, no API key) with rain, snow and sun effects;
  the place name can be hidden (screenshots, streaming).
- **Dock** (optional): pinned and running apps, recent apps, menus, drag to
  reorder, auto-hide, any edge.
- **Desktop right-click menu**.
- **Precise moving**: snapping, guide lines and dimming when moving windows
  and widgets.

### Bar
- Left and right positions; optionally drag the bar to another edge
  (Settings → Bar → Move by dragging, off by default).
- **Clock popup** with a month calendar, a round clock and the weather.
- Clock position: middle, left or right, before or after the other items.
- **Network menu**: connection details, Wi-Fi networks, connect with a password.
- **Bluetooth menu**: devices, battery, pairing.
- **Brightness button** and *Settings → Display*: monitor brightness and
  contrast over DDC/CI or the laptop backlight; saturation, night light,
  gamma and dimming as a screen shader (only while used).
- Screen recorder button (60 fps, GPU-encoded).

### Windows and workspaces
- **Alt+Tab** switcher with live previews.
- Smooth workspace switching with a synced bar indicator; previous/next and
  last-workspace keys.
- **Window transparency** with per-app rules.

### Look and feel
- **UI sounds**: six families (Glass, Soft, Minimal, Bubble, Wood, Pulse) or
  your own files, per event.
- Ten **panel backgrounds** (Glow, Aurora, Grain, Mesh, Sheen, Edge light,
  Dusk, Lines, Dots).
- **Colour themes from the wallpaper**, saved per wallpaper or automatic.
- Five wallpapers of Altair's own (Aurora, Dusk, Lagoon, Ember, Glacier).
- Launcher: animated results while typing, shrinks to its results,
  right-click menu for apps.
- Settings: re-centring and size reset glide, opens where you left it.

### Fixes
- Several settings changed at once (e.g. a sound style for everything) no
  longer revert some of them.
- The equalizer no longer pauses music; leftover filter processes are
  cleaned up.
- Restart and uninstall stop the shell reliably (SIGKILL; Quickshell 0.3.2
  can crash on a normal quit).

### Dependencies
- New optional: `bluez` (Bluetooth), `ddcutil` (monitor brightness),
  `cava` (visualizer), `libpulse` (equalizer routing),
  `gpu-screen-recorder` (recorder).

## [0.1.0] — 2026-11-13

First release: bar, app launcher, notifications, Settings, wallpapers with
a picker and live wallpapers.

[0.2.0]: https://github.com/0kosmos/altair-shell/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/0kosmos/altair-shell/releases/tag/v0.1.0
