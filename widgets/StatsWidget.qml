// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.services
import qs.theme

// CPU and memory use, optional GPU temperature (Settings > Widgets). Base
// size 300 x 132. Readings come from services/SysStats.qml, which only reads
// while at least one of these widgets exists (every 2 s; GPU every 5 s).
Item {
    id: root
    property string style: ""

    Component.onCompleted: SysStats.users++
    Component.onDestruction: SysStats.users--

    function gb(bytes: real): string {
        return (bytes / 1073741824).toFixed(1);
    }

    component Meter: ColumnLayout {
        property string label
        property string value
        property real ratio: 0
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: parent.parent.label
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
                font.weight: Font.DemiBold
                font.letterSpacing: 0.5
            }
            StyledText {
                text: parent.parent.value
                font.pixelSize: Theme.font.small
                tabular: true
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Theme.pressed
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, parent.parent.ratio))
                height: parent.height
                radius: 3
                // Turns to the warning colour when nearly full.
                color: parent.parent.ratio > 0.9 ? Theme.critical : Theme.accent
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        Meter {
            label: "CPU"
            value: Math.round(SysStats.cpu * 100) + " %"
            ratio: SysStats.cpu
        }
        Meter {
            label: "MEMORY"
            value: root.gb(SysStats.memUsed) + " / " + root.gb(SysStats.memTotal) + " GB"
            ratio: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
        }
        RowLayout {
            Layout.fillWidth: true
            visible: Config.widgets.gpuTemp
            StyledText {
                Layout.fillWidth: true
                text: "GPU"
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
                font.weight: Font.DemiBold
                font.letterSpacing: 0.5
            }
            StyledText {
                text: SysStats.gpuTemp >= 0 ? SysStats.gpuTemp + " °C" : "—"
                font.pixelSize: Theme.font.small
                tabular: true
            }
        }
        Item { Layout.fillHeight: true }
    }
}
