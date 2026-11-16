// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.components
import qs.core
import qs.services
import qs.theme

// Recorder menu: right-click the bar's record button (left click still just
// starts/stops). What to record, sound, frame rate, quality, codec, cursor,
// and the latest clips.
AltairPanel {
    id: root

    name: "recorder"
    dock: Theme.barVertical ? Theme.barPosition : Theme.barAtTop ? "top" : "bottom"
    centerVertically: Theme.barVertical
    fullWidth: false
    along: "end"
    slideDistance: 12
    panelWidth: 380
    property real contentHeight: 420
    panelHeight: contentHeight

    onOpenChanged: if (open) Recorder.loadRecent()

    // Refresh rate of the focused monitor caps the frame-rate choices.
    readonly property int maxFps: Math.round(Hyprland.focusedMonitor?.lastIpcObject?.refreshRate ?? 240)

    content: Component {
        FocusScope {
            focus: true
            Binding {
                target: root
                property: "contentHeight"
                value: col.implicitHeight + Theme.space.l * 2
            }

            ColumnLayout {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.space.l
                spacing: Theme.space.m

                // ---- Header: title + start/stop ------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space.s
                    StyledText {
                        Layout.fillWidth: true
                        text: Recorder.recording ? "Recording…" : "Screen recording"
                        font.pixelSize: Theme.font.title
                        font.weight: Font.DemiBold
                    }
                    IconButton {
                        icon: "folder_open"
                        onClicked: {
                            ShellState.close();
                            Recorder.openPath(Recorder.folder);
                        }
                    }
                }

                // Big start / stop button.
                MouseArea {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    cursorShape: Qt.PointingHandCursor
                    enabled: Recorder.available
                    onClicked: {
                        ShellState.close();
                        Recorder.toggle();
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius.m
                        color: Recorder.recording ? Qt.alpha(Theme.critical, parent.containsPress ? 0.32 : 0.22)
                            : parent.containsPress ? Qt.darker(Theme.accent, 1.15) : Theme.accent
                        opacity: Recorder.available ? 1 : 0.4
                        Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
                    }
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Theme.space.s
                        Rectangle {
                            implicitWidth: 12
                            implicitHeight: 12
                            radius: Recorder.recording ? 2 : 6
                            color: Recorder.recording ? Theme.critical : Theme.onAccent
                            Behavior on radius { NumberAnimation { duration: Theme.anim.fast } }
                        }
                        StyledText {
                            text: !Recorder.available ? "gpu-screen-recorder is not installed"
                                : Recorder.recording ? "Stop and save"
                                : Recorder.target === "region" && Recorder.hasSlurp ? "Select a region and record"
                                : "Record the screen"
                            color: Recorder.recording ? Theme.fg : Theme.onAccent
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // ---- Options ---------------------------------------------------------
                Row_ {
                    label: "Record"
                    Segmented {
                        stretch: true
                        width: parent.width
                        options: Recorder.hasSlurp
                            ? [{ label: "Screen", value: "screen" }, { label: "Region", value: "region" }]
                            : [{ label: "Screen", value: "screen" }]
                        current: Recorder.target
                        onSelected: value => Config.recorder.target = value
                    }
                }
                Row_ {
                    label: "Sound"
                    Segmented {
                        stretch: true
                        width: parent.width
                        options: [{ label: "None", value: "none" }, { label: "System", value: "system" }, { label: "+ Mic", value: "both" }]
                        current: Config.recorder.audio
                        onSelected: value => Config.recorder.audio = value
                    }
                }
                Row_ {
                    label: "Frame rate"
                    Segmented {
                        stretch: true
                        width: parent.width
                        options: [30, 60, 120, 144, 165].filter(f => f <= Math.max(60, root.maxFps)).map(f => ({ label: String(f), value: f }))
                        current: Recorder.fps
                        onSelected: value => Config.recorder.fps = value
                    }
                }
                Row_ {
                    label: "Quality"
                    Segmented {
                        stretch: true
                        width: parent.width
                        options: [{ label: "Medium", value: "medium" }, { label: "High", value: "high" },
                                  { label: "Very high", value: "very_high" }, { label: "Ultra", value: "ultra" }]
                        current: Recorder.quality
                        onSelected: value => Config.recorder.quality = value
                    }
                }
                Row_ {
                    label: "Codec"
                    Segmented {
                        stretch: true
                        width: parent.width
                        options: [{ label: "H.264", value: "h264", hint: "plays everywhere" }, { label: "HEVC", value: "hevc" }, { label: "AV1", value: "av1" }]
                            .filter(o => Recorder.codecs.indexOf(o.value) !== -1)
                        current: Recorder.codec
                        onSelected: value => Config.recorder.codec = value
                    }
                }
                Row_ {
                    label: "Mouse pointer"
                    inline: true
                    Toggle {
                        checked: Recorder.cursor
                        onToggled: value => Config.recorder.cursor = value
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: Recorder.recording
                    text: "Changes apply to the next recording."
                    color: Theme.fgMuted
                    font.pixelSize: Theme.font.small
                }

                // ---- Latest clips --------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.border
                    visible: Recorder.recent.length > 0
                }
                StyledText {
                    visible: Recorder.recent.length > 0
                    text: "Latest clips"
                    color: Theme.fgMuted
                    font.pixelSize: Theme.font.small
                }
                Repeater {
                    model: Recorder.recent
                    delegate: MouseArea {
                        id: clip
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 40
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ShellState.close();
                            Recorder.openPath(modelData.path);
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius.s
                            color: clip.containsMouse ? Theme.hover : "transparent"
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.space.s
                            anchors.rightMargin: Theme.space.s
                            spacing: Theme.space.s
                            Icon {
                                name: "movie"
                                color: Theme.fgMuted
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: clip.modelData.name.replace(/^Recording_/, "").replace(/\.(mp4|mkv|webm)$/, "").replace("_", "  ").replace(/-(\d\d)-(\d\d)$/, ":$1:$2")
                                elide: Text.ElideRight
                            }
                            StyledText {
                                text: clip.modelData.size >= 1073741824 ? (clip.modelData.size / 1073741824).toFixed(1) + " GB"
                                    : Math.max(1, Math.round(clip.modelData.size / 1048576)) + " MB"
                                color: Theme.fgMuted
                                font.pixelSize: Theme.font.small
                                tabular: true
                            }
                        }
                    }
                }
            }
        }
    }

    // A small label above a control that spans the menu (or, with `inline`,
    // label left and control right, e.g. a toggle).
    component Row_: GridLayout {
        id: r
        property string label
        property bool inline: false
        default property alias control: holder.data
        Layout.fillWidth: true
        columns: inline ? 2 : 1
        rowSpacing: 4
        columnSpacing: Theme.space.m
        StyledText {
            Layout.fillWidth: true
            text: r.label
            color: Theme.fgMuted
            font.pixelSize: Theme.font.small
        }
        Item {
            id: holder
            Layout.fillWidth: !r.inline
            implicitWidth: children[0]?.implicitWidth ?? 0
            implicitHeight: children[0]?.implicitHeight ?? 0
        }
    }
}
