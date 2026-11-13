# Altair v0.2 roadmap

This file is the plan for Altair v0.2. Work through it one feature at a time.
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
4. Stop and tell me it's done. I will run `/clear` and start the next feature
   in a fresh session, so never rely on chat history: this file, CLAUDE.md and
   git are the memory.
5. If a feature turns out too big or too expensive in usage, say so and
   propose a smaller version before building.

## Rules for every feature

- Performance first: near 0% idle CPU, no polling loops, components load
  lazily and are destroyed when closed or disabled.
- Every new option lives in config.json, appears in the settings app, has a
  sensible default and can be turned off.
- Low-power mode turns off blur, sounds and non-essential animations.
- Never rewrite my hyprland.lua. Anything Hyprland needs goes through the
  `altair` Lua module or hyprctl at runtime. Keep the escape-hatch binds working.
- Use the existing theme (palette, accent, blur, animation speed) everywhere.
  Animations must look smooth at 165 Hz and respect the animations toggle.
- Update README (features, keybinds, dependency table), install.sh (new
  dependencies), and CREDITS.md (any third-party asset with source + licence;
  never invent a licence).
- No personal data in files or commits.

---

## Feature 1: Window transparency

Goal: make terminals and chosen apps slightly see-through, adjustable in settings.

- Settings page "Transparency": a global default opacity slider, plus a list of
  app rules. Each rule: app (picked from currently open windows, or typed
  window class), opacity 0-100%, inactive-window opacity, optional blur behind.
- Ship ready-made suggestions for common apps (kitty, Spotify, Discord,
  Firefox, Dolphin) that I can enable with one click.
- For kitty, compare kitty's own `background_opacity` (text stays fully
  opaque) with whole-window opacity, pick the better-looking one and explain why.
- Apply live, restore on shell start, and remove cleanly on uninstall.
  Tell me which Hyprland mechanism you used (Lua window rules vs hyprctl) and why.

Done when: changing a slider updates the window instantly, survives a
restart of Altair and of Hyprland, and does nothing in low-power mode except
keep opacity (blur off).

## Feature 2: Clock popup with calendar

- Clicking the date/time in the bar opens a small popup under it with an
  animated open (fade + slight slide/scale) and a month calendar: today
  highlighted, arrows or scroll to change month, click month title to go back
  to today.
- Leave a clear spot for a future agenda/events list, but don't build it.
- Closes on outside click, Escape, or clicking the clock again.

Done when: it opens and closes smoothly, follows the theme, and the clock in
the bar still updates only once a minute.

## Feature 3: Smooth workspace switching + Alt+Tab

- Workspace animation: a clean slide or fade (configurable style, speed,
  on/off). Use Hyprland's own workspace animations via the `altair` module.
  The bar's workspace pill must stay in sync with the animation.
- Alt+Tab window switcher: holding Alt and pressing Tab opens an overlay with
  window previews (or app icons + titles if previews are too expensive),
  Tab/Shift+Tab move the selection, releasing Alt focuses the selected window
  and switches workspace if needed. Escape cancels. Animated open/close.
  Explain how you detect Alt release on Wayland before building it.
- Extra keybinds with the same animation: Super+Ctrl+Left/Right to go to the
  previous/next workspace, and Super+Tab to go back to the last used workspace.
- All keybinds configurable in settings (or at least in `setup()` options),
  documented in README.

Done when: switching feels smooth at 165 Hz, Alt+Tab never gets stuck open,
and the escape-hatch binds still work.

## Feature 4: Precise window and widget moving (snapping + dim)

- A shared drag system used by the settings window now and by widgets later.
- While dragging: the rest of the screen dims slightly (animated overlay,
  amount adjustable), and alignment guide lines appear at the screen centre
  (both axes), screen edges, and the edges/centres of other widgets or panels,
  with magnetic snapping within a few pixels. Hold Shift to drag without snapping.
- Snap-to-grid option with adjustable grid size.
- Positions are saved per monitor and clamped so nothing ends up off-screen
  after a resolution change.

Done when: the settings window snaps to the centre lines and edges, guides
fade in and out smoothly, and nothing runs while no drag is happening.

## Feature 5: Desktop widgets + edit mode

- Edit mode, opened by a keybind and a button in settings: the background
  dims, widgets show handles, a widget dock slides up from the bottom listing
  available widgets, and a "Done" button saves and leaves edit mode.
- Each widget: drag (using Feature 4 snapping), resize, opacity slider,
  remove. Several copies of the same widget allowed.
- First widgets: clock (big time + date), music player (MPRIS: album art,
  title, artist, progress bar, previous/play-pause/next; hidden or compact
  when nothing plays), system stats (CPU, RAM, optionally GPU temperature via
  nvidia-smi only while visible and at a slow interval).
- A widget that isn't on screen must cost nothing.

Done when: I can add, move, resize, change opacity and remove widgets, and
the layout survives a restart. Report idle CPU/RAM with 0 widgets and with
all three.

## Feature 6: Taskbar / dock

- Optional dock (off by default): pinned apps + running apps from Hyprland,
  click to launch or focus, right-click for pin/unpin and close, indicator
  dot for running apps and the focused one, cheap hover zoom animation.
- Settings: on/off, position (bottom/left/right), icon size, auto-hide,
  and whether it reserves screen space.
- Drag apps in the dock to reorder pinned apps.

Done when: it tracks open and closed windows correctly without polling and
can be fully disabled.

## Feature 7: UI sounds

- Style: minimal/clean, glass/crystal and modern. Very short, soft, light, no
  reverb tails, never harsh or loud.
- Events (each its own category): notification, menu/panel open, menu/panel
  close, click, toggle on, toggle off, typing (launcher and search fields
  only), volume change, edit-mode enter/exit, snap (when a drag snaps to a guide).
- Per event: 3 built-in options (e.g. "Glass", "Soft", "Minimal"), "Off", or
  a custom file (wav/ogg) chosen in settings. Validate custom files, fall back
  to the default if missing or invalid, never crash.
- Settings "Sounds" page: master on/off, master volume, per-event toggle,
  option picker and a preview button. Add an IPC call:
  `qs -c altair ipc call sounds play <event>`.
- Defaults: notifications on, everything else off.
- Sources: free sounds with compatible licences (CC0 preferred, e.g. Kenney,
  Freesound CC0). If you can't find good ones, tell me and suggest options.
  Let me preview sounds before you commit to them.
- Load sounds lazily, zero idle CPU, typing sounds must add no input latency,
  all sounds off in low-power mode.

Done when: every event plays the chosen sound, custom files work, and
perf.sh shows no idle cost.

---

## Checklist

- [x] 1. Window transparency
- [ ] 2. Clock popup with calendar
- [ ] 3. Smooth workspace switching + Alt+Tab
- [ ] 4. Precise moving (snapping + dim)
- [ ] 5. Desktop widgets + edit mode
- [ ] 6. Taskbar / dock
- [ ] 7. UI sounds
- [ ] Release v0.2.0 (README screenshots, changelog, tag)

## Notes

(Add one line per finished feature here.)

- F1 transparency: services/WindowRules.qml sends named Lua rules `altair-opacity-<n>` via `hyprctl eval` (same name = replace, applies to open windows live; `opacity = "a override b override"` so it replaces the default instead of multiplying; a config reload drops them, re-sent on `configreloaded`). Default opacity = decoration.active/inactive_opacity in Hypr.qml (originals stored like blur). Kitty's own background_opacity was skipped (user's choice). JsonAdapter `var` lists arrive as Qt lists: use Array.from. Don't name QML properties `left`/`right` etc. (FINAL anchor lines).
