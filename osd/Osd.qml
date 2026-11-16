// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.core
import qs.services
import qs.theme

// A small pill that shows volume, mute, microphone mute and brightness
// changes for a moment. It reacts to the values themselves (PipeWire,
// Display), not to keys, so it also shows for changes made by the stock
// `wpctl` keybinds, other apps or the bar. The window only exists while
// shown; nothing runs while hidden.
Scope {
    id: root

    readonly property bool enabled: Config.ready && Config.osd.enabled
    readonly property bool atTop: Config.osd.position === "top"

    // What to show: "volume" | "mic" | "brightness".
    property string kind: "volume"
    property bool loaded: false
    property bool shown: false

    // Values at start-up (and devices appearing) are not changes.
    property bool armed: false
    Timer {
        running: true
        interval: 2500
        onTriggered: root.armed = true
    }

    function show(what: string): void {
        if (!enabled || !armed || Locker.locked)
            return;
        // The brightness menu already shows its slider.
        if (what === "brightness" && ShellState.openPanel === "brightness")
            return;
        kind = what;
        loaded = true;
        shown = true;
        hide.restart();
    }
    Timer {
        id: hide
        interval: 1500
        onTriggered: root.shown = false
    }
    // Unload once faded out.
    Timer {
        running: root.loaded && !root.shown
        interval: Theme.anim.normal + 100
        onTriggered: root.loaded = false
    }

    Connections {
        target: Audio
        function onVolumeChanged() { root.show("volume"); }
        function onMutedChanged() { root.show("volume"); }
        function onMicMutedChanged() { root.show("mic"); }
        // A new default device: its values are not a change by the user.
        function onSinkChanged() { root.rearm(); }
        function onSourceChanged() { root.rearm(); }
    }
    Connections {
        target: Display
        function onBrightnessChanged() { root.show("brightness"); }
        function onNudged() { root.show("brightness"); }
    }
    function rearm(): void {
        armed = false;
        rearmTimer.restart();
    }
    Timer {
        id: rearmTimer
        interval: 800
        onTriggered: root.armed = true
    }

    // ---- What it shows ----------------------------------------------------------------------
    readonly property real value: kind === "volume" ? Audio.volume
        : kind === "brightness" ? Display.brightness / 100 : 0
    readonly property bool off: kind === "volume" ? Audio.muted || Audio.volume === 0
        : kind === "mic" ? Audio.micMuted : false
    readonly property string icon: kind === "mic" ? (Audio.micMuted ? "mic_off" : "mic")
        : kind === "brightness" ? Display.icon
        : off ? "volume_off" : Audio.volume < 0.34 ? "volume_mute" : Audio.volume < 0.67 ? "volume_down" : "volume_up"
    readonly property string label: kind === "mic" ? (Audio.micMuted ? "Microphone off" : "Microphone on")
        : kind === "volume" && Audio.muted ? "Muted"
        : Math.round(value * 100) + "%"

    LazyLoader {
        active: root.loaded

        PanelWindow {
            id: win
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

            WlrLayershell.namespace: "altair-osd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // Keeps clear of the bar and a dock that reserves space.
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0
            anchors.bottom: !root.atTop
            anchors.top: root.atTop
            // Clear of a dock on the same edge that doesn't reserve space.
            readonly property bool dockHere: Config.dock.enabled && Config.dock.position === "bottom" && !root.atTop
                && (!Config.dock.reserveSpace || Config.dock.autoHide)
            margins.bottom: Theme.barGap * 6 + (dockHere ? Config.dock.iconSize + 24 : 0)
            margins.top: Theme.barGap * 6
            implicitWidth: 300
            implicitHeight: 56
            color: "transparent"
            // Clicks pass through.
            mask: Region {}

            BackgroundEffect.blurRegion: Theme.blur && root.shown ? blurShape : null
            Region {
                id: blurShape
                item: pill
                radius: pill.radius
            }

            GlassBackground {
                id: pill
                animate: root.shown
                anchors.fill: parent
                radius: height / 2

                property bool visibleNow: false
                Component.onCompleted: visibleNow = Qt.binding(() => root.shown)
                opacity: visibleNow ? 1 : 0
                scale: visibleNow ? 1 : 0.92
                transform: Translate {
                    y: pill.visibleNow ? 0 : root.atTop ? -14 : 14
                    Behavior on y { NumberAnimation { duration: pill.visibleNow ? Theme.anim.normal : Theme.anim.fast; easing.type: pill.visibleNow ? Easing.OutQuint : Easing.InCubic } }
                }
                Behavior on opacity { NumberAnimation { duration: pill.visibleNow ? Theme.anim.fast : Theme.anim.normal } }
                Behavior on scale { NumberAnimation { duration: pill.visibleNow ? Theme.anim.normal : Theme.anim.fast; easing.type: pill.visibleNow ? Easing.OutBack : Easing.InCubic } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 20
                    spacing: 14

                    Icon {
                        name: root.icon
                        size: 22
                        color: root.off ? Theme.fgMuted : Theme.fg
                    }
                    // Bar (not for the microphone: on/off only).
                    Rectangle {
                        visible: root.kind !== "mic"
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Qt.alpha(Theme.fg, 0.14)
                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: parent.width * Math.max(0, Math.min(1, root.value))
                            color: root.off ? Theme.fgDisabled : Theme.accent
                            Behavior on width { NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
                        }
                    }
                    StyledText {
                        Layout.fillWidth: root.kind === "mic"
                        Layout.preferredWidth: root.kind === "mic" ? -1 : 52
                        horizontalAlignment: root.kind === "mic" ? Text.AlignLeft : Text.AlignRight
                        text: root.label
                        tabular: true
                        color: root.off ? Theme.fgMuted : Theme.fg
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }
}
