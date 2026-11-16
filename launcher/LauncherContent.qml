// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.core
import qs.services
import qs.theme
import "Fuzzy.js" as Fuzzy

// Search field + ranked results.
// Keys: type to filter, Up/Down (or Tab/Shift+Tab, Ctrl+N/P) to move,
// PageUp/PageDown, Enter to launch, Esc to close (handled by AltairPanel).
// Right-click an app (or Menu / Shift+F10 on the selected one) for its menu.
FocusScope {
    id: root

    // Needed so the Loader in AltairPanel hands keyboard focus to us (and on
    // to the search field) as soon as the launcher opens.
    focus: true

    property int rows: 7
    property int rowHeight: 52
    property int searchHeight: 52

    // Height the panel shrinks to: search row + the results shown (one row
    // for "no match"), or more while the app menu needs the room.
    readonly property real listHeight: Math.max(1, Math.min(rows, results.length)) * rowHeight
    readonly property real wantedHeight: Math.max(
        Theme.space.s * 3 + searchHeight + 1 + listHeight,
        menu.open ? menu.y + menu.height + Theme.space.s : 0)

    // Re-ranked on every keystroke (~1.4 ms for ~50 apps).
    readonly property var results: Fuzzy.rank(search.text, Apps.list, Apps.launches)
    // A new search: the best match is selected and the list starts at the
    // top. (The view would otherwise keep following the previously selected
    // app to its new row and scroll there.)
    onResultsChanged: Qt.callLater(() => {
        list.currentIndex = 0;
        list.positionViewAtBeginning();
    })

    // Last pointer position (screen coordinates) seen over the list; null until
    // the first hover event. Hovering only changes the selection when the
    // pointer really moved, so keyboard navigation isn't undone when the list
    // scrolls under a resting pointer, or when the launcher opens under it.
    property var lastPointer: null

    function pointerMoved(pos: point, index: int): void {
        const moved = lastPointer !== null && (pos.x !== lastPointer.x || pos.y !== lastPointer.y);
        lastPointer = pos;
        if (moved)
            list.currentIndex = index;
    }

    function move(delta: int): void {
        if (results.length === 0)
            return;
        list.currentIndex = Math.max(0, Math.min(results.length - 1, list.currentIndex + delta));
    }

    function launchCurrent(): void {
        const entry = results[list.currentIndex];
        if (!entry)
            return;
        Apps.launch(entry);
        ShellState.close();
    }

    // ---- Search row ----------------------------------------------------------
    Item {
        id: searchRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.space.s
        height: root.searchHeight

        Icon {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: Theme.space.m
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 22
            color: Theme.fgMuted
        }

        TextInput {
            id: search
            anchors.left: searchIcon.right
            anchors.leftMargin: Theme.space.m
            anchors.right: parent.right
            anchors.rightMargin: Theme.space.m
            anchors.verticalCenter: parent.verticalCenter
            focus: true
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccent
            // Caret: solid while typing, then a soft fading blink for a few
            // seconds, then solid again (each fade redraws the launcher, so
            // it doesn't blink forever while the launcher sits open).
            cursorDelegate: Rectangle {
                id: caret
                width: 2
                radius: 1
                color: Theme.accent
                visible: search.activeFocus
                property bool typing: true
                Connections {
                    target: search
                    function onTextChanged() { caret.typing = true; caret.opacity = 1; idle.restart(); }
                    function onCursorPositionChanged() { caret.typing = true; caret.opacity = 1; idle.restart(); }
                }
                Timer { id: idle; interval: 700; running: true; onTriggered: caret.typing = false }
                SequentialAnimation on opacity {
                    running: !caret.typing && search.activeFocus && Theme.animations
                    loops: 4
                    PauseAnimation { duration: 450 }
                    NumberAnimation { to: 0; duration: 160; easing.type: Easing.InOutSine }
                    PauseAnimation { duration: 300 }
                    NumberAnimation { to: 1; duration: 160; easing.type: Easing.InOutSine }
                }
            }
            font.family: Theme.font.family
            font.pixelSize: Theme.font.title
            clip: true

            onTextChanged: {
                list.currentIndex = 0;
                menu.close();
            }

            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                if (menu.open && menu.handleKey(event)) {
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
                    const it = list.currentItem;
                    if (it) {
                        root.openMenu(list.currentIndex, it.mapToItem(root, it.width - 200, it.height / 2));
                        menu.current = 0;
                    }
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_N)) {
                    root.move(1);
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_P)) {
                    root.move(-1);
                } else if (event.key === Qt.Key_PageDown) {
                    root.move(list.visibleRows);
                } else if (event.key === Qt.Key_PageUp) {
                    root.move(-list.visibleRows);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.launchCurrent();
                } else {
                    return;
                }
                event.accepted = true;
            }

            StyledText {
                anchors.fill: parent
                visible: search.text.length === 0
                text: "Search apps"
                color: Theme.fgDisabled
                font.pixelSize: Theme.font.title
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: searchRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.border
    }

    // ---- Results ---------------------------------------------------------------
    ListView {
        id: list

        readonly property int visibleRows: Math.floor(height / root.rowHeight)

        anchors.top: divider.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.space.s
        clip: true
        // ScriptModel diffs each new result list against the last (by desktop
        // id), so rows that stay keep their delegate and can glide; rows
        // that come or go get the add/remove transitions below.
        model: ScriptModel {
            values: root.results
            objectProp: "id"
        }

        // Search animations (Settings > Effects): "off" | "subtle" | "lively".
        readonly property string anim: Theme.animations ? Theme.searchAnim : "off"
        readonly property bool animOn: anim !== "off"
        readonly property bool lively: anim === "lively"
        add: Transition {
            enabled: list.animOn
            SequentialAnimation {
                // Start after the leaving rows have faded (no overlap);
                // Lively: new rows arrive one after another.
                PropertyAction { property: "opacity"; value: 0 }
                PauseAnimation { duration: 70 + (list.lively ? Math.min(6, ViewTransition.index) * 18 : 0) }
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: list.lively ? 260 : 180; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "x"; from: list.lively ? 14 : 6; to: 0; duration: list.lively ? 320 : 220; easing.type: Easing.OutQuint }
                }
            }
        }
        remove: Transition {
            enabled: list.animOn
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 70; easing.type: Easing.InQuad }
                NumberAnimation { property: "x"; to: list.lively ? -10 : 0; duration: 70; easing.type: Easing.InQuad }
            }
        }
        displaced: Transition {
            enabled: list.animOn
            NumberAnimation { property: "y"; duration: list.lively ? 300 : 220; easing.type: Easing.OutQuint }
            // A row interrupted mid-fade must end fully visible.
            NumberAnimation { property: "opacity"; to: 1; duration: 120 }
            NumberAnimation { property: "x"; to: 0; duration: 120 }
        }
        move: Transition {
            enabled: list.animOn
            NumberAnimation { property: "y"; duration: list.lively ? 300 : 220; easing.type: Easing.OutQuint }
        }
        boundsBehavior: Flickable.StopAtBounds
        // Keep the highlight in view when moving with the keyboard.
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Theme.anim.fast
        highlightMoveVelocity: -1
        // Qt's default grows the highlight at 400 px/s: on open it crept
        // in from zero width. Rows all have the same size: no resize.
        highlightResizeDuration: 0
        highlightResizeVelocity: -1
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: height

        highlight: Rectangle {
            radius: Theme.radius.m
            color: Qt.alpha(Theme.accent, 0.16)
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.35)
        }

        delegate: AppItem {
            required property var modelData
            required property int index
            entry: modelData
            width: list.width
            height: root.rowHeight
            current: ListView.isCurrentItem
            onHovered: pos => root.pointerMoved(pos, index)
            onActivated: {
                list.currentIndex = index;
                root.launchCurrent();
            }
            onMenuRequested: pos => {
                list.currentIndex = index;
                root.openMenu(index, mapToItem(root, pos.x, pos.y));
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (root.rowHeight - height) / 2
            visible: root.results.length === 0
            text: Apps.list.length === 0 ? "Loading apps…" : `No apps match "${search.text}"`
            color: Theme.fgMuted
        }
    }

    // ---- App menu ----------------------------------------------------------------
    // Drawn inside the launcher (a separate popup surface would fight the
    // launcher's click-outside grab). The panel grows while it needs room.
    function openMenu(index: int, pos: point): void {
        const entry = results[index];
        if (!entry)
            return;
        menu.entry = entry;
        menu.x = Math.max(Theme.space.s, Math.min(width - menu.width - Theme.space.s, pos.x));
        menu.anchorY = pos.y;
        menu.open = true;
    }

    // Click anywhere else in the launcher: close the menu.
    MouseArea {
        anchors.fill: parent
        visible: menu.open
        z: 9
        acceptedButtons: Qt.AllButtons
        onPressed: menu.close()
    }

    AppMenu {
        id: menu
        z: 10
        onLaunched: ShellState.close()
    }
}
