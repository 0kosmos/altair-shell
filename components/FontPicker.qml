// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.theme

// Choice of a font family: common families that are installed, each shown in
// its own font. `current` "" = the "default" choice (labelled by `defaultLabel`).
Flow {
    id: root

    property string current: ""
    property string defaultLabel: "Default"
    signal picked(string family)

    // Well-known families; only the installed ones are offered.
    readonly property var candidates: ["Inter", "Inter Display", "Adwaita Sans", "Cantarell", "Noto Sans",
        "Roboto", "Open Sans", "Lato", "Montserrat", "Poppins", "Nunito", "Raleway", "Ubuntu",
        "Fira Sans", "IBM Plex Sans", "Source Sans 3", "DejaVu Sans", "Liberation Sans",
        "Noto Serif", "DejaVu Serif", "Liberation Serif", "Playfair Display",
        "JetBrains Mono", "Fira Code", "Hack", "DejaVu Sans Mono", "Adwaita Mono"]
    readonly property var installed: {
        const all = new Set(Qt.fontFamilies());
        return candidates.filter(f => all.has(f));
    }

    Layout.fillWidth: true
    spacing: 6

    Repeater {
        model: [{ label: root.defaultLabel, family: "" }].concat(root.installed.map(f => ({ label: f, family: f })))
        MouseArea {
            id: chip
            required property var modelData
            readonly property bool on: root.current === modelData.family
            implicitWidth: label.implicitWidth + 20
            implicitHeight: 30
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.picked(modelData.family)
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: chip.on ? Theme.accent : chip.containsMouse ? Theme.hover : Theme.surfaceRaised
                border.width: chip.on ? 0 : 1
                border.color: Theme.border
                Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
            }
            Text {
                id: label
                anchors.centerIn: parent
                text: chip.modelData.label
                color: chip.on ? Theme.onAccent : Theme.fg
                font.family: chip.modelData.family || Theme.font.family
                font.pixelSize: Theme.font.small + 1
            }
        }
    }
}
