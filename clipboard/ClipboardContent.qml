// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import qs.components
import qs.core
import qs.services
import qs.theme

// Search field + clipboard entries (newest first).
// Keys: type to filter, Up/Down to move, Enter to copy (and paste, if on),
// Shift+Enter to only copy, Delete to remove an entry, Esc to close.
FocusScope {
    id: root
    focus: true

    property int rows: 7
    property int rowHeight: 56
    property int searchHeight: 52

    readonly property bool ready: Clipboard.available && Clipboard.enabled
    readonly property string query: search.text.trim().toLowerCase()
    readonly property var results: !ready ? []
        : query === "" ? Clipboard.entries
        : Clipboard.entries.filter(e => (e.image ? "image " + e.info : e.text).toLowerCase().indexOf(query) !== -1)
    onResultsChanged: Qt.callLater(() => {
        if (list.currentIndex >= results.length || query !== lastQuery) {
            list.currentIndex = 0;
            list.positionViewAtBeginning();
        }
        lastQuery = query;
    })
    property string lastQuery: ""

    // One row for a message; two when it has a button.
    readonly property real listHeight: Math.max(results.length === 0 && Clipboard.available && !Clipboard.enabled ? 2 : 1,
        Math.min(rows, results.length)) * rowHeight
    readonly property real wantedHeight: Theme.space.s * 3 + searchHeight + 1 + listHeight

    Component.onCompleted: Clipboard.refresh()
    // The fresh list (new copies on top) replaces the one from last time:
    // select the newest entry, not the row the old selection slid to.
    Connections {
        target: Clipboard
        function onLoadingChanged() {
            if (!Clipboard.loading) {
                list.currentIndex = 0;
                list.positionViewAtBeginning();
            }
        }
    }

    function move(delta: int): void {
        if (results.length > 0)
            list.currentIndex = Math.max(0, Math.min(results.length - 1, list.currentIndex + delta));
    }
    function useCurrent(paste: bool): void {
        const e = results[list.currentIndex];
        if (!e)
            return;
        ShellState.close();
        Clipboard.use(e, paste && Clipboard.autoPaste);
    }

    // ---- Search row ------------------------------------------------------------------
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
            name: "content_paste_search"
            size: 22
            color: Theme.fgMuted
        }
        TextInput {
            id: search
            anchors.left: searchIcon.right
            anchors.leftMargin: Theme.space.m
            anchors.right: clearButton.left
            anchors.rightMargin: Theme.space.s
            anchors.verticalCenter: parent.verticalCenter
            focus: true
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccent
            font.family: Theme.font.family
            font.pixelSize: Theme.font.title
            clip: true
            onTextEdited: Sounds.typing()

            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_N)) {
                    root.move(1);
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_P)) {
                    root.move(-1);
                } else if (event.key === Qt.Key_PageDown) {
                    root.move(root.rows);
                } else if (event.key === Qt.Key_PageUp) {
                    root.move(-root.rows);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.useCurrent(!(event.modifiers & Qt.ShiftModifier));
                } else if (event.key === Qt.Key_Delete) {
                    Clipboard.remove(root.results[list.currentIndex]);
                } else {
                    return;
                }
                event.accepted = true;
            }

            StyledText {
                anchors.fill: parent
                visible: search.text.length === 0
                text: "Search the clipboard"
                color: Theme.fgDisabled
                font.pixelSize: Theme.font.title
            }
        }
        IconButton {
            id: clearButton
            anchors.right: parent.right
            anchors.rightMargin: Theme.space.xs
            anchors.verticalCenter: parent.verticalCenter
            visible: root.ready && Clipboard.entries.length > 0
            icon: "delete_sweep"
            onClicked: clearArmed ? (Clipboard.wipe(), clearArmed = false) : (clearArmed = true, disarm.restart())
            property bool clearArmed: false
            color: clearArmed ? Theme.critical : Theme.fgMuted
            Timer { id: disarm; interval: 3000; onTriggered: clearButton.clearArmed = false }
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

    // ---- Entries ------------------------------------------------------------------------
    ListView {
        id: list
        anchors.top: divider.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.space.s
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: root.results
            objectProp: "id"
        }
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Theme.anim.fast
        highlightMoveVelocity: -1
        highlightResizeDuration: 0
        highlightResizeVelocity: -1
        highlight: Rectangle {
            radius: Theme.radius.m
            color: Qt.alpha(Theme.accent, 0.16)
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.35)
        }
        remove: Transition {
            enabled: Theme.animations
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 140 }
                NumberAnimation { property: "x"; to: -16; duration: 140; easing.type: Easing.InQuad }
            }
        }
        displaced: Transition {
            enabled: Theme.animations
            NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutQuint }
        }

        delegate: MouseArea {
            id: row
            required property var modelData
            required property int index
            width: list.width
            height: root.rowHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onEntered: list.currentIndex = index
            onClicked: mouse => {
                list.currentIndex = index;
                if (mouse.button === Qt.MiddleButton)
                    Clipboard.remove(modelData);
                else
                    root.useCurrent(true);
            }

            // Image: thumbnail + size; text: up to two lines.
            Rectangle {
                id: thumbBox
                visible: row.modelData.image
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.m
                anchors.verticalCenter: parent.verticalCenter
                width: 72
                height: 44
                radius: Theme.radius.s
                color: Theme.surfaceRaised
                clip: true
                Image {
                    id: thumbImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(144, 88)
                    source: {
                        void Clipboard.thumbVersion;
                        return row.modelData.image && Clipboard.thumbsDone[row.modelData.id]
                            ? "file://" + Clipboard.thumb(row.modelData.id) : "";
                    }
                }
                Icon {
                    anchors.centerIn: parent
                    visible: thumbImage.status !== Image.Ready
                    name: "image"
                    color: Theme.fgMuted
                }
            }
            Column {
                anchors.left: row.modelData.image ? thumbBox.right : parent.left
                anchors.leftMargin: Theme.space.m
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.m
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                StyledText {
                    width: parent.width
                    text: row.modelData.image ? "Image" : row.modelData.text.replace(/\s+/g, " ").trim()
                    maximumLineCount: row.modelData.image ? 1 : 2
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideRight
                    font.pixelSize: Theme.font.body
                    font.weight: row.ListView.isCurrentItem && row.modelData.image ? Font.DemiBold : Font.Normal
                }
                StyledText {
                    width: parent.width
                    visible: row.modelData.image
                    text: row.modelData.info
                    color: Theme.fgMuted
                    font.pixelSize: Theme.font.small
                }
            }
        }

        // Empty states.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (root.rowHeight - height) / 2
            visible: root.results.length === 0
            spacing: Theme.space.s
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !Clipboard.checked ? ""
                    : !Clipboard.available ? "Clipboard history needs cliphist (sudo pacman -S cliphist)."
                    : !Clipboard.enabled ? "Clipboard history is off."
                    : Clipboard.loading ? "Loading…"
                    : root.query !== "" ? `Nothing matches "${search.text}"`
                    : "Nothing copied yet."
                color: Theme.fgMuted
            }
            PillButton {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Clipboard.available && !Clipboard.enabled
                text: "Turn on"
                onClicked: Config.clipboard.enabled = true
            }
        }
    }
}
