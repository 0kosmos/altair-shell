// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.services
import qs.theme

// The wallpaper picker's theme row: pick a palette for the current wallpaper
// (or "Auto": generated from it), save it for this wallpaper or for all, and
// choose what happens when the wallpaper changes (services/WallpaperTheme).
Flow {
    id: root

    // The wallpaper the row is about (the current one).
    property string path: Wallpapers.current
    readonly property string palette: Config.appearance.palette

    spacing: 6

    // ---- Palettes ---------------------------------------------------------------
    // "Auto" first, then every built-in palette as three colour dots.
    Repeater {
        model: [{ id: "auto", name: "Auto" }].concat(Theme.palettes)

        MouseArea {
            id: chip
            required property var modelData
            readonly property bool isAuto: modelData.id === "auto"
            readonly property bool on: root.palette === modelData.id
            readonly property var cols: isAuto ? Array.from(Config.appearance.autoColors) : modelData.colors
            implicitWidth: isAuto ? autoRow.implicitWidth + 18 : 40
            implicitHeight: 30
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: WallpaperTheme.choose(modelData.id, root.path)
            scale: pressed ? Theme.anim.pressScale : containsMouse ? 1.06 : 1
            Behavior on scale { NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2 } }

            Rectangle {
                anchors.fill: parent
                radius: Theme.pill(height)
                color: chip.isAuto ? (chip.on ? Theme.accent : Theme.surfaceRaised) : chip.cols[0]
                border.width: chip.on ? 2 : 1
                border.color: chip.on ? Theme.accent : Theme.border
                Behavior on border.color { ColorAnimation { duration: Theme.anim.fast } }
            }
            // Palette: surface and accent dots on its background.
            Row {
                visible: !chip.isAuto
                anchors.centerIn: parent
                spacing: -4
                Repeater {
                    model: chip.isAuto ? [] : [chip.cols[2], chip.cols[3], chip.cols[4]]
                    Rectangle {
                        required property var modelData
                        width: 12
                        height: 12
                        radius: 6
                        color: modelData
                        border.width: 1
                        border.color: Qt.alpha("#000000", 0.25)
                    }
                }
            }
            RowLayout {
                id: autoRow
                visible: chip.isAuto
                anchors.centerIn: parent
                spacing: 5
                Icon {
                    name: "auto_awesome"
                    size: 15
                    color: chip.on ? Theme.onAccent : Theme.accent
                    // Spins while the colours are being read.
                    RotationAnimation on rotation {
                        running: WallpaperTheme.generating
                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        onRunningChanged: if (!running) parent.rotation = 0
                    }
                }
                StyledText {
                    text: "Auto"
                    color: chip.on ? Theme.onAccent : Theme.fg
                    font.pixelSize: Theme.font.small
                    font.weight: Font.DemiBold
                }
            }
            // Name on hover.
            ToolTipText {
                visible: chip.containsMouse && !chip.isAuto
                text: chip.modelData.name
            }
        }
    }

    // ---- Divider ----------------------------------------------------------------
    Rectangle {
        width: 1
        height: 30
        color: Theme.border
    }

    // ---- When the wallpaper changes -------------------------------------------------
    StyledText {
        height: 30
        text: "On change:"
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
    }
    Repeater {
        model: [{ v: "keep", l: "Keep theme" }, { v: "saved", l: "Saved" }, { v: "auto", l: "Auto" }]
        Pill {
            required property var modelData
            label: modelData.l
            on: WallpaperTheme.mode === modelData.v
            onClicked: Config.wallpaper.themeMode = modelData.v
        }
    }

    Rectangle {
        width: 1
        height: 30
        color: Theme.border
    }

    // ---- Save -----------------------------------------------------------------------
    // Saved and unchanged: click to forget. Saved but changed since: update.
    Pill {
        readonly property bool saved: WallpaperTheme.hasSaved(root.path)
        readonly property bool same: saved && JSON.stringify(WallpaperTheme.saved[root.path]) === JSON.stringify(WallpaperTheme.currentTheme())
        icon: same ? "bookmark_added" : "bookmark_add"
        label: same ? "Saved for this wallpaper" : saved ? "Update for this wallpaper" : "Save for this wallpaper"
        on: same
        enabled: root.path !== ""
        onClicked: same ? WallpaperTheme.forget(root.path) : WallpaperTheme.saveFor(root.path)
    }
    Pill {
        icon: "select_all"
        label: "Use for all"
        onClicked: {
            WallpaperTheme.saveForAll();
            flash.restart();
        }
        on: flash.running
        Timer { id: flash; interval: 1200 }
    }

    component Pill: MouseArea {
        id: pill
        property string icon: ""
        property string label
        property bool on: false
        implicitWidth: pillRow.implicitWidth + 20
        implicitHeight: 30
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        opacity: enabled ? 1 : 0.4
        scale: pressed ? Theme.anim.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
        Rectangle {
            anchors.fill: parent
            radius: Theme.pill(height)
            color: pill.on ? Theme.accent : pill.containsMouse ? Theme.hover : Theme.surfaceRaised
            Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
        }
        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 5
            Icon {
                visible: pill.icon !== ""
                name: pill.icon
                size: 15
                color: pill.on ? Theme.onAccent : Theme.fg
            }
            StyledText {
                text: pill.label
                color: pill.on ? Theme.onAccent : Theme.fg
                font.pixelSize: Theme.font.small
            }
        }
    }

    component ToolTipText: Rectangle {
        property alias text: tipLabel.text
        y: -height - 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: tipLabel.implicitWidth + 14
        height: 22
        radius: 6
        color: Theme.base
        border.width: 1
        border.color: Theme.border
        z: 10
        StyledText {
            id: tipLabel
            anchors.centerIn: parent
            font.pixelSize: Theme.font.small
        }
    }
}
