// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.components
import qs.core
import qs.services
import qs.theme

// CPU and memory use, optional GPU temperature (Settings > Widgets). Styles
// (sizes in services/Widgets.qml):
//   bars     a labelled bar per value
//   rings    round gauges
//   compact  one line of text
// Readings come from services/SysStats.qml, which only reads while at least
// one of these widgets exists (every 2 s; GPU every 5 s). Nothing here
// animates between readings, so the widget redraws once per reading.
Item {
    id: root
    property string style: "bars"
    // Counts as a reader only while not covered by windows (WidgetFrame).
    property bool live: true
    property bool counted: false
    onLiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (counted) SysStats.users--
    function sync(): void {
        if (live && !counted) { SysStats.users++; counted = true; }
        else if (!live && counted) { SysStats.users--; counted = false; }
    }

    readonly property real memRatio: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
    readonly property bool gpu: Config.widgets.gpuTemp
    readonly property string cpuText: Math.round(SysStats.cpu * 100) + " %"
    readonly property string memText: gb(SysStats.memUsed) + " / " + gb(SysStats.memTotal) + " GB"
    readonly property string gpuText: SysStats.gpuTemp >= 0 ? SysStats.gpuTemp + " °C" : "—"

    // Size the frame should have (WidgetFrame glides to it): fits what is
    // shown, so turning the GPU reading off leaves no gap.
    readonly property real fitW: style === "rings" ? rings.implicitWidth + 40
        : style === "compact" ? compact.implicitWidth + 40 : -1
    readonly property real fitH: style === "bars" ? bars.implicitHeight + 36 : -1

    function gb(bytes: real): string {
        return (bytes / 1073741824).toFixed(1);
    }
    // Warning colour when nearly full.
    function tone(r: real): color {
        return r > 0.9 ? Theme.critical : Theme.accent;
    }

    component Label: StyledText {
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
        font.weight: Font.DemiBold
        font.letterSpacing: 0.5
    }

    // ---- Bars ------------------------------------------------------------------------
    component Meter: ColumnLayout {
        id: meter
        property string label
        property string value
        property real ratio: 0
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                text: meter.label
            }
            StyledText {
                text: meter.value
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
                width: parent.width * Math.max(0, Math.min(1, meter.ratio))
                height: parent.height
                radius: 3
                color: root.tone(meter.ratio)
            }
        }
    }

    ColumnLayout {
        id: bars
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 18
        visible: root.style === "bars"
        spacing: 12

        Meter {
            label: "CPU"
            value: root.cpuText
            ratio: SysStats.cpu
        }
        Meter {
            label: "MEMORY"
            value: root.memText
            ratio: root.memRatio
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.gpu
            Label {
                Layout.fillWidth: true
                text: "GPU"
            }
            StyledText {
                text: root.gpuText
                font.pixelSize: Theme.font.small
                tabular: true
            }
        }
    }

    // ---- Rings -----------------------------------------------------------------------
    component Ring: Item {
        id: ring
        property string label
        property string value
        property real ratio: 0
        implicitWidth: 84
        implicitHeight: 104

        Shape {
            id: gauge
            width: 76
            height: 76
            anchors.horizontalCenter: parent.horizontalCenter
            preferredRendererType: Shape.CurveRenderer
            // Track, then the value, from 12 o'clock clockwise.
            ShapePath {
                strokeWidth: 7
                strokeColor: Theme.pressed
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 38; centerY: 38; radiusX: 33; radiusY: 33; startAngle: -90; sweepAngle: 360 }
            }
            ShapePath {
                strokeWidth: 7
                strokeColor: root.tone(ring.ratio)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 38; centerY: 38; radiusX: 33; radiusY: 33; startAngle: -90; sweepAngle: 360 * Math.max(0.005, Math.min(1, ring.ratio)) }
            }
        }
        StyledText {
            anchors.centerIn: gauge
            text: ring.value
            font.pixelSize: 15
            font.weight: Font.DemiBold
            tabular: true
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: ring.label
        }
    }

    RowLayout {
        id: rings
        anchors.centerIn: parent
        visible: root.style === "rings"
        spacing: 10
        Ring {
            label: "CPU"
            value: Math.round(SysStats.cpu * 100) + "%"
            ratio: SysStats.cpu
        }
        Ring {
            label: "MEMORY"
            value: Math.round(root.memRatio * 100) + "%"
            ratio: root.memRatio
        }
        // GPU temperature as a gauge from 30 to 95 °C.
        Ring {
            visible: root.gpu
            label: "GPU"
            value: SysStats.gpuTemp >= 0 ? SysStats.gpuTemp + "°" : "—"
            ratio: SysStats.gpuTemp >= 0 ? (SysStats.gpuTemp - 30) / 65 : 0
        }
    }

    // ---- Compact ---------------------------------------------------------------------
    RowLayout {
        id: compact
        anchors.centerIn: parent
        visible: root.style === "compact"
        spacing: Theme.space.m

        Repeater {
            model: [
                { label: "CPU", value: root.cpuText, show: true },
                { label: "RAM", value: root.gb(SysStats.memUsed) + " GB", show: true },
                { label: "GPU", value: root.gpuText, show: root.gpu },
            ]
            RowLayout {
                required property var modelData
                required property int index
                visible: modelData.show
                spacing: 6
                // A dot between items.
                Rectangle {
                    visible: index > 0
                    width: 4
                    height: 4
                    radius: 2
                    color: Theme.fgDisabled
                    Layout.rightMargin: 6
                }
                Label { text: modelData.label }
                StyledText {
                    text: modelData.value
                    font.weight: Font.DemiBold
                    tabular: true
                }
            }
        }
    }
}
