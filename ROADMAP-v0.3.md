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
- [x] 4. Clipboard history
- [ ] 5. Quick settings
- [x] 6. Recorder menu
- [x] 7. Corner radius
- [x] 8. Livelier panel backgrounds
- [x] 9. Settings layouts
- [ ] Release v0.3.0

## Notes

(Add one line per finished feature here.)

- F1 lock: services/Locker.qml (state, PAM via PamContext with /etc/pam.d/login (a custom configDirectory breaks `include login`: PAM resolves includes in that same directory), IdleMonitor x2, logind via `gdbus monitor` wrapped in `sh … cat` so it dies with the shell, sleep delay inhibitor `systemd-inhibit … cat` held while unlocked), lock/LockScreen.qml (LazyLoader + WlSessionLock, `held` until the compositor lets go), LockSurface.qml (no TextInput: keys edit Locker.buffer; Caps Lock from `hyprctl devices -j` after a key), PasswordField.qml (ListView add/remove/displaced transitions per style; `live: false` + count/status for the Settings preview). Flag file `$XDG_RUNTIME_DIR/altair/locked-<HYPRLAND_INSTANCE_SIGNATURE>` = relock on start. hypr/init.lua: allow_session_lock_restore, MOD+L, restart bind `locked = true`. DPMS: `hl.dsp.dpms({ action = "off" })`. TESTING: nested Hyprland (`Hyprland -c <test.lua>` opens a window; stop it by PID, never `pkill Hyprland`/patterns that match your own command), test shell with symlinked folders + `XDG_CONFIG_HOME` copy + `ALTAIR_LOCK_PAM_DIR`/`ALTAIR_LOCK_PAM_CONFIG` pointing at a test PAM file (pam_exec checker + pam_deny); never test wrong passwords against the real `login` stack (pam_faillock: 3 = 10 min lockout). From a TTY `loginctl unlock-session` (no ID) targets the TTY's own session; `unlock-sessions` needs auth_admin. TODO before v0.3.0: remove the fail-open Unlock button (Locker.forceUnlock / `broken`).
- F2 OSD: osd/Osd.qml (LazyLoader PanelWindow "altair-osd", Overlay, empty mask = click-through, ExclusionMode.Normal + extra margin for a non-reserving bottom dock). Triggers on value changes (Audio.volume/muted/micMuted, Display.brightness + Display.nudged for steps at 0/100), armed 2.5 s after start and re-armed 0.8 s after a default device change. Audio gained source/micMuted/toggleMicMute (PwObjectTracker tracks both). Skipped while locked and for brightness while the brightness panel is open. Cost: 0 idle, ~12 % shell CPU while a key is held (blurred layer redraws).
- F3 power: power/PowerMenu.qml (panel name "power" in ShellState.panels, own full-screen Overlay PanelWindow, LazyLoader; countdown = NumberAnimation on win.progress, Shape arc ring; CanHibernate via busctl on open; inline PowerButton with staggered entrance). Keys L S H O R D (Shut down = D: no P in the label). `ALTAIR_POWER_DRY_RUN=1` logs instead of acting: test power actions only with it (nested test shell has it in start.sh). Desktop menu: Lock + "Power…" (old click-twice list removed). Settings page renamed "Lock & power" (id still "lock"), lock.powerCountdown 0/3/5.
- F4 clipboard: services/Clipboard.qml (watchers `wl-paste --type text|image --watch cliphist -max-items N store` in one `sh … cat` process; cliphist skips CLIPBOARD_STATE=sensitive, so no filter of ours; list on open; image thumbs = `cliphist decode` into ~/.cache/altair/clipboard/<id>.png one at a time; use() = decode | wl-copy, then send_shortcut CTRL V or CTRL SHIFT V for terminal classes after 0.18 s; delete = the original list line into `cliphist delete`). clipboard/ClipboardPanel + ClipboardContent (launcher-style, ScriptModel by id; selection reset to 0 after each reload, else an insert above slides it). Settings > Clipboard. SUPER+V is the stock float key, so SUPER+SHIFT+V. TESTING: paste only into a test window identified by title/class AND verified focused; close test windows by PID (a focus-based close once shut the user's Chrome).
- F6 recorder menu: recorder/RecorderPanel.qml (AltairPanel "recorder", docked like brightness; Row_ = label above a full-width control); Segmented gained `stretch` (segments share the given width; set width: parent.width). Recorder: target/fps/quality/codec/cursor config, codecs from `gpu-screen-recorder --info` (section video_codecs: h264/hevc/av1), region via slurp started with `< /dev/null` (slurp reads preset boxes from a piped stdin and otherwise never shows), recent clips via ls/stat on open. TESTING: editing a QML file hot-reloads the shell and IPC answers "Not ready" for a moment: a toggle can get lost, the next one then STARTS a recording; wait or restart before IPC tests. vmouse needs a small move before press for slurp; delete test clips afterwards.
- F7 corners: Theme.corners (Config.appearance.corners 0–2) scales Theme.radius.s/m/l; circles/pills keep their fixed or height/2 radius. Hypr.qml stores `rounding` in the originals (old records: read once with getoption, since Altair never changed it before) and applies round(original × corners) when appearance.windowCorners. Settings window rounding: place_settings(x, y, rounding) (x, y may be nil); the running Hyprland keeps the old 2-argument function until the next login (the extra argument is ignored, rounding stays 18).
- F8 panel backgrounds: panelfx.frag modes 10–15 (flow, nebula, waves, prism, stars, pulse) use `time`; uniforms c2/c3 (palette colours, alpha 0 = derive from the accent). GlassBackground.animate (AltairPanel: open; menus: true; OSD: shown) drives time with a 33 ms Timer only while animate && Theme.panelFxAnimated && visible; elsewhere time stays 7 (still frame). Cost here: ~11 % shell CPU while a panel with a moving style is open, idle unchanged (0.05 %). Panel motion in AltairPanel body (scaleFrom/slide/easing per Theme.panelMotion); the Effects page opens the calendar once to demo a new motion.
- F8 follow-up: modes 16–19 (lava, ripple, snow, plasma); Stars drift. Settings window animates its background while open (~8 % CPU here) and uses the panel motion: Theme.motionSpec { scale, slide, flip, swing, unfold, easing, overshoot, extra } drives both AltairPanel and SettingsWindow through one progress value p (0 closed → 1 open; OutBack overshoot = bounce); closing is a quick ease-in. Settings tones motion down (it must stay inside its window).
- Workspaces: Hypr.workspaceStyles = id -> { Hyprland style, bezier } (slidefade/slidefadevert 30 %, bounce = slide on 0.34,1.45,0.64,1, smooth = slide on 0.65,0,0.35,1); workspaceCurve follows the style for the bar pill. Hyprland 0.57 workspace styles accepted: slide [dir], slidevert, fade, slidefade N%, slidefadevert N% (popin is windows-only: "unknown style").
- Sounds: four families appended to scripts/gen-sounds.py (retro = filtered pulse waves + arpeggios, bell = tuned-bell partials, mechanical = noise click + damped low body, scifi = resonant SVF saw sweeps + zaps). Appended after the old styles so the seeded noise of the existing files stays identical (git shows only new files). Add a family: generator + Sounds.builtIn + SoundsPage.builtIns. (An "air" family of noise whooshes was tried and removed: the user disliked it.)
- Wallpaper picker filter: wallpaper/PickerFilter.qml (used by strip and grid): kind tabs (wallpaper.pickerKind) + type-to-search; nameFilters = "*query*" + extension, applied 150 ms after the last key (FolderListModel re-listing on every key could end empty). The picker's own Keys handler asks filter.handleKey first (Esc clears the search before closing; Space applies only when no search is typed).
- Widget menu: widgets/WidgetMenu.qml (Overlay PanelWindow like DesktopMenu, opened by WidgetLayer on Widgets.menuRequested(id, screen, at)); WidgetFrame has a RightButton-only MouseArea (z 50) so left clicks still reach controls; detach/remove go back to the frame via Widgets.detachRequested/removeRequested (frames know their neighbours). Widgets.groupOf(id) = all items on the attachedTo chain from the top; Widgets.updateMany for one save/undo step; group opacity in the menu and the edit toolbar. Test tool: vmouse.py gained rpress/rrelease (right button).
- Widget rows: WidgetFrame.leftOf/rightOf (left/right joins in both directions), leftWidth/rightWidth (sizes only), rowOf/rowChild; top/bottom scaleIn/slotPos/gap use the row; free() allows one spanning child per row side; joinedTop/Bottom also when a neighbour's spanning child covers this frame. attachTarget refuses a slot whose facing side of the dragged widget already has a child. Music type attach "any".
- Corners for controls: Theme.pill(h) = h/2 × min(1, corners) for buttons, chips, tabs, toggles (+knob), slider knob, fields, toolbars, OSD, lock field, workspace dots; real circles (art, swatches, clock faces, avatars) keep width/2.
- F9 Settings layouts: settings/NavSide.qml (sidebar or `rail`, sliding marker via selectedRow.mapToItem, rail names drawn outside the clipped Flickable) and settings/NavTabs.qml (scrolling tabs, sliding underline, reveal() keeps the tab in view); SettingsWindow positions nav/separator/page with plain x/y/width/height from Theme.settingsLayout (appearance.settingsLayout). Closing unloads via Qt.callLater (a direct `settings.loaded = false` in onOpacityChanged was a binding loop on the LazyLoader).
