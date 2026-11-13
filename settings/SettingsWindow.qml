// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.core
import qs.services
import qs.theme

// The Settings app: a normal (floating) window with a sidebar. Open with
// SUPER+comma, "Altair Settings" in the launcher, or
// `qs -c altair ipc call panels toggle settings`.
// Every change is saved to ~/.config/altair/config.json immediately.
//
// It is an ordinary window, so Hyprland's window rules apply: hypr/init.lua
// makes it float, centred, at 1000x700 with corner rounding matching ours
// (class org.quickshell, this title).
Scope {
    id: settings

    // Whether the window exists. Set true when Settings opens, and false only
    // after the fade-out (or right away if Hyprland closed the window).
    // NOTE: one flag on purpose. "open || closing" let the loader see both as
    // false for a moment on close, destroy the window and build a new one.
    property bool loaded: false
    readonly property bool wanted: ShellState.settingsOpen
    onWantedChanged: if (wanted) loaded = true
    // Safety net, in case the fade-out never finishes.
    Timer {
        running: settings.loaded && !settings.wanted
        interval: Theme.anim.slow + 400
        onTriggered: settings.loaded = false
    }

    LazyLoader {
        active: settings.loaded

        FloatingWindow {
            id: win

            title: "Altair Settings"
            implicitWidth: 1000
            implicitHeight: 700
            minimumSize: Qt.size(760, 520)
            // The background is drawn by GlassBackground below (so liquid glass
            // applies here too); the window itself is transparent.
            color: "transparent"

            property string page: "appearance"
            // Sidebar entries, grouped. Add a page: an entry here + a case in
            // pageSource() below + a <Name>Page.qml file.
            readonly property var pages: [
                { id: "appearance", label: "Appearance", icon: "palette", group: "Personalise" },
                { id: "wallpaper", label: "Wallpaper", icon: "wallpaper", group: "Personalise" },
                { id: "bar", label: "Bar", icon: "toolbar", group: "Personalise" },
                { id: "windows", label: "Windows", icon: "select_window", group: "Desktop" },
                { id: "transparency", label: "Transparency", icon: "opacity", group: "Desktop" },
                { id: "effects", label: "Effects", icon: "auto_awesome", group: "Desktop" },
                { id: "notifications", label: "Notifications", icon: "notifications", group: "System" },
                { id: "performance", label: "Performance", icon: "speed", group: "System" },
                { id: "about", label: "About", icon: "info", group: "System" },
            ]

            // Closed by Hyprland (e.g. SUPER+C): the window is already gone, so
            // no fade; drop it right away and keep our state in sync.
            onVisibleChanged: {
                if (!visible) {
                    settings.loaded = false;
                    ShellState.settingsOpen = false;
                }
            }

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

                // Closing: the opening animation in reverse, then the window goes.
                ParallelAnimation {
                    id: closeAnim
                    NumberAnimation { target: body; property: "opacity"; to: 0; duration: Theme.anim.normal; easing.type: Theme.anim.easingIn }
                    NumberAnimation { target: body; property: "scale"; to: 0.98; duration: Theme.anim.normal; easing.type: Theme.anim.easingIn }
                    onFinished: settings.loaded = false
                }

                Connections {
                    target: ShellState
                    function onSettingsOpenChanged() {
                        if (ShellState.settingsOpen) {
                            closeAnim.stop();
                            openAnim.start();
                        } else {
                            openAnim.stop();
                            closeAnim.start();
                        }
                    }
                }

                // Double-click on any empty spot (sidebar, margins): back to the
                // default size, centred. Controls on top take their own clicks;
                // pages report theirs via backgroundDoubleClicked.
                MouseArea {
                    anchors.fill: parent
                    onDoubleClicked: win.resetGeometry()
                }

                // Radius deliberately SMALLER than Hyprland's window rounding (18,
                // see hypr/init.lua): Hyprland cuts the corners itself, and with
                // equal radii the two anti-aliased curves left tiny see-through
                // spots in the corners.
                GlassBackground {
                    anchors.fill: parent
                    radius: Theme.radius.m
                    bordered: false
                    solidity: 0.85
                    rim: 0.35
                }

                FocusScope {
                    anchors.fill: parent
                    focus: true
                    Keys.onEscapePressed: ShellState.settingsOpen = false
                    // Keyboard: Ctrl+0 re-centres; Tab / Shift+Tab and Left/Right
                    // switch pages; Up/Down scroll, and at the end of a page (or on
                    // a page that fits) move to the next/previous page (only on a
                    // fresh press, so holding a key never races through pages);
                    // PageUp/PageDown, Home/End scroll. Focused controls get keys
                    // first (text fields, sliders), so they keep working.
                    Keys.onPressed: event => {
                        const page = pageLoader.item;
                        const ctrl = event.modifiers & Qt.ControlModifier;
                        if (event.key === Qt.Key_0 && ctrl)
                            win.resetGeometry();
                        // Shift+Tab arrives as Backtab, or as Tab with Shift held
                        // (depends on keyboard/layout): treat both as "back".
                        else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)))
                            win.stepPage(-1);
                        else if (event.key === Qt.Key_Tab)
                            win.stepPage(1);
                        else if (event.key === Qt.Key_Right)
                            win.stepPage(1);
                        else if (event.key === Qt.Key_Left)
                            win.stepPage(-1);
                        else if (page && event.key === Qt.Key_Down) {
                            if (page.atEnd(1)) {
                                if (!event.isAutoRepeat)
                                    win.stepPage(1);
                            } else {
                                page.scrollBy(70);
                            }
                        } else if (page && event.key === Qt.Key_Up) {
                            if (page.atEnd(-1)) {
                                if (!event.isAutoRepeat)
                                    win.stepPage(-1);
                            } else {
                                page.scrollBy(-70);
                            }
                        }
                        else if (page && event.key === Qt.Key_PageDown)
                            page.scrollBy(page.height * 0.85);
                        else if (page && event.key === Qt.Key_PageUp)
                            page.scrollBy(-page.height * 0.85);
                        else if (page && event.key === Qt.Key_Home)
                            page.scrollTo(0);
                        else if (page && event.key === Qt.Key_End)
                            page.scrollTo(page.maxY);
                        else
                            return;
                        event.accepted = true;
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        // ---- Sidebar ------------------------------------------------
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 230
                            color: Theme.surfaceRaised
                            topLeftRadius: Theme.radius.m
                            bottomLeftRadius: Theme.radius.m

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

                                    ColumnLayout {
                                        id: entry
                                        required property var modelData
                                        required property int index
                                        readonly property bool firstOfGroup: index === 0 || win.pages[index - 1].group !== modelData.group

                                        Layout.fillWidth: true
                                        spacing: 2

                                        // Group heading above the first page of each group.
                                        StyledText {
                                            visible: entry.firstOfGroup
                                            Layout.leftMargin: Theme.space.s
                                            Layout.topMargin: entry.index === 0 ? 0 : Theme.space.m
                                            Layout.bottomMargin: 2
                                            text: entry.modelData.group
                                            color: Theme.fgDisabled
                                            font.pixelSize: Theme.font.small
                                            font.weight: Font.DemiBold
                                            font.capitalization: Font.AllUppercase
                                            font.letterSpacing: 0.6
                                        }

                                        MouseArea {
                                            id: nav
                                            readonly property var modelData: entry.modelData
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
                                }

                                Item { Layout.fillHeight: true }

                                StyledText {
                                    Layout.leftMargin: Theme.space.s
                                    // Wraps: a long line would widen the whole sidebar layout.
                                    Layout.fillWidth: true
                                    Layout.rightMargin: Theme.space.s
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideNone
                                    text: "Altair " + ShellState.version + "\nArrows / Tab: scroll and switch pages\nDouble-click an empty spot or Ctrl+0 to re-centre"
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

                            Connections {
                                target: pageLoader.item
                                ignoreUnknownSignals: true
                                function onBackgroundDoubleClicked() {
                                    win.resetGeometry();
                                }
                            }
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

            // Default size, centred on the monitor (via Hyprland: it owns the
            // window's position).
            // Next/previous page in the sidebar, wrapping around.
            function stepPage(delta: int): void {
                const i = pages.findIndex(p => p.id === page);
                page = pages[(i + delta + pages.length) % pages.length].id;
            }

            function resetGeometry(): void {
                Hypr.resetWindowByTitle(win.title, win.implicitWidth, win.implicitHeight);
            }

            function pageSource(id: string): string {
                switch (id) {
                case "wallpaper": return "WallpaperPage.qml";
                case "bar": return "BarPage.qml";
                case "windows": return "WindowsPage.qml";
                case "transparency": return "TransparencyPage.qml";
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
