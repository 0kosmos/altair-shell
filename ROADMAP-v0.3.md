# Altair v0.3 roadmap

This file is the plan for Altair v0.3. Work through it one feature at a time.
Follow every rule in CLAUDE.md. If this file and CLAUDE.md disagree, ask me.

## How to work

1. Before any code: read the existing code and this file, then show me a short
   plan for the NEXT unfinished feature only (files touched, approach, risks,
   rough effort). Wait for my OK.
2. Build that one feature, test it, measure with `scripts/perf.sh 30`
   (idle CPU and RAM before and after), then commit it on its own.
3. Tick the feature off in the checklist at the bottom of this file in the
   same commit, and add one line under "Notes" with anything the next session
   needs to know.
4. Stop and tell me it's done. Never rely on chat history: this file,
   CLAUDE.md and git are the memory.
5. If a feature turns out too big or too expensive, say so and propose a
   smaller version before building.

## Rules for every feature

The same as v0.2 (see ROADMAP-v0.2.md): performance first, every option in
config.json + Settings with a sensible default, low-power mode respected,
never rewrite hyprland.lua, use the theme everywhere, keep README /
install.sh / CREDITS in sync, no personal data.

---

## Feature 1: Lock screen + lock on idle

The last step of the original plan. Safety rules from CLAUDE.md apply in full.
- `WlSessionLock` (ext-session-lock-v1) + `PamContext` with the system's
  `/etc/pam.d/login` rules, so no file in /etc is needed.
- One surface per monitor: clock, date, password field, user name, media
  controls, blurred wallpaper. Wrong password: shake + message, never unlock.
- Fails open to an error message: if PAM itself can't start or errors
  internally (not a wrong password), the lock shows what went wrong and a
  way out; never a frozen screen.
- Recovery: `misc.allow_session_lock_restore` on (via the altair module),
  a `locked = true` restart bind, so a crashed lock can be brought back
  from the keyboard; TTY recovery documented in the README.
- Lock on idle with `IdleMonitor` (respects idle inhibitors such as video
  players), lock before suspend, screen off after a further timeout.
- IPC `lock lock`; keybind in the altair module (`SUPER + L` by default).
- Developed and tested in a nested Hyprland (a window on the real desktop)
  with a test-only PAM file (never shipped); the real lock is tried by me.

## Feature 2: Volume / brightness OSD

A small pill on volume, brightness and mic-mute changes, fades out after
~1.5 s. Only exists while visible.

## Feature 3: Power menu

Full-screen menu: lock, log out, suspend, reboot, shut down; confirm step;
keyboard navigable. Desktop right-click power actions use it.

## Feature 4: Clipboard history

Opt-in (`cliphist`, optional dependency). Text and images, searchable,
opened from the launcher with a prefix or its own key.

## Feature 5: Quick settings

One panel with volume, mic, Wi-Fi, Bluetooth, brightness, night light,
do-not-disturb and the recorder, reusing the existing menus.

## Feature 6: Recorder menu

Left click on the bar's record button starts/stops as now; right click opens
a small menu: audio (none / system / system + mic), frame rate, quality,
which screen or a region, cursor on/off, the folder, recent clips.

## Feature 7: Corner radius

One "Corners" setting (square → very round) that scales every radius in the
shell (panels, buttons, bar, dock, widgets, Settings) and Hyprland's window
rounding to match (runtime, originals restored).

## Feature 8: Livelier panel backgrounds

More panel background styles, some gently animated (only while a panel is
open, never at idle), with options: intensity, speed, colour source. Smoother
open/close motion for panels (style choice).

## Feature 9: Settings layouts

Layout styles for the Settings window: sidebar left (now), sidebar right,
categories as tabs on top, at the bottom, or a compact icon rail; plus a
polish pass on the Settings UI.

## Still untested from v0.2

- Bluetooth (no adapter on the dev PC)
- Joining a Wi-Fi network with a password
- Display colour shader (screenshots don't capture it)

---

## Checklist

- [x] 1. Lock screen + lock on idle
- [x] 2. Volume / brightness OSD
- [x] 3. Power menu
- [ ] 4. Clipboard history
- [ ] 5. Quick settings
- [ ] 6. Recorder menu
- [ ] 7. Corner radius
- [ ] 8. Livelier panel backgrounds
- [ ] 9. Settings layouts
- [ ] Release v0.3.0

## Notes

(Add one line per finished feature here.)

- F1 lock: services/Locker.qml (state, PAM via PamContext with /etc/pam.d/login (a custom configDirectory breaks `include login`: PAM resolves includes in that same directory), IdleMonitor x2, logind via `gdbus monitor` wrapped in `sh … cat` so it dies with the shell, sleep delay inhibitor `systemd-inhibit … cat` held while unlocked), lock/LockScreen.qml (LazyLoader + WlSessionLock, `held` until the compositor lets go), LockSurface.qml (no TextInput: keys edit Locker.buffer; Caps Lock from `hyprctl devices -j` after a key), PasswordField.qml (ListView add/remove/displaced transitions per style; `live: false` + count/status for the Settings preview). Flag file `$XDG_RUNTIME_DIR/altair/locked-<HYPRLAND_INSTANCE_SIGNATURE>` = relock on start. hypr/init.lua: allow_session_lock_restore, MOD+L, restart bind `locked = true`. DPMS: `hl.dsp.dpms({ action = "off" })`. TESTING: nested Hyprland (`Hyprland -c <test.lua>` opens a window; stop it by PID, never `pkill Hyprland`/patterns that match your own command), test shell with symlinked folders + `XDG_CONFIG_HOME` copy + `ALTAIR_LOCK_PAM_DIR`/`ALTAIR_LOCK_PAM_CONFIG` pointing at a test PAM file (pam_exec checker + pam_deny); never test wrong passwords against the real `login` stack (pam_faillock: 3 = 10 min lockout). From a TTY `loginctl unlock-session` (no ID) targets the TTY's own session; `unlock-sessions` needs auth_admin. TODO before v0.3.0: remove the fail-open Unlock button (Locker.forceUnlock / `broken`).
- F2 OSD: osd/Osd.qml (LazyLoader PanelWindow "altair-osd", Overlay, empty mask = click-through, ExclusionMode.Normal + extra margin for a non-reserving bottom dock). Triggers on value changes (Audio.volume/muted/micMuted, Display.brightness + Display.nudged for steps at 0/100), armed 2.5 s after start and re-armed 0.8 s after a default device change. Audio gained source/micMuted/toggleMicMute (PwObjectTracker tracks both). Skipped while locked and for brightness while the brightness panel is open. Cost: 0 idle, ~12 % shell CPU while a key is held (blurred layer redraws).
- F3 power: power/PowerMenu.qml (panel name "power" in ShellState.panels, own full-screen Overlay PanelWindow, LazyLoader; countdown = NumberAnimation on win.progress, Shape arc ring; CanHibernate via busctl on open; inline PowerButton with staggered entrance). Keys L S H O R D (Shut down = D: no P in the label). `ALTAIR_POWER_DRY_RUN=1` logs instead of acting: test power actions only with it (nested test shell has it in start.sh). Desktop menu: Lock + "Power…" (old click-twice list removed). Settings page renamed "Lock & power" (id still "lock"), lock.powerCountdown 0/3/5.
