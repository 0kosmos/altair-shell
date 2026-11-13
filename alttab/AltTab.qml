// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.components
import qs.core
import qs.theme

// Alt+Tab window switcher.
//
// Detecting Alt on Wayland: an app only gets keys while it has keyboard focus,
// and Hyprland handles its own binds before any app. So the keys are Hyprland
// binds (hypr/init.lua) that reach us through Hyprland's global-shortcut
// protocol (GlobalShortcut below: no process per key press):
//   ALT + Tab / ALT + SHIFT + Tab  -> "alttab-next" / "alttab-prev"
//   releasing Alt (a release bind)  -> custom event "altair:alttab-release"
//                                      on Hyprland's event socket => commit
// Backups, so it can never stay open: while shown, the overlay has keyboard
// focus, so any key pressed without Alt held commits (and an Alt release, if
// Qt sees one); Escape or a click outside cancels.
//
// A quick Alt+Tab tap switches to the previous window without showing the
// overlay at all (it only appears after `showDelay`).
Scope {
    id: root

    readonly property int showDelay: 120

    // ---- State -----------------------------------------------------------------
    property bool active: false            // between the first Tab and commit/cancel
    property var windows: []               // snapshot of HyprlandToplevels, most recent first
    property int index: 0

    // Most-recently-used order, as addresses. Kept up to date from focus
    // changes (event-driven, no polling).
    property var mru: []
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            const a = Hyprland.activeToplevel?.address;
            if (a)
                root.mru = [a].concat(root.mru.filter(x => x !== a)).slice(0, 200);
        }
    }

    function snapshot(): var {
        const list = Hyprland.toplevels.values.filter(t => t.lastIpcObject?.mapped !== false);
        // Not seen focused yet (e.g. focused before the shell started): fall back
        // to Hyprland's own focus history.
        const rank = t => {
            const i = mru.indexOf(t.address);
            return i !== -1 ? i : 1000 + (t.lastIpcObject?.focusHistoryID ?? 999);
        };
        return list.sort((a, b) => rank(a) - rank(b));
    }

    function step(delta: int): void {
        if (!active) {
            windows = snapshot();
            if (windows.length === 0)
                return;
            active = true;
            index = windows.length > 1 ? (delta > 0 ? 1 : windows.length - 1) : 0;
            showTimer.restart();
        } else if (windows.length > 0) {
            index = (index + delta + windows.length) % windows.length;
        }
    }

    function commit(source: string): void {
        if (!active)
            return;
        const t = windows[index];
        const shown = ShellState.openPanel === "alttab";
        finish();
        if (t) {
            const a = t.address.startsWith("0x") ? t.address : "0x" + t.address;
            focusTimer.command = `hl.dsp.focus({ window = "address:${a}" })`;
            // While the overlay holds exclusive keyboard focus Hyprland ignores
            // a focus request, so wait until it has let go (it does so as it
            // starts closing). A quick tap never showed it: focus right away.
            focusTimer.interval = shown ? 60 : 0;
            focusTimer.restart();
        }
        console.info("altair: alt-tab -> " + (t?.title ?? "nothing") + " (via " + source + ")");
    }

    function cancel(): void {
        if (active)
            finish();
    }

    function finish(): void {
        active = false;
        showTimer.stop();
        if (ShellState.openPanel === "alttab")
            ShellState.close();
    }

    // Focusing a window also switches to its workspace.
    Timer {
        id: focusTimer
        property string command
        onTriggered: Hyprland.dispatch(command)
    }

    Timer {
        id: showTimer
        interval: root.showDelay
        onTriggered: if (root.active) ShellState.open("alttab")
    }

    // The overlay closed some other way (Escape, click outside, another panel).
    Connections {
        target: ShellState
        function onOpenPanelChanged() {
            if (ShellState.openPanel !== "alttab" && root.active && !showTimer.running)
                root.cancel();
        }
    }

    GlobalShortcut {
        appid: "altair"
        name: "alttab-next"
        description: "Alt+Tab: next window"
        onPressed: root.step(1)
    }
    GlobalShortcut {
        appid: "altair"
        name: "alttab-prev"
        description: "Alt+Tab: previous window"
        onPressed: root.step(-1)
    }
    // Alt released: a custom event on Hyprland's event socket (see the binds in
    // hypr/init.lua for why this is not a global shortcut).
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "custom" && event.data === "altair:alttab-release")
                root.commit("Alt released");
        }
    }

    // ---- Overlay ----------------------------------------------------------------
    readonly property int cardWidth: 216
    readonly property int visibleCards: Math.max(1, Math.min(windows.length, 6))

    AltairPanel {
        name: "alttab"
        centerVertically: true
        panelWidth: root.visibleCards * root.cardWidth + Theme.space.m * 2
        panelHeight: 176 + Theme.space.m * 2

        content: Component {
            FocusScope {
                focus: true

                // Backup for the release bind: we have keyboard focus while shown.
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Alt || !(event.modifiers & Qt.AltModifier))
                        root.commit("key release");
                }
                Keys.onPressed: event => {
                    const modifierKey = [Qt.Key_Alt, Qt.Key_Shift, Qt.Key_Control, Qt.Key_Meta, Qt.Key_Super_L].indexOf(event.key) !== -1;
                    if (!(event.modifiers & Qt.AltModifier) && event.key !== Qt.Key_Escape && !modifierKey) {
                        root.commit("key without Alt");
                    } else if (event.key === Qt.Key_Left) {
                        root.step(-1);
                    } else if (event.key === Qt.Key_Right) {
                        root.step(1);
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.commit("Enter");
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: Theme.space.m
                    orientation: ListView.Horizontal
                    model: root.windows
                    currentIndex: root.index
                    interactive: false
                    // Keep the selection visible when there are more than fit.
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: root.cardWidth
                    preferredHighlightEnd: width - root.cardWidth
                    highlightMoveDuration: Theme.anim.fast
                    highlight: Rectangle {
                        radius: Theme.radius.m
                        color: Qt.alpha(Theme.accent, 0.16)
                        border.width: 1.5
                        border.color: Qt.alpha(Theme.accent, 0.7)
                    }

                    delegate: WindowCard {
                        required property var modelData
                        required property int index
                        toplevel: modelData
                        selected: index === root.index
                        previews: Config.alttab.previews
                        onActivated: {
                            root.index = index;
                            root.commit("click");
                        }
                    }
                }
            }
        }
    }
}
