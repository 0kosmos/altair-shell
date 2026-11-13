// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.core
import qs.theme

// The Settings app: a normal (floating) window with a sidebar. Open with
// SUPER+comma, "Altair Settings" in the launcher, or
// `qs -c altair ipc call panels toggle settings`.
// Every change is saved to ~/.config/altair/config.json immediately.
//
// It is an ordinary window, so Hyprland's window rules apply: hypr/init.lua
// makes it float, centred, at 820x560 with corner rounding matching ours
// (class org.quickshell, this title).
Scope {
    LazyLoader {
        active: ShellState.settingsOpen

        FloatingWindow {
            id: win

            title: "Altair Settings"
            implicitWidth: 820
            implicitHeight: 560
            minimumSize: Qt.size(640, 420)
            // The background is drawn by GlassBackground below (so liquid glass
            // applies here too); the window itself is transparent.
            color: "transparent"

            property string page: "appearance"
            readonly property var pages: [
                { id: "appearance", label: "Appearance", icon: "palette" },
                { id: "effects", label: "Effects", icon: "auto_awesome" },
                { id: "notifications", label: "Notifications", icon: "notifications" },
                { id: "performance", label: "Performance", icon: "speed" },
                { id: "about", label: "About", icon: "info" },
            ]

            // Closed by the compositor (e.g. SUPER+C): keep our state in sync.
            onVisibleChanged: if (!visible) ShellState.settingsOpen = false

            // Mostly solid: a settings page needs readable text more than glass.
            // Hyprland draws the window border, so no hairline border of our own.
            // Radius = the window rounding set by the rule in hypr/init.lua.
            // Everything fades in and grows from 98 % on open (Hyprland's own
            // animation is off for this window, see the rule in hypr/init.lua).
            Item {
                id: body
                anchors.fill: parent
                opacity: 0
                scale: 0.98
                Component.onCompleted: openAnim.start()

                ParallelAnimation {
                    id: openAnim
                    NumberAnimation { target: body; property: "opacity"; to: 1; duration: Theme.anim.normal; easing.type: Theme.anim.easing }
                    NumberAnimation { target: body; property: "scale"; to: 1; duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide }
                }

                GlassBackground {
                    anchors.fill: parent
                    radius: Theme.radius.l
                    bordered: false
                    solidity: 0.85
                }

                FocusScope {
                    anchors.fill: parent
                    focus: true
                    Keys.onEscapePressed: ShellState.settingsOpen = false

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        // ---- Sidebar ------------------------------------------------
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 210
                            color: Theme.surfaceRaised
                            topLeftRadius: Theme.radius.l
                            bottomLeftRadius: Theme.radius.l

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.space.m
                                spacing: 2

                                StyledText {
                                    Layout.leftMargin: Theme.space.s
                                    Layout.topMargin: Theme.space.s
                                    Layout.bottomMargin: Theme.space.m
                                    text: "Settings"
                                    font.pixelSize: Theme.font.title
                                    font.weight: Font.DemiBold
                                }

                                Repeater {
                                    model: win.pages

                                    MouseArea {
                                        id: nav
                                        required property var modelData
                                        readonly property bool selected: win.page === modelData.id

                                        Layout.fillWidth: true
                                        implicitHeight: 38
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.page = modelData.id
                                        scale: pressed ? Theme.anim.pressScale : 1
                                        Behavior on scale {
                                            NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.radius.s
                                            color: nav.selected ? Qt.alpha(Theme.accent, 0.16)
                                                : nav.containsMouse ? Theme.hover : "transparent"
                                            Behavior on color {
                                                ColorAnimation { duration: Theme.anim.fast }
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Theme.space.s
                                            spacing: Theme.space.s

                                            Icon {
                                                name: nav.modelData.icon
                                                fill: nav.selected ? 1 : 0
                                                color: nav.selected ? Theme.accent : Theme.fgMuted
                                            }
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: nav.modelData.label
                                                font.weight: nav.selected ? Font.DemiBold : Font.Normal
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                StyledText {
                                    Layout.leftMargin: Theme.space.s
                                    text: "Altair " + ShellState.version
                                    color: Theme.fgDisabled
                                    font.pixelSize: Theme.font.small
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillHeight: true
                            implicitWidth: 1
                            color: Theme.border
                        }

                        // ---- Page (only the visible one exists) ---------------------
                        // Switching pages: the old one fades out, the new one fades
                        // in while sliding up a little.
                        Loader {
                            id: pageLoader
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            source: win.pageSource(win.shownPage)

                            transform: Translate { id: pageShift }
                        }
                    }
                }
            }

            property string shownPage: page
            onPageChanged: {
                if (Theme.anim.fast === 0) {
                    shownPage = page;
                    return;
                }
                pageSwap.restart();
            }

            SequentialAnimation {
                id: pageSwap
                NumberAnimation { target: pageLoader; property: "opacity"; to: 0; duration: 90; easing.type: Theme.anim.easingIn }
                ScriptAction { script: win.shownPage = win.page }
                PropertyAction { target: pageShift; property: "y"; value: 10 }
                ParallelAnimation {
                    NumberAnimation { target: pageLoader; property: "opacity"; to: 1; duration: Theme.anim.normal; easing.type: Theme.anim.easing }
                    NumberAnimation { target: pageShift; property: "y"; to: 0; duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide }
                }
            }

            function pageSource(id: string): string {
                switch (id) {
                case "effects": return "EffectsPage.qml";
                case "notifications": return "NotificationsPage.qml";
                case "performance": return "PerformancePage.qml";
                case "about": return "AboutPage.qml";
                default: return "AppearancePage.qml";
                }
            }
        }
    }
}
