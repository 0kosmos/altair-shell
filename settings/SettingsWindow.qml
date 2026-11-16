// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.components
import qs.core
import qs.services
import qs.theme

// The Settings app: a normal (floating) window with a sidebar. Open with
// SUPER+comma, "Altair Settings" in the launcher, or
// `qs -c altair ipc call panels toggle settings`.
// Every change is saved to ~/.config/altair/config.json immediately.
//
// It is an ordinary window, so Hyprland's window rules apply: hypr/init.lua
// makes it float, centred, at 1120x700 with corner rounding matching ours
// (class org.quickshell, this title).
Scope {
    id: settings

    // Whether the window exists. Set true when Settings opens, and false only
    // after the fade-out (or right away if Hyprland closed the window).
    // NOTE: one flag on purpose. "open || closing" let the loader see both as
    // false for a moment on close, destroy the window and build a new one.
    property bool loaded: false
    readonly property bool wanted: ShellState.settingsOpen
    onWantedChanged: if (wanted && !loaded) placer.open()

    // Before the window exists, tell Hyprland where it goes (its saved spot on
    // the focused monitor, kept on screen; else centred), so it appears there
    // instead of jumping from the centre. See M.place_settings in hypr/init.lua.
    Process {
        id: placer

        function open(): void {
            const mon = Snap.monitorInfo(Hyprland.focusedMonitor);
            const saved = Placement.get("settings", mon.name);
            let args = "nil, nil";
            if (saved) {
                const r = Snap.clampTo({ x: mon.x + saved.x, y: mon.y + saved.y, w: 1120, h: 700 }, mon);
                args = r.x + ", " + r.y;
            }
            // The window's corner rounding follows Settings > Appearance > Corners.
            args += ", " + Theme.radius.l;
            // pcall: an older hypr/init.lua without place_settings just centres.
            command = ["hyprctl", "eval", `local ok, a = pcall(require, "altair") if ok and a.place_settings then a.place_settings(${args}) end`];
            running = true;
            placeFallback.restart();
        }
        onExited: if (settings.wanted) settings.loaded = true
    }
    // In case hyprctl hangs or cannot start: open anyway.
    Timer {
        id: placeFallback
        interval: 400
        onTriggered: if (settings.wanted) settings.loaded = true
    }
    // Safety net, in case the fade-out never finishes.
    Timer {
        running: settings.loaded && !settings.wanted
        interval: Theme.anim.slow + 400
        onTriggered: settings.loaded = false
    }

    LazyLoader {
        active: settings.loaded

        FloatingWindow {
            id: win

            title: "Altair Settings"
            implicitWidth: 1120
            implicitHeight: 700
            minimumSize: Qt.size(760, 520)
            // The background is drawn by GlassBackground below (so liquid glass
            // applies here too); the window itself is transparent.
            color: "transparent"

            // A page asked for before the window existed (openSettings() on a
            // closed window) is waiting in ShellState.requestedPage.
            // A page asked for before this window existed waits in
            // ShellState.requestedPage (taken in Component.onCompleted below).
            property string page: "appearance"
            Connections {
                target: ShellState
                function onSettingsPageRequested(p) { win.page = p; }
            }
            // Sidebar entries, grouped. Add a page: an entry here + a case in
            // pageSource() below + a <Name>Page.qml file.
            readonly property var pages: [
                { id: "appearance", label: "Appearance", icon: "palette", group: "Personalise" },
                { id: "wallpaper", label: "Wallpaper", icon: "wallpaper", group: "Personalise" },
                { id: "bar", label: "Bar", icon: "toolbar", group: "Personalise" },
                { id: "dock", label: "Dock", icon: "dock_to_bottom", group: "Personalise" },
                { id: "windows", label: "Windows", icon: "select_window", group: "Desktop" },
                { id: "transparency", label: "Transparency", icon: "opacity", group: "Desktop" },
                { id: "widgets", label: "Widgets", icon: "widgets", group: "Desktop" },
                { id: "effects", label: "Effects", icon: "auto_awesome", group: "Desktop" },
                { id: "display", label: "Display", icon: "brightness_6", group: "System" },
                { id: "clipboard", label: "Clipboard", icon: "content_paste", group: "System" },
                { id: "lock", label: "Lock & power", icon: "lock", group: "System" },
                { id: "notifications", label: "Notifications", icon: "notifications", group: "System" },
                { id: "sounds", label: "Sounds", icon: "volume_up", group: "System" },
                { id: "performance", label: "Performance", icon: "speed", group: "System" },
                { id: "about", label: "About", icon: "info", group: "System" },
            ]

            // Closed by Hyprland (e.g. SUPER+C): the window is already gone, so
            // no fade; drop it right away and keep our state in sync.
            onVisibleChanged: {
                if (!visible) {
                    settings.loaded = false;
                    ShellState.settingsOpen = false;
                }
            }

            // Mostly solid: a settings page needs readable text more than glass.
            // Hyprland draws the window border, so no hairline border of our own.
            // Radius = the window rounding set by the rule in hypr/init.lua.
            // Everything fades in and grows from 98 % on open (Hyprland's own
            // animation is off for this window, see the rule in hypr/init.lua).
            Item {
                id: body
                anchors.fill: parent
                opacity: 0
                scale: 0.98
                Component.onCompleted: openAnim.start()

                ParallelAnimation {
                    id: openAnim
                    NumberAnimation { target: body; property: "opacity"; to: 1; duration: Theme.anim.normal; easing.type: Theme.anim.easing }
                    NumberAnimation { target: body; property: "scale"; to: 1; duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide }
                }

                // Closing: the opening animation in reverse, then the window goes.
                ParallelAnimation {
                    id: closeAnim
                    NumberAnimation { target: body; property: "opacity"; to: 0; duration: Theme.anim.normal; easing.type: Theme.anim.easingIn }
                    NumberAnimation { target: body; property: "scale"; to: 0.98; duration: Theme.anim.normal; easing.type: Theme.anim.easingIn }
                    onFinished: settings.loaded = false
                }

                Connections {
                    target: ShellState
                    function onSettingsOpenChanged() {
                        if (ShellState.settingsOpen) {
                            closeAnim.stop();
                            openAnim.start();
                        } else {
                            openAnim.stop();
                            closeAnim.start();
                        }
                    }
                }

                // Empty spots (sidebar, margins): drag to move the window (with
                // snapping), double-click to re-centre keeping the size (Ctrl+0
                // also resets the size). Controls on top take their own clicks;
                // pages report double-clicks via backgroundDoubleClicked and
                // drags on their title via dragController.
                MouseArea {
                    anchors.fill: parent
                    onDoubleClicked: win.recenter()
                    onPressed: mouse => dragger.press(this, mouse)
                    onPositionChanged: mouse => dragger.move(this, mouse)
                    onReleased: dragger.release()
                    onCanceled: dragger.release()
                }

                // Radius deliberately SMALLER than Hyprland's window rounding (18,
                // see hypr/init.lua): Hyprland cuts the corners itself, and with
                // equal radii the two anti-aliased curves left tiny see-through
                // spots in the corners.
                GlassBackground {
                    anchors.fill: parent
                    radius: Theme.radius.m
                    bordered: false
                    solidity: 0.85
                    rim: 0.35
                }

                FocusScope {
                    anchors.fill: parent
                    focus: true
                    // A panel opened on top (wallpaper picker, launcher, ...) owns
                    // the keyboard: Escape closes it first, and Settings ignores
                    // its own keys while it is open.
                    Keys.onEscapePressed: {
                        if (ShellState.openPanel !== "")
                            ShellState.close();
                        else
                            ShellState.settingsOpen = false;
                    }
                    // Keyboard: Ctrl+0 resets to the default size, centred; Tab / Shift+Tab and Left/Right
                    // switch pages; Up/Down scroll, and at the end of a page (or on
                    // a page that fits) move to the next/previous page (only on a
                    // fresh press, so holding a key never races through pages);
                    // PageUp/PageDown, Home/End scroll. Focused controls get keys
                    // first (text fields, sliders), so they keep working.
                    Keys.onPressed: event => {
                        if (ShellState.openPanel !== "")
                            return;
                        const page = pageLoader.item;
                        const ctrl = event.modifiers & Qt.ControlModifier;
                        if (event.key === Qt.Key_0 && ctrl)
                            win.resetGeometry();
                        // Shift+Tab arrives as Backtab, or as Tab with Shift held
                        // (depends on keyboard/layout): treat both as "back".
                        else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)))
                            win.stepPage(-1);
                        else if (event.key === Qt.Key_Tab)
                            win.stepPage(1);
                        else if (event.key === Qt.Key_Right)
                            win.stepPage(1);
                        else if (event.key === Qt.Key_Left)
                            win.stepPage(-1);
                        else if (page && event.key === Qt.Key_Down) {
                            if (page.atEnd(1)) {
                                if (!event.isAutoRepeat)
                                    win.stepPage(1);
                            } else {
                                page.scrollBy(70);
                            }
                        } else if (page && event.key === Qt.Key_Up) {
                            if (page.atEnd(-1)) {
                                if (!event.isAutoRepeat)
                                    win.stepPage(-1);
                            } else {
                                page.scrollBy(-70);
                            }
                        }
                        else if (page && event.key === Qt.Key_PageDown)
                            page.scrollBy(page.height * 0.85);
                        else if (page && event.key === Qt.Key_PageUp)
                            page.scrollBy(-page.height * 0.85);
                        else if (page && event.key === Qt.Key_Home)
                            page.scrollTo(0);
                        else if (page && event.key === Qt.Key_End)
                            page.scrollTo(page.maxY);
                        else
                            return;
                        event.accepted = true;
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        // ---- Sidebar ------------------------------------------------
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 230
                            color: Theme.surfaceRaised
                            topLeftRadius: Theme.radius.m
                            bottomLeftRadius: Theme.radius.m

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.space.m
                                spacing: 2

                                StyledText {
                                    Layout.leftMargin: Theme.space.s
                                    Layout.topMargin: Theme.space.s
                                    Layout.bottomMargin: Theme.space.m
                                    text: "Settings"
                                    font.pixelSize: Theme.font.title
                                    font.weight: Font.DemiBold
                                }

                                Repeater {
                                    model: win.pages

                                    ColumnLayout {
                                        id: entry
                                        required property var modelData
                                        required property int index
                                        readonly property bool firstOfGroup: index === 0 || win.pages[index - 1].group !== modelData.group

                                        Layout.fillWidth: true
                                        spacing: 2

                                        // Group heading above the first page of each group.
                                        StyledText {
                                            visible: entry.firstOfGroup
                                            Layout.leftMargin: Theme.space.s
                                            Layout.topMargin: entry.index === 0 ? 0 : Theme.space.m
                                            Layout.bottomMargin: 2
                                            text: entry.modelData.group
                                            color: Theme.fgDisabled
                                            font.pixelSize: Theme.font.small
                                            font.weight: Font.DemiBold
                                            font.capitalization: Font.AllUppercase
                                            font.letterSpacing: 0.6
                                        }

                                        MouseArea {
                                            id: nav
                                            readonly property var modelData: entry.modelData
                                            readonly property bool selected: win.page === modelData.id

                                            Layout.fillWidth: true
                                            implicitHeight: 38
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.page = modelData.id
                                            scale: pressed ? Theme.anim.pressScale : 1
                                            Behavior on scale {
                                                NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: Theme.radius.s
                                                color: nav.selected ? Qt.alpha(Theme.accent, 0.16)
                                                    : nav.containsMouse ? Theme.hover : "transparent"
                                                Behavior on color {
                                                    ColorAnimation { duration: Theme.anim.fast }
                                                }
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: Theme.space.s
                                                spacing: Theme.space.s

                                                Icon {
                                                    name: nav.modelData.icon
                                                    fill: nav.selected ? 1 : 0
                                                    color: nav.selected ? Theme.accent : Theme.fgMuted
                                                }
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: nav.modelData.label
                                                    font.weight: nav.selected ? Font.DemiBold : Font.Normal
                                                }
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                StyledText {
                                    Layout.leftMargin: Theme.space.s
                                    // Wraps: a long line would widen the whole sidebar layout.
                                    Layout.fillWidth: true
                                    Layout.rightMargin: Theme.space.s
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideNone
                                    text: "Altair " + ShellState.version + "\nArrows / Tab: scroll and switch pages\nDouble-click an empty spot to re-centre\nCtrl+0: default size"
                                    color: Theme.fgDisabled
                                    font.pixelSize: Theme.font.small
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillHeight: true
                            implicitWidth: 1
                            color: Theme.border
                        }

                        // ---- Page (only the visible one exists) ---------------------
                        // Switching pages: the old one fades out, the new one fades
                        // in while sliding up a little.
                        Loader {
                            id: pageLoader
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            source: win.pageSource(win.shownPage)

                            transform: Translate { id: pageShift }

                            onLoaded: if (item.dragController !== undefined) item.dragController = dragger

                            Connections {
                                target: pageLoader.item
                                ignoreUnknownSignals: true
                                function onBackgroundDoubleClicked() {
                                    win.recenter();
                                }
                            }
                        }
                    }
                }
            }

            property string shownPage: page
            // Compile every page in the background when Settings opens, so
            // switching to one later doesn't stall (Qt caches the types).
            property var precompiled: []
            Component.onCompleted: {
                if (ShellState.requestedPage !== "") {
                    page = ShellState.requestedPage;
                    shownPage = page;
                    ShellState.requestedPage = "";
                }
                Qt.callLater(() => {
                    win.precompiled = pages.map(p => Qt.createComponent(win.pageSource(p.id), Component.Asynchronous));
                });
            }
            onPageChanged: {
                if (Theme.anim.fast === 0) {
                    shownPage = page;
                    return;
                }
                pageSwap.restart();
            }

            SequentialAnimation {
                id: pageSwap
                NumberAnimation { target: pageLoader; property: "opacity"; to: 0; duration: 90; easing.type: Theme.anim.easingIn }
                ScriptAction { script: win.shownPage = win.page }
                PropertyAction { target: pageShift; property: "y"; value: 10 }
                // Loading a page blocks for a moment; the animation clock keeps
                // running meanwhile, which made the fade-in jump (it looked
                // like the page reloaded). This pause swallows that time, so
                // the fade always starts from the beginning.
                PauseAnimation { duration: 30 }
                ParallelAnimation {
                    NumberAnimation { target: pageLoader; property: "opacity"; to: 1; duration: Theme.anim.normal; easing.type: Theme.anim.easing }
                    NumberAnimation { target: pageShift; property: "y"; to: 0; duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide }
                }
            }

            // Default size, centred on the monitor (via Hyprland: it owns the
            // window's position).
            // Next/previous page in the sidebar, wrapping around.
            function stepPage(delta: int): void {
                const i = pages.findIndex(p => p.id === page);
                page = pages[(i + delta + pages.length) % pages.length].id;
            }

            function recenter(): void {
                Placement.clear("settings");   // next time: centred again
                Hypr.centerWindowByTitle(win.title);
            }

            // ---- Moving with snapping (services/Snap.qml) -------------------
            // Hyprland owns the window's position, so we move it ourselves:
            // new position = last requested + (cursor - press point), both in
            // window coordinates. (Events already in flight still use the old
            // position; that error lasts one event and never accumulates.)
            QtObject {
                id: dragger

                property bool pressed: false
                property bool active: false
                property point pressAt
                property real reqX
                property real reqY
                property var size: null
                property var mon: null
                property string address

                function scene(area: Item, mouse: var): point {
                    return area.mapToItem(null, mouse.x, mouse.y);
                }

                function press(area: Item, mouse: var): void {
                    // Grabbed again while still settling: start a fresh drag.
                    if (active)
                        Snap.settling = false;
                    pressed = true;
                    active = false;
                    pressAt = scene(area, mouse);
                    // Fresh positions before the drag really starts (4 px later).
                    Hyprland.refreshToplevels();
                    Hyprland.refreshMonitors();
                }

                function move(area: Item, mouse: var): void {
                    if (!pressed)
                        return;
                    const p = scene(area, mouse);
                    if (!active) {
                        if (Math.hypot(p.x - pressAt.x, p.y - pressAt.y) < 4)
                            return;
                        const t = Hypr.windowByTitle(win.title);
                        const o = t?.lastIpcObject;
                        if (!o?.at)
                            return;
                        address = t.address;
                        reqX = o.at[0];
                        reqY = o.at[1];
                        size = { w: o.size?.[0] ?? win.width, h: o.size?.[1] ?? win.height };
                        mon = Snap.monitorInfo(Hyprland.monitors.values.find(m => m.id === o.monitor) ?? Hyprland.focusedMonitor);
                        // = the window rounding (hypr/init.lua, place_settings).
                        Snap.begin(mon, Theme.radius.l, { x: reqX, y: reqY, w: size.w, h: size.h });
                        active = true;
                    }
                    const free = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                    // reqX/Y = where we last put the window, i.e. where it is
                    // (the pointer position is relative to that).
                    Snap.update({ x: reqX + p.x - pressAt.x, y: reqY + p.y - pressAt.y, w: size.w, h: size.h }, free);
                }

                // Snap.rect follows the pointer smoothly, every frame, and
                // keeps gliding for a moment after release.
                readonly property var placed: active ? Snap.rect : null
                onPlacedChanged: if (placed && (placed.x !== reqX || placed.y !== reqY)) Qt.callLater(flush)

                // At most one move per event-loop pass.
                function flush(): void {
                    if (!active || !Snap.rect)
                        return;
                    reqX = Snap.rect.x;
                    reqY = Snap.rect.y;
                    Hypr.moveWindow(address, reqX, reqY);
                }

                // Let go: Snap glides it to rest (onto the grid, if set); the
                // final spot is saved once it has settled.
                function release(): void {
                    pressed = false;
                    if (active)
                        Snap.end();
                }

                property Connections settle: Connections {
                    target: Snap
                    function onSettled(rect) {
                        if (!dragger.active)
                            return;
                        dragger.flush();
                        Placement.set("settings", dragger.mon.name, { x: rect.x - dragger.mon.x, y: rect.y - dragger.mon.y });
                        dragger.active = false;
                    }
                }
            }

            // Back where it was last dropped on this monitor (kept inside the
            // usable area, e.g. after a resolution change). Hyprland's rule
            // centres it first; the content is still fading in when we move it.
            Timer {
                id: restorer
                property int tries: 0
                interval: 40
                repeat: true
                running: true
                Component.onCompleted: Hyprland.refreshMonitors()
                onTriggered: {
                    const t = Hypr.windowByTitle(win.title);
                    if (!t?.lastIpcObject?.at) {
                        if (++tries > 15)
                            stop();
                        else
                            Hyprland.refreshToplevels();
                        return;
                    }
                    stop();
                    const o = t.lastIpcObject;
                    const mon = Snap.monitorInfo(Hyprland.monitors.values.find(m => m.id === o.monitor) ?? Hyprland.focusedMonitor);
                    const saved = Placement.get("settings", mon.name);
                    if (!saved)
                        return;
                    const r = Snap.clampTo({ x: mon.x + saved.x, y: mon.y + saved.y, w: o.size?.[0] ?? win.width, h: o.size?.[1] ?? win.height }, mon);
                    // Normally Hyprland already placed it there (placer above);
                    // this only corrects it (e.g. with an older hypr/init.lua).
                    if (Math.abs(o.at[0] - r.x) > 2 || Math.abs(o.at[1] - r.y) > 2)
                        Hypr.moveWindow(t.address, r.x, r.y);
                }
            }

            function resetGeometry(): void {
                Placement.clear("settings");
                Hypr.resetWindowByTitle(win.title, win.implicitWidth, win.implicitHeight);
            }

            function pageSource(id: string): string {
                switch (id) {
                case "wallpaper": return "WallpaperPage.qml";
                case "bar": return "BarPage.qml";
                case "dock": return "DockPage.qml";
                case "windows": return "WindowsPage.qml";
                case "transparency": return "TransparencyPage.qml";
                case "widgets": return "WidgetsPage.qml";
                case "effects": return "EffectsPage.qml";
                case "display": return "DisplayPage.qml";
                case "lock": return "LockPage.qml";
                case "clipboard": return "ClipboardPage.qml";
                case "notifications": return "NotificationsPage.qml";
                case "sounds": return "SoundsPage.qml";
                case "performance": return "PerformancePage.qml";
                case "about": return "AboutPage.qml";
                default: return "AppearancePage.qml";
                }
            }
        }
    }
}
