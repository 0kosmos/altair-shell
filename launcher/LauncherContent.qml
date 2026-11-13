// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.core
import qs.services
import qs.theme
import "Fuzzy.js" as Fuzzy

// Search field + ranked results.
// Keys: type to filter, Up/Down (or Tab/Shift+Tab, Ctrl+N/P) to move,
// PageUp/PageDown, Enter to launch, Esc to close (handled by AltairPanel).
FocusScope {
    id: root

    // Needed so the Loader in AltairPanel hands keyboard focus to us (and on
    // to the search field) as soon as the launcher opens.
    focus: true

    property int rowHeight: 52
    property int searchHeight: 52

    // Re-ranked on every keystroke (~1.4 ms for ~50 apps).
    readonly property var results: Fuzzy.rank(search.text, Apps.list, Apps.launches)

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
            font.family: Theme.font.family
            font.pixelSize: Theme.font.title
            clip: true

            onTextChanged: list.currentIndex = 0

            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_N)) {
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
        model: root.results
        boundsBehavior: Flickable.StopAtBounds
        // Keep the highlight in view when moving with the keyboard.
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Theme.anim.fast
        highlightMoveVelocity: -1
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
        }

        StyledText {
            anchors.centerIn: parent
            visible: root.results.length === 0
            text: Apps.list.length === 0 ? "Loading apps…" : `No apps match "${search.text}"`
            color: Theme.fgMuted
        }
    }
}
