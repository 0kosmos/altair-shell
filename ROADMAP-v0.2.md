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
- [x] 2. Clock popup with calendar
- [x] 3. Smooth workspace switching + Alt+Tab
- [x] 4. Precise moving (snapping + dim)
- [x] 5. Desktop widgets + edit mode
- [x] 6. Taskbar / dock
- [x] 7. UI sounds
- [ ] Release v0.2.0 (README screenshots, changelog, tag)

## Notes

(Add one line per finished feature here.)

- F1 transparency: services/WindowRules.qml sends named Lua rules `altair-opacity-<n>` via `hyprctl eval` (same name = replace, applies to open windows live; `opacity = "a override b override"` so it replaces the default instead of multiplying; a config reload drops them, re-sent on `configreloaded`). Default opacity = decoration.active/inactive_opacity in Hypr.qml (originals stored like blur). Kitty's own background_opacity was skipped (user's choice). JsonAdapter `var` lists arrive as Qt lists: use Array.from. Don't name QML properties `left`/`right` etc. (FINAL anchor lines).
- F2 calendar: calendar/CalendarPopup.qml (an AltairPanel docked "top"/"bottom" with fullWidth false; new `slideDistance` + scale for small edge panels) and calendar/MonthView.qml (reusable 6x7 grid, ready for the dashboard; agenda slot marked under the grid). Popup has its own SystemClock (hours) so the bar clock still ticks per minute. Clicking the clock while open relies on the focus grab closing it (like the bell); mouse clicks could not be tested by Claude, keyboard was (send_shortcut). Gotchas: an `id` shadows a same-named property inside functions; StyledText (Text) has read-only implicitWidth/Height, use Layout.preferred*; hot reload is unreliable here, restart with `hyprctl eval 'hl.exec_cmd(require("altair").restart_cmd)'`.
- F2 extra (user request): round clock (calendar/AnalogClock.qml, reusable for the F5 clock widget) left of the calendar; options bar.analogClock / bar.clockSeconds. Hands jump like a quartz clock: an eased seconds tick cost ~4 % CPU while open (180 ms) or ~2 % (70 ms) on this CPU vs 0.2 % plain.
- F3a workspaces (3b Alt+Tab still open, so not ticked): Hypr.applyWorkspaces sets the workspaces/In/Out animations at runtime (curve "altairWorkspace"; originals in hyprland-original.json `wsAnim`); bar pill uses Hypr.workspaceDuration + same bezier. Binds in hypr/init.lua (r-1 / r+1 / previous). Reader ignores reads that still contain "altair*" curves (overlapping instances during hot reload once stored our own values as the user's).
- F3b plan (agreed): Alt+Tab via Hyprland binds -> hl.dsp.global -> Quickshell GlobalShortcut (no process per key); Alt release = bind "ALT + Alt_L" with release = true; Qt key release + "no Alt held" checks as backup; previews = ScreencopyView live:false with icons fallback. Test the release bind FIRST.
- F3b Alt+Tab: alttab/AltTab.qml + WindowCard.qml; binds in hypr/init.lua -> hl.dsp.global("altair:alttab-*") -> GlobalShortcut (appid "altair"). Test without a keyboard: `hyprctl dispatch 'hl.dsp.global("altair:alttab-next")'` / `-release`. MRU kept from Hyprland.activeToplevel changes. Gotcha: while our overlay holds exclusive keyboard focus Hyprland ignores focus requests, so the focus dispatch waits 60 ms after closing. Quick tap (< 120 ms) never shows the overlay. Previews: ScreencopyView live:false (hyprland_toplevel_export) works on NVIDIA, +13 MiB while open, no leak over 11 opens.
- F3b fix: a global-shortcut event sent from a RELEASE bind only reaches the client with the next input event (0.57), so the Alt release is a bind with hl.dsp.event("altair:alttab-release") -> Hyprland rawEvent "custom" (event socket, immediate). Never add binds with hyprctl eval AND reload: duplicates make every Tab step twice.
- F4 snapping: services/Snap.qml (begin/place/end, global layout coords; `targets` is where F5 widgets register their rects), components/DragOverlay.qml (Top layer, empty mask, dim = huge-border rounded rect so the hole matches the window radius), services/Placement.qml (positions per monitor in $XDG_STATE_HOME/altair/positions.json). Settings window drags itself: new pos = last requested + (cursor - press) in window coords, one hl.dsp.window.move per event-loop pass. Monitor geometry: HyprlandMonitor x/y/width/height/scale are always set, `reserved` only after refreshMonitors(). SUPER+drag (Hyprland's) cannot snap. Snap maths, overlay, move and restore were tested via a temporary IPC hook; the mouse drag itself needs the user (no pointer injection here).
- Restart is now SIGKILL of exact PIDs (hypr/init.lua stop_cmd): `qs kill` + Quickshell's exit-time segfault + crash-handler relaunch once left no shell. If you see "Quickshell has crashed" on restart again, check ~/.cache/quickshell/crashes.
- F5a widgets (5b = music + stats, not ticked yet): services/Widgets.qml (types, items in config.json widgets.items, editing, selected), widgets/WidgetLayer.qml (per monitor, Bottom layer, Top + full input in edit mode, mask/blur = union of frame Regions, ScriptModel objectProp "id"), WidgetFrame.qml (move via Snap with targets = other widgets and dim:false, corner resize -> scale, toolbar for the selected widget), EditDock.qml. Add a type: entry in Widgets.types + <Name>Widget.qml + case in WidgetFrame. Cost: anything ticking per second on the blurred widget layer is ~0.75 % CPU here (so the round-clock widget has no seconds hand); 0 widgets = no layer at all.
- F5b: services/Media.qml (MPRIS: playing > last played > first), services/SysStats.qml (/proc every 2 s, nvidia-smi every 5 s if enabled; only while `users` > 0, paused when the focused workspace is fullscreen). MusicWidget asks for the position every 2 s only while playing (MPRIS doesn't push it). A widget can set `hidden` (music when idle) and WidgetFrame drops it from the blur/click region. Measured: clock + round clock + music (playing) + system with GPU: 0.23 % shell CPU, plus nvidia-smi ~13 ms CPU per call (~0.26 % at 5 s, so off by default).
- F5 extras (user requests): max 3 widgets per type; styles for music (card/disc/cover/minimal) and system (bars/rings/compact), per-style sizes (Widgets.sizeOf); Equalizer widget + music visualizer from cava (services/Cava.qml: config written to $XDG_RUNTIME_DIR, restarts after it has exited on setting changes, sensitivity/smoothing/fps options, mono); seekable song bar. Widgets get `live` = false while the monitor's workspace has a tiled/fullscreen window (Hyprland still asks covered layers for frames). Costs here: anything at 30 fps on the widget layer is ~6-7 % CPU, 60 fps ~13-15 %, plus cava ~2.5 %; covered 0.0-0.1 %. Floor for any redraw on this i7-3770/NVIDIA: ~3.5 % at 30 fps.
- F5 equalizer (part B): services/Equalizer.qml runs `pipewire -c $XDG_RUNTIME_DIR/altair-eq.conf` (needs protocol-native/client-node/adapter modules in the conf, else "can't find protocol") with a filter-chain sink "altair_eq_sink" (preamp highshelf at 0 Hz + lowshelf 60, peaking 150/400/1k/2.4k, highshelf 15k); gains live via `pw-cli set-param altair_eq_sink Props '{ params = [ "b1:Gain" 3.0 ] }'`; player streams moved with `pactl move-sink-input` (pactl index != PipeWire node id; match by application.name). Killing the filter makes PipeWire move streams back by itself (tested with SIGKILL). Widget type id "eq" ("equalizer" is the old name of the visualizer and is migrated). Part C (magnetic attach) still open.
- F5 part C (magnetic groups): item.attachedTo = id of the widget above (chains: music -> visualizer/eq -> ...). WidgetFrame computes parentFrame/childFrame from siblings, takes the parent's x/width when attached, the top frame draws one GlassBackground of groupHeight, attached frames z 1; attach on Snap.settled when within 28 px of a group's bottom (Widgets.attachHint shows the glow while dragging); dragging an attached one detaches it. The music widget's built-in visualizer was removed; the old `widgets.visualizer` setting is migrated once into attached Visualizer widgets.
- Groups on four sides: item.attachSide ("bottom" default/top/left/right). Music has 4 slots (left/right only for card/disc styles), attached widgets one slot further out on their own side; top/bottom take the parent's width, left/right its height. Each frame draws its own GlassBackground with open sides (shader extends the shape past them; tint over Frame.groupRoot.groupBox).
- Weather: services/Weather.qml (Open-Meteo forecast + geocoding via XMLHttpRequest, every 30 min only while a Weather widget exists, `configured` needs coordinates). Types have `attach`: "music" (visualizer/eq/lyrics) or "any" (weather); standalone hosts offer top/bottom, plus left/right when 2:1 wide, slots skipped if the child's scale would leave 0.45-2.5. Max 2 widgets per type. QML gotcha: a RowLayout of Repeater ColumnLayouts kept content width; explicit-width Row works.
- Lyrics: services/Lyrics.qml from LRCLIB (/api/get, fallback /api/search; header Lrclib-Client), in-memory cache of 60 tracks, only while a Lyrics widget exists. Synced LRC follows an estimated position (player position every 2 s + elapsed time, line check 4x/s, only `index` changes redraw); plain lyrics get an estimated line from progress, labelled. Qt's JS has no String.matchAll: use a regex exec loop.
- Screen recorder: services/Recorder.qml runs `gpu-screen-recorder -w <focused monitor> -f 60 -c mp4 -q high [-a default_output[|default_input]]`, stopped with Process.signal(2) (SIGINT saves the file); bar/RecordButton.qml. Measured: 1080p60 H.264 + Opus, recorder ~8 % of one core (NVENC). Seen once while dragging widgets: "Binding loop detected for property targetScale" (WidgetFrame.qml:203), not reproducible on start; look into it if it shows up again.
- F6 dock: services/DockApps.qml (items = pinned desktop ids from config + running Hyprland toplevels grouped by Wayland appId -> DesktopEntries.heuristicLookup, cached; Spotify matches spotify-launcher), dock/Dock.qml (one Top-layer strip per screen, full length so the dock resizes inside it; mask = dock or a 3 px trigger when auto-hidden; exclusiveZone 0 when not reserving so it still stacks next to the bar), DockItem.qml (zoom/tooltip/drag), DockMenu.qml (PopupWindow), components/MenuRow.qml (moved out of TrayMenu). Gotchas: a vertical layer surface needs BOTH top and bottom anchors or it ends up 1 px long and reserves nothing; changing anchors on a live surface misbehaves, so a position change rebuilds the window; the singleton can't be called `Dock` (clashes with the dock/Dock.qml type). `hl.dsp.cursor.move` warps the pointer but layer surfaces get no hover from it, so hover/drag/click need the user. IPC `dock list|pin|unpin|toggle`.
- Polish round after F6 (user requests, 2026-11-16): dock recent apps (state in dock.json, focus-tracked), add apps by search, slide-out/in on edge change, blur region never toggled (it flashed the whole surface); launcher fitContent (AltairPanel shrinks glass/blur/mask, window keeps its size) + in-window AppMenu (a popup surface fights the focus grab); desktop menu = its own Overlay PanelWindow (a popup of the Background-layer wallpaper is drawn under all windows), IPC `desktop menu`, power actions need a second click; widgets: Snap.extent keeps whole groups on screen, resting widgets clamp to the usable area and glide (Hyprland.refreshMonitors after bar/dock changes), fitW/fitH lets content size its frame, clock/roundclock/stats attach "any"; weather effects: GPU shader in a small Bottom-layer window over the widget (`altair-widget-fx`), because ANY animation inside the widget layer redraws the whole layer (~6 % here); equalizer filter stays up while enabled (removing the sink paused Spotify), unroute before stop; cava values decay on stop; lyrics schedule the next line exactly; panelfx.frag static panel decoration. Not tested by Claude (needs pointer/music): dock hover/drag/click, desktop right-click, lyrics motion, equalizer with music playing.
- Polish round 2 (2026-11-16): launcher AppMenu flips up (anchorY); widgets avoid bar + dock as obstacles with a 12 px gap (Snap.obstacles/avoid, DockApps.rects published by the dock), so they can sit beside the dock; dock blur Region uses explicit clipped coordinates (a Region tied to an invisible item covered the whole window strip); FrameOverlay = small Bottom-layer window over a widget for continuous motion (weather, karaoke); karaoke lyrics (KaraokeLine fills per laid-out line via onLineLaidOut); bar left/right (Theme.barVertical, BarButton/Tray are GridLayouts, AltairPanel docks left/right); calendar popup weather + tune menu (bar.clockStyle/calendarStyle/popupWeather); widget styles (clock stacked/split, weather big, stats graph with SysStats history), widget font via window property textFamily read by StyledText (QsWindow.window); edit toolbar (Widgets.selecting/picked/groupDelta/undo history); launcher ScriptModel + add/remove/displaced transitions (reset currentIndex on results change), finite caret blink; WallpaperTheme + PaletteExtractor + ThemeRow (palette "auto"). Gotchas: new files and new inline components need a full restart (hot reload says "X is not a type"); inline components must be declared at the file's root and can't see the file's ids. The weather longitude in the user's config was found reset to 0 this session (cause not found); watch for it.
- Polish round 3: FrameOverlay waits for Widgets.layerSettled (a layer that changes Top->Bottom is put above existing Bottom surfaces, so overlays made earlier ended up under the blurred widget glass); picker strip is a PathView (a function and a property with the same name in one object: the property wins, the call fails with "not a function"); bar drag = MouseArea under the bar items + ShellState.barDragTarget + BarMoveHint overlay; Lyrics index has back-step hysteresis (1.5 s). After many hot reloads `qs ipc` can answer "Not ready to accept queries yet" forever: restart the shell.
- F7 sounds: services/Sounds.qml plays via `pw-play` (execDetached; ~10 ms CPU, ~30 ms latency per sound, 0 idle). QtMultimedia SoundEffect was measured at +86 MiB (FFmpeg backend), rejected. Sounds are synthesised by scripts/gen-sounds.py (stdlib only) into assets/sounds/<glass|soft|minimal|bubble|wood|pulse>/ (CC0). Hooks live in the shared components (Toggle, Slider, IconButton/PillButton/MenuRow/Segmented: both a component's and an instance's onClicked run), so new controls get sounds for free. Click is deferred 30 ms and dropped if another sound follows (a button that opens a panel plays only "open"). Slider ticks: one per step, pitch = value (8 files), max 1 per 45 ms; continuous drags (hue, seek, music volume, EQ) use Sounds.slideBegin/slideTo buckets. Config: sounds.{enabled, volume, on.*, style.*, custom{}}; notification on/off stays notifications.sound. Also fixed: ShellState.openSettings(page) on a closed Settings window (requestedPage); Config saves are coalesced (30 ms timer, blockWrites) and our own saves no longer trigger a re-read: several changes in one go (sound "style for everything") used to revert 2-4 of them. IPC `sounds style <name>` sets all.
- After F7 (user requests, 2026-11-16): clock position (bar lays out workspaces/clock/status by hand along its length; AltairPanel.along = start/center/end for small edge panels); music widget built-in visualizer (item.vis per widget, offered modes per style in Widgets.types `vis`; Visualizer gained ringRadius/ringLength/ringLine and a "glow" style; styles marked `alone` (Visualizer circle) fall back while attached); network menu (connections/NetworkPanel + WifiRow; never `import Quickshell.Networking` in a file that uses our Network singleton: its `Network` type shadows it; details from nmcli once on open) and Bluetooth (services/Bt.qml, untested here: no adapter on the dev PC); display (services/Display.qml: ddcutil queue, logind backlight, generated screen shader in $XDG_RUNTIME_DIR/altair/screen-a|b.frag; grim/screencopy captures before the screen shader, so its effect can't be checked by screenshot). New panels must be added to ShellState.panels.
- Release prep (2026-11-16): cava hears only the player (PIPEWIRE_PROPS node.name=altair-cava, autoconnect=false, then pw-link player ports in; a stream as cava `source` falls back to the microphone); AlbumSpot `room` keeps ring/glow inside the music widget; attached widgets offer all sides but the one facing their parent; default wallpapers shipped (install.sh install_wallpapers); new screenshots (user's moewalls picks, credited) and CHANGELOG.md. Still to do for the tag (user said "not yet"): bump ShellState.version to 0.2.0, date the changelog, tag v0.2.0, create the GitHub repo and push.
