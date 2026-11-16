// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.core
import qs.services
import qs.theme

// Power menu (SUPER + Escape, `qs -c altair ipc call panels toggle power`):
// lock, suspend, (hibernate), log out, restart, shut down. A full-screen
// overlay on the focused monitor that only exists while open.
// Log out / restart / shut down run after a countdown (lock.powerCountdown
// seconds, 0 = at once) that Escape, a click or Cancel stops.
Scope {
    id: root

    readonly property bool open: ShellState.openPanel === "power"
    property bool loaded: false
    onOpenChanged: if (open) loaded = true
    Timer {
        running: root.loaded && !root.open
        interval: Theme.anim.slow + 150
        onTriggered: root.loaded = false
    }

    // Hibernate only where the system supports it (asked on open).
    property bool canHibernate: false
    Process {
        running: root.open
        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1",
            "org.freedesktop.login1.Manager", "CanHibernate"]
        stdout: StdioCollector {
            onStreamFinished: root.canHibernate = text.trim() === 's "yes"'
        }
    }

    readonly property var actions: [
        { id: "lock", label: "Lock", icon: "lock", key: Qt.Key_L, confirm: false },
        { id: "suspend", label: "Suspend", icon: "bedtime", key: Qt.Key_S, confirm: false },
        { id: "hibernate", label: "Hibernate", icon: "downloading", key: Qt.Key_H, confirm: false },
        { id: "logout", label: "Log out", icon: "logout", key: Qt.Key_O, confirm: true },
        { id: "reboot", label: "Restart", icon: "restart_alt", key: Qt.Key_R, confirm: true },
        { id: "poweroff", label: "Shut down", icon: "power_settings_new", key: Qt.Key_D, confirm: true }
    ].filter(a => a.id !== "hibernate" || root.canHibernate)

    // ALTAIR_POWER_DRY_RUN=1: only log (for testing the menu).
    readonly property bool dryRun: Quickshell.env("ALTAIR_POWER_DRY_RUN") === "1"
    function run(id: string): void {
        console.info("altair: power action " + id + (dryRun ? " (dry run)" : ""));
        ShellState.close();
        if (dryRun)
            return;
        switch (id) {
        case "lock": Locker.lock(); break;
        case "suspend": Quickshell.execDetached(["systemctl", "suspend"]); break;
        case "hibernate": Quickshell.execDetached(["systemctl", "hibernate"]); break;
        case "logout": Hyprland.dispatch("hl.dsp.exit()"); break;
        case "reboot": Quickshell.execDetached(["systemctl", "reboot"]); break;
        case "poweroff": Quickshell.execDetached(["systemctl", "poweroff"]); break;
        }
    }

    LazyLoader {
        active: root.loaded

        PanelWindow {
            id: win
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            WlrLayershell.namespace: "altair-power"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            BackgroundEffect.blurRegion: Theme.blur && root.open ? fullRegion : null
            Region { id: fullRegion; item: dim }

            // ---- Countdown ---------------------------------------------------------
            property string pending: ""          // action waiting for its countdown
            property real progress: 0            // 0 → 1
            readonly property int seconds: Config.ready ? Math.max(0, Config.lock.powerCountdown) : 5
            readonly property int left: Math.ceil(seconds * (1 - progress))
            function choose(a: var): void {
                if (!a)
                    return;
                if (!a.confirm || seconds === 0 || pending === a.id) {
                    root.run(a.id);
                    return;
                }
                pending = a.id;
                countdown.restart();
            }
            function cancel(): void {
                pending = "";
                countdown.stop();
                progress = 0;
            }
            NumberAnimation {
                id: countdown
                target: win
                property: "progress"
                from: 0; to: 1
                duration: win.seconds * 1000
                onFinished: if (win.pending !== "") root.run(win.pending)
            }

            property int current: 0
            property bool shown: false
            Component.onCompleted: shown = Qt.binding(() => root.open)

            Rectangle {
                id: dim
                anchors.fill: parent
                color: Qt.alpha("#000000", Theme.blur ? 0.48 : 0.65)
                opacity: win.shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: win.shown ? Theme.anim.normal : Theme.anim.fast } }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: win.pending !== "" ? win.cancel() : ShellState.close()
            }

            FocusScope {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    const n = root.actions.length;
                    if (event.key === Qt.Key_Escape) {
                        win.pending !== "" ? win.cancel() : ShellState.close();
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.key === Qt.Key_Down) {
                        win.current = (win.current + 1) % n;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab || event.key === Qt.Key_Up) {
                        win.current = (win.current - 1 + n) % n;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        win.choose(root.actions[win.current]);
                    } else {
                        const a = root.actions.find(x => x.key === event.key);
                        if (!a)
                            return;
                        win.current = root.actions.indexOf(a);
                        win.choose(a);
                    }
                    event.accepted = true;
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.space.xl
                    opacity: win.shown ? 1 : 0
                    scale: win.shown ? 1 : 0.94
                    Behavior on opacity { NumberAnimation { duration: win.shown ? Theme.anim.normal : Theme.anim.fast } }
                    Behavior on scale { NumberAnimation { duration: win.shown ? Theme.anim.slow : Theme.anim.fast; easing.type: win.shown ? Easing.OutQuint : Easing.InCubic } }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: (Quickshell.env("USER") ?? "") + (uptime.text ? "  ·  up " + uptime.text : "")
                        color: Qt.alpha("#ffffff", 0.75)
                        font.pixelSize: Theme.font.body
                    }

                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 22
                        Repeater {
                            model: root.actions
                            delegate: PowerButton {
                                required property var modelData
                                required property int index
                                action: modelData
                                selected: win.current === index
                                pending: win.pending === modelData.id
                                progress: win.progress
                                secondsLeft: win.left
                                delay: Theme.animations ? 40 + index * 45 : 0   // staggered entrance
                                onHovered: win.current = index
                                onActivated: win.choose(modelData)
                            }
                        }
                    }

                    // Countdown line / hint.
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 360
                        implicitHeight: 34
                        StyledText {
                            anchors.centerIn: parent
                            visible: win.pending === ""
                            text: "Arrows and Enter, or the underlined letter · Esc to close"
                            color: Qt.alpha("#ffffff", 0.5)
                            font.pixelSize: Theme.font.small
                        }
                        PillButton {
                            anchors.centerIn: parent
                            visible: win.pending !== ""
                            text: "Cancel"
                            onClicked: win.cancel()
                        }
                    }
                }
            }

            // Uptime from /proc/uptime, read once on open.
            FileView {
                id: uptimeFile
                path: "/proc/uptime"
                blockLoading: true
            }
            QtObject {
                id: uptime
                readonly property string text: {
                    const sec = Number(uptimeFile.text().split(" ")[0]);
                    if (!(sec > 0))
                        return "";
                    const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
                    return (d ? d + " d " : "") + (d || h ? h + " h " : "") + m + " min";
                }
            }
        }
    }

    // ---- One round button -----------------------------------------------------------------
    component PowerButton: Item {
        id: btn
        property var action
        property bool selected
        property bool pending
        property real progress
        property int secondsLeft
        property int delay: 0
        property bool entered: false
        Timer {
            running: true
            interval: Math.max(1, btn.delay)
            onTriggered: btn.entered = true
        }
        signal hovered()
        signal activated()

        width: 112
        height: 140
        opacity: entered ? 1 : 0
        transform: Translate {
            y: btn.entered ? 0 : 18
            Behavior on y { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint } }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.anim.normal } }

        Rectangle {
            id: circle
            width: 96
            height: 96
            radius: 48
            anchors.horizontalCenter: parent.horizontalCenter
            color: btn.pending ? Qt.alpha(Theme.critical, 0.30)
                : btn.selected ? Qt.alpha("#ffffff", 0.20) : Qt.alpha("#ffffff", 0.09)
            border.width: 1
            border.color: btn.selected ? Qt.alpha("#ffffff", 0.45) : Qt.alpha("#ffffff", 0.14)
            scale: mouse.pressed ? Theme.anim.pressScale : btn.selected ? 1.06 : 1
            Behavior on scale { NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: Theme.anim.fast } }

            Icon {
                anchors.centerIn: parent
                name: btn.action.icon
                size: 36
                color: "#ffffff"
                opacity: btn.pending ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.anim.fast } }
            }
            StyledText {
                anchors.centerIn: parent
                visible: btn.pending
                text: btn.secondsLeft
                tabular: true
                color: "#ffffff"
                font.pixelSize: 34
                font.weight: Font.Light
            }
            // Countdown ring.
            Shape {
                anchors.fill: parent
                visible: btn.pending
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "#ffffff"
                    strokeWidth: 3
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 48; centerY: 48
                        radiusX: 46.5; radiusY: 46.5
                        startAngle: -90
                        sweepAngle: 360 * btn.progress
                    }
                }
            }
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: circle.bottom
            anchors.topMargin: 12
            textFormat: Text.StyledText
            // The keyboard letter underlined.
            text: {
                const l = btn.action.label;
                const k = String.fromCharCode(btn.action.key).toLowerCase();
                const i = l.toLowerCase().indexOf(k);
                return i < 0 ? l : l.slice(0, i) + "<u>" + l[i] + "</u>" + l.slice(i + 1);
            }
            color: "#ffffff"
            font.pixelSize: Theme.font.body
            font.weight: btn.selected ? Font.Medium : Font.Normal
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: btn.hovered()
            onClicked: btn.activated()
        }
    }
}
