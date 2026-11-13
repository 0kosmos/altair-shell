// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services
import qs.theme

// Popup stack in the top-right corner (bottom-right if the bar is at the
// bottom). The window exists only while there are popups to show.
Scope {
    id: root

    readonly property int cardWidth: 380

    LazyLoader {
        active: Notifs.popups.length > 0

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

            WlrLayershell.namespace: "altair-notification-popups"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // Normal + zero exclusive zone: placed next to the bar, not under it.
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0

            anchors {
                top: Theme.barAtTop
                bottom: !Theme.barAtTop
                right: true
            }
            margins {
                top: Theme.barGap
                bottom: Theme.barGap
                right: Theme.barGap
            }

            // Fixed size so the surface never resizes while cards animate; only
            // the cards themselves take input (mask) and get blur.
            implicitWidth: root.cardWidth
            implicitHeight: Math.round((screen?.height ?? 1080) * 0.7)
            color: "transparent"
            mask: Region {
                item: column
            }

            // One blur slot per possible popup (Region's child list is fixed,
            // so it can't follow the model directly). A slot is empty when there
            // is no card at that index or the card is animating out.
            BackgroundEffect.blurRegion: Theme.blur ? blur : null
            Region {
                id: blur
                Region { item: repeater.count > 0 ? repeater.itemAt(0)?.blurTarget ?? null : null; radius: Theme.radius.l }
                Region { item: repeater.count > 1 ? repeater.itemAt(1)?.blurTarget ?? null : null; radius: Theme.radius.l }
                Region { item: repeater.count > 2 ? repeater.itemAt(2)?.blurTarget ?? null : null; radius: Theme.radius.l }
                Region { item: repeater.count > 3 ? repeater.itemAt(3)?.blurTarget ?? null : null; radius: Theme.radius.l }
                Region { item: repeater.count > 4 ? repeater.itemAt(4)?.blurTarget ?? null : null; radius: Theme.radius.l }
            }

            Column {
                id: column
                anchors.right: parent.right
                anchors.top: Theme.barAtTop ? parent.top : undefined
                anchors.bottom: Theme.barAtTop ? undefined : parent.bottom
                width: root.cardWidth
                spacing: Theme.space.s

                // Remaining cards glide into place when one leaves.
                move: Transition {
                    NumberAnimation {
                        properties: "y"
                        duration: Theme.anim.normal
                        easing.type: Theme.anim.easing
                    }
                }

                Repeater {
                    id: repeater
                    // ScriptModel diffs the array, so existing cards are kept
                    // (and keep their timers) when a new one arrives.
                    model: ScriptModel {
                        values: Notifs.popups
                    }

                    PopupCard {}
                }
            }
        }
    }

    component PopupCard: Item {
        id: slot

        required property var modelData
        property bool leaving: false
        // What the blur slot should cover; nothing while animating out.
        readonly property Item blurTarget: leaving ? null : card

        width: root.cardWidth
        height: card.implicitHeight

        // Slide out to the right, then remove. `dismiss` = also delete it.
        function leave(dismiss: bool): void {
            if (leaving)
                return;
            leaving = true;
            exit.dismiss = dismiss;
            exit.start();
        }

        // Popup lifetime in ms; 0 = stays until closed (critical, or app asked).
        readonly property int timeoutMs: Notifs.timeoutFor(modelData)

        // NOTE: a Timer can fire once while this item is still being created,
        // before the bindings below have settled, and an interval of 0 fires
        // immediately. Hence the explicit timeoutMs checks.
        Timer {
            id: timeout
            interval: Math.max(1, slot.timeoutMs)
            running: slot.timeoutMs > 0 && !card.hovered && !slot.leaving
            onTriggered: {
                if (slot.timeoutMs > 0)
                    slot.leave(false);
            }
        }

        Connections {
            target: Notifs
            function onPopupShown(n) {
                if (n === slot.modelData && slot.timeoutMs > 0)
                    timeout.restart();
            }
        }

        NotificationCard {
            id: card
            width: parent.width
            notification: slot.modelData
            inPopup: true
            onCloseRequested: slot.leave(true)

            // Enter: fade in and slide from the right.
            opacity: 0
            transform: Translate {
                id: shift
                x: 24
            }
            Component.onCompleted: enter.start()
        }

        ParallelAnimation {
            id: enter
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: Theme.anim.normal; easing.type: Theme.anim.easing }
            NumberAnimation { target: shift; property: "x"; to: 0; duration: Theme.anim.normal; easing.type: Theme.anim.easing }
        }

        SequentialAnimation {
            id: exit
            property bool dismiss: false
            ParallelAnimation {
                NumberAnimation { target: card; property: "opacity"; to: 0; duration: Theme.anim.fast; easing.type: Theme.anim.easingIn }
                NumberAnimation { target: shift; property: "x"; to: 32; duration: Theme.anim.fast; easing.type: Theme.anim.easingIn }
            }
            ScriptAction {
                script: exit.dismiss ? Notifs.dismiss(slot.modelData) : Notifs.hidePopup(slot.modelData)
            }
        }
    }
}
