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
    // Where the panel sits:
    //   ""        centred, topOffset from the top (launcher)
    //   "right"   docked to the right edge next to the bar (notification centre)
    //   "top"/"bottom"  full width along that edge (wallpaper strip)
    // Docked panels respect the bar's exclusive zone, so they sit next to it.
    property string dock: alignRight ? "right" : ""
    property bool alignRight: false
    // "top"/"bottom": stretch along the edge, or keep panelWidth (centred).
    property bool fullWidth: true
    // How far edge panels slide in from their edge, in px.
    property int slideDistance: 24
    // dock "": centre vertically instead of using topOffset.
    property bool centerVertically: false
    // Several panels can share a name (e.g. two picker styles); only the
    // available one opens.
    property bool available: true
    property Component content

    readonly property bool docked: dock !== ""
    readonly property bool open: available && ShellState.openPanel === name
    // Whether the window exists: true on open, false only after the close
    // animation. NOTE: one flag on purpose; "open || closing" let the loader
    // see both false for a moment, destroy the window and build a new one.
    property bool loaded: false
    onOpenChanged: {
        if (!open)
            return;
        if (loaded) {
            // Reopened while still fading out: build a fresh window. Reusing
            // the old one re-arms its click-outside grab, which Hyprland then
            // reports as cleared at once, closing the panel again.
            loaded = false;
            Qt.callLater(() => root.loaded = root.open);
        } else {
            loaded = true;
        }
    }

    // Safety net: if the panel is closed before its fade-in started, opacity
    // never changes and the "faded out" check below would never fire.
    Timer {
        running: root.loaded && !root.open
        interval: Theme.anim.slow + 200
        onTriggered: root.loaded = false
    }

    LazyLoader {
        active: root.loaded

        PanelWindow {
            id: win

            // Where the user is working right now.
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

            WlrLayershell.namespace: "altair-" + root.name
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            // Docked panels respect the bar's exclusive zone (sit next to it);
            // centred ones float over everything.
            exclusionMode: root.docked ? ExclusionMode.Normal : ExclusionMode.Ignore
            exclusiveZone: 0

            anchors.top: root.dock === "" || root.dock === "top" || (root.dock === "right" && Theme.barAtTop)
            anchors.bottom: root.dock === "bottom" || (root.dock === "right" && !Theme.barAtTop)
            anchors.right: root.dock === "right" || ((root.dock === "top" || root.dock === "bottom") && root.fullWidth)
            anchors.left: (root.dock === "top" || root.dock === "bottom") && root.fullWidth
            margins.top: root.docked ? Theme.barGap
                : root.centerVertically ? Math.round(((screen?.height ?? 1080) - root.panelHeight) / 2)
                : Math.round((screen?.height ?? 1080) * root.topOffset)
            margins.bottom: root.docked ? Theme.barGap : 0
            margins.right: root.docked ? Theme.barGap : 0
            margins.left: root.docked ? Theme.barGap : 0
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
                // Edge panels slide in from their edge; others grow slightly
                // (small edge panels, e.g. the calendar, do both, growing out
                // of the bar).
                readonly property bool edge: root.dock === "top" || root.dock === "bottom"
                scale: shown || (edge && root.fullWidth) ? 1 : 0.97
                transformOrigin: root.dock === "top" ? Item.Top : root.dock === "bottom" ? Item.Bottom : Item.Center
                transform: Translate {
                    y: body.shown ? 0 : root.dock === "bottom" ? root.slideDistance : root.dock === "top" ? -root.slideDistance : 0
                    Behavior on y {
                        NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide }
                    }
                }
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
                // (Only while closing: opacity also passes 0 while the panel is
                // being built, and must not unload it then.)
                onOpacityChanged: if (opacity === 0 && !shown && !root.open) root.loaded = false

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
