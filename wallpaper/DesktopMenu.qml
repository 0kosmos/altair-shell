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

// Right-click menu on the empty desktop (Settings > Widgets > Desktop menu).
// Opens at the pointer; clicking outside closes it.
//
// Log out / Restart / Shut down need a second click on the same row within
// 4 s ("Click again to …"), so a stray click never turns the PC off.
PanelWindow {
    id: root

    // Its own window on the overlay layer: as a popup of the wallpaper it
    // would be drawn on the background layer, under every window.
    required property var anchorWindow
    required property point at
    signal dismissed()

    screen: anchorWindow.screen
    WlrLayershell.namespace: "altair-desktop-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true
    anchors.left: true
    // At the pointer, kept on screen (opens up/left near the edges).
    readonly property int menuWidth: 264
    readonly property int menuHeight: list.implicitHeight + Theme.space.xs * 2
    readonly property int screenW: anchorWindow.width
    readonly property int screenH: anchorWindow.height
    margins.left: at.x + menuWidth > screenW - 8 ? Math.max(8, at.x - menuWidth) : at.x
    margins.top: at.y + menuHeight > screenH - 8 ? Math.max(8, at.y - menuHeight) : at.y
    implicitWidth: menuWidth
    implicitHeight: menuHeight
    color: "transparent"

    property bool closing: false
    function close(): void {
        if (closing)
            return;
        closing = true;
        background.opacity = 0;
        background.scale = 0.97;
        closeTimer.start();
    }
    Timer {
        id: closeTimer
        interval: Theme.anim.fast + 20
        onTriggered: root.dismissed()
    }
    // Run after the menu is gone (panels opened from here must not race
    // its focus grab).
    function then(f): void {
        close();
        Qt.callLater(f);
    }

    // Click anywhere else: close.
    HyprlandFocusGrab {
        active: !root.closing
        windows: [root]
        onCleared: root.close()
    }

    BackgroundEffect.blurRegion: Theme.blur ? blurShape : null
    Region {
        id: blurShape
        item: background
        radius: Theme.radius.m
    }

    GlassBackground {
        id: background
        anchors.fill: parent
        radius: Theme.radius.m
        // Over busy wallpapers (and without blur) text must stay readable.
        solidity: Theme.blur ? 0.3 : 0.6
        opacity: 0
        scale: 0.96
        transformOrigin: Item.TopLeft
        Component.onCompleted: {
            opacity = 1;
            scale = 1;
        }
        Behavior on opacity { NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.anim.normal; easing.type: Easing.OutQuint } }
    }

    ColumnLayout {
        id: list
        focus: true
        Keys.onEscapePressed: root.close()
        anchors.fill: parent
        anchors.margins: Theme.space.xs
        spacing: 0
        opacity: background.opacity
        scale: background.scale
        transformOrigin: Item.TopLeft

        MenuRow {
            iconName: "apps"
            label: "Open an app"
            onClicked: root.then(() => ShellState.open("launcher"))
        }
        MenuRow {
            iconName: "terminal"
            label: "Terminal"
            onClicked: root.then(() => Hypr.exec([Apps.terminal], Quickshell.env("HOME")))
        }
        Sep {}
        MenuRow {
            iconName: "wallpaper"
            label: "Change wallpaper"
            onClicked: root.then(() => ShellState.open("wallpaper"))
        }
        MenuRow {
            iconName: "widgets"
            label: "Edit widgets"
            onClicked: root.then(() => Widgets.editing = true)
        }
        MenuRow {
            visible: Recorder.available
            iconName: Recorder.recording ? "stop_circle" : "radio_button_checked"
            label: Recorder.recording ? "Stop recording" : "Record the screen"
            onClicked: root.then(() => Recorder.toggle())
        }
        MenuRow {
            label: "Do not disturb"
            checkable: true
            checked: Config.notifications.doNotDisturb
            onClicked: Config.notifications.doNotDisturb = !Config.notifications.doNotDisturb
        }
        MenuRow {
            label: "Low-power mode"
            checkable: true
            checked: Config.performance.lowPower
            onClicked: Config.performance.lowPower = !Config.performance.lowPower
        }
        Sep {}
        MenuRow {
            iconName: "settings"
            label: "Altair settings"
            onClicked: root.then(() => ShellState.open("settings"))
        }
        MenuRow {
            iconName: "refresh"
            label: "Refresh desktop (restart Altair)"
            onClicked: root.then(() => Hyprland.dispatch('hl.dsp.exec_cmd(require("altair").restart_cmd)'))
        }
        Sep {}
        MenuRow {
            iconName: "lock"
            label: "Lock"
            onClicked: root.then(() => Locker.lock())
        }
        MenuRow {
            iconName: "power_settings_new"
            label: "Power…"
            onClicked: root.then(() => ShellState.open("power"))
        }
    }

    component Sep: Item {
        Layout.fillWidth: true
        implicitHeight: 1 + Theme.space.xs * 2
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - Theme.space.s * 2
            height: 1
            color: Theme.border
        }
    }
}
