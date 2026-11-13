// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.core
import qs.theme

// Base for every popup panel (launcher, settings, dashboard, ...).
//
// - Opens when ShellState.openPanel === name (toggle with
//   `qs -c altair ipc call panels toggle <name>`).
// - The window is created on open and destroyed after the close animation,
//   so a closed panel costs nothing.
// - Appears on the focused monitor, horizontally centred, `topOffset` of the
//   screen height from the top.
// - Closes on Esc, on a click outside it, or via ShellState.close().
//
// Put the panel's UI in `content` (a Component). It is sized to
// panelWidth x panelHeight and should take keyboard focus where it wants it.
Scope {
    id: root

    required property string name
    property int panelWidth: 560
    property int panelHeight: 420
    property real topOffset: 0.2
    // false: centred, topOffset from the top (launcher).
    // true: docked to the right edge next to the bar (notification centre).
    property bool alignRight: false
    property Component content

    readonly property bool open: ShellState.openPanel === name
    // True while the close animation plays; keeps the window alive until done.
    property bool closing: false

    onOpenChanged: if (!open) closing = true

    // Safety net: if the panel is closed before its fade-in started, opacity
    // never changes and the "faded out" check below would never fire.
    Timer {
        running: root.closing
        interval: Theme.anim.slow + 200
        onTriggered: root.closing = false
    }

    LazyLoader {
        active: root.open || root.closing

        PanelWindow {
            id: win

            // Where the user is working right now.
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

            WlrLayershell.namespace: "altair-" + root.name
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            // Docked panels respect the bar's exclusive zone (sit next to it);
            // centred ones float over everything.
            exclusionMode: root.alignRight ? ExclusionMode.Normal : ExclusionMode.Ignore
            exclusiveZone: 0

            anchors.top: !root.alignRight || Theme.barAtTop
            anchors.bottom: root.alignRight && !Theme.barAtTop
            anchors.right: root.alignRight
            margins.top: root.alignRight ? Theme.barGap : Math.round((screen?.height ?? 1080) * root.topOffset)
            margins.bottom: root.alignRight ? Theme.barGap : 0
            margins.right: root.alignRight ? Theme.barGap : 0
            implicitWidth: root.panelWidth
            implicitHeight: root.panelHeight
            color: "transparent"

            // No blur while fading out: the compositor would keep blurring the
            // full rectangle behind a panel that is already half transparent.
            BackgroundEffect.blurRegion: Theme.blur && root.open ? blurShape : null
            Region {
                id: blurShape
                item: background
                radius: Theme.radius.l
            }

            // Click outside any of our windows -> close.
            HyprlandFocusGrab {
                active: root.open
                windows: [win]
                onCleared: if (root.open) ShellState.close()
            }

            Item {
                id: body
                anchors.fill: parent

                // Starts hidden and animates in (see Component.onCompleted).
                property bool shown: false
                opacity: shown ? 1 : 0
                scale: shown ? 1 : 0.97
                Component.onCompleted: shown = Qt.binding(() => root.open)

                Behavior on opacity {
                    NumberAnimation {
                        duration: body.shown ? Theme.anim.normal : Theme.anim.fast
                        easing.type: body.shown ? Theme.anim.easing : Theme.anim.easingIn
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: body.shown ? Theme.anim.normal : Theme.anim.fast
                        easing.type: body.shown ? Theme.anim.easing : Theme.anim.easingIn
                    }
                }
                // Unload once fully faded out.
                onOpacityChanged: if (opacity === 0 && !shown) root.closing = false

                GlassBackground {
                    id: background
                    anchors.fill: parent
                    radius: Theme.radius.l
                }

                FocusScope {
                    anchors.fill: parent
                    focus: true
                    Keys.onEscapePressed: ShellState.close()

                    Loader {
                        anchors.fill: parent
                        focus: true
                        sourceComponent: root.content
                        // Give the panel keyboard focus right away, so it can be
                        // typed into without clicking it first. (The content's
                        // root must also have `focus: true`.)
                        onLoaded: item.forceActiveFocus()
                    }
                }
            }
        }
    }
}
