// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// A small window of its own, exactly over a widget (Bottom layer, above the
// widget layer, no input). For things that move continuously (rain, the
// karaoke fill): animating inside the widget layer would redraw every widget
// on it and make Hyprland re-blur it each frame (~6–7 % of a core here at
// 24–30 fps); this small surface costs about half that.
//
// Shown only while `wanted`, outside edit mode and not while the widget is
// dragged (`showing` tells the widget to draw a still copy itself then).
Scope {
    id: root

    property bool wanted: true
    // From WidgetFrame (see WidgetFrame.onLoaded): the widget's rect on its
    // monitor, the monitor, whether it is being dragged.
    property rect frameRect
    property string screenName: ""
    property bool moving: false
    // What to draw; it fills the window.
    property Component content

    readonly property bool showing: wanted && !moving && !Widgets.editing
        && frameRect.width > 0 && screenName !== ""

    LazyLoader {
        active: root.showing

        PanelWindow {
            screen: Quickshell.screens.find(s => s.name === root.screenName) ?? null
            WlrLayershell.namespace: "altair-widget-fx"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.left: true
            margins.left: Math.round(root.frameRect.x)
            margins.top: Math.round(root.frameRect.y)
            implicitWidth: Math.round(root.frameRect.width)
            implicitHeight: Math.round(root.frameRect.height)
            color: "transparent"
            mask: Region {}

            Loader {
                anchors.fill: parent
                sourceComponent: root.content
            }
        }
    }
}
