// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.components
import qs.core
import qs.services
import qs.theme

// The launcher's right-click menu for one app: open (or switch to it when it
// is running), the app's own actions from its .desktop file, a new window,
// pin/unpin in the dock, copy the launch command.
// Keys while open: Up/Down, Enter, Esc (forwarded by LauncherContent).
Item {
    id: root

    property var entry: null
    property bool open: false
    property int current: -1
    signal launched()

    width: 248
    height: col.implicitHeight + Theme.space.xs * 2
    // Where it was opened (y in the launcher). It opens downward when it
    // fits in the launcher's full height, else upward from that point
    // (e.g. on the last row), never past the top.
    property real anchorY: 0
    readonly property real room: parent ? parent.height : 0
    readonly property bool upward: anchorY + height + Theme.space.s > room
    y: upward ? Math.max(Theme.space.s, anchorY - height) : Math.max(Theme.space.s, anchorY)
    transformOrigin: upward ? Item.BottomLeft : Item.TopLeft
    visible: opacity > 0
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.96
    Behavior on opacity { NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Theme.anim.normal; easing.type: Easing.OutQuint } }

    function close(): void {
        open = false;
        current = -1;
    }

    // Windows of this app, if it runs (same matching as the dock).
    readonly property var windows: {
        if (!entry)
            return [];
        return Hyprland.toplevels.values.filter(t => DockApps.entryFor(DockApps.appIdOf(t))?.id === entry.id);
    }
    readonly property bool pinned: entry ? DockApps.pinned.indexOf(entry.id) !== -1 : false

    readonly property var rows: {
        if (!entry)
            return [];
        const e = entry;
        const r = [];
        if (windows.length > 0) {
            r.push({ icon: "open_in_new", label: "Switch to " + e.name, run: () => DockApps.focus(windows[0]) });
            r.push({ icon: "add", label: "New window", run: () => Apps.launch(e) });
        } else {
            r.push({ icon: "open_in_new", label: "Open", run: () => Apps.launch(e) });
        }
        for (const a of Array.from(e.actions ?? []))
            r.push({ icon: "bolt", label: a.name, run: () => Hypr.exec(Array.from(a.command), e.workingDirectory) });
        r.push({ sep: true });
        r.push({
            icon: "keep",
            label: pinned ? "Unpin from dock" : "Pin to dock" + (Config.dock.enabled ? "" : " (dock is off)"),
            run: () => pinned ? DockApps.unpin(e.id) : DockApps.pin(e.id, -1),
            stay: true
        });
        r.push({ icon: "content_copy", label: "Copy launch command", run: () => Quickshell.clipboardText = e.execString, stay: true });
        return r;
    }

    function trigger(i: int): void {
        const row = rows[i];
        if (!row || row.sep)
            return;
        row.run();
        if (row.stay) {
            close();
        } else {
            close();
            launched();
        }
    }

    function step(d: int): void {
        let i = current;
        for (let n = 0; n < rows.length; n++) {
            i = (i + d + rows.length) % rows.length;
            if (!rows[i].sep) {
                current = i;
                return;
            }
        }
    }

    // Returns true when the key was for the menu.
    function handleKey(event): bool {
        switch (event.key) {
        case Qt.Key_Escape:
            close();
            return true;
        case Qt.Key_Down:
        case Qt.Key_Tab:
            step(1);
            return true;
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            step(-1);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (current >= 0)
                trigger(current);
            else
                close();
            return true;
        }
        return false;
    }

    GlassBackground {
        anchors.fill: parent
        radius: Theme.radius.m
        solidity: 0.5     // sits on the launcher's own glass
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.space.xs
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            Layout.margins: Theme.space.s
            Layout.bottomMargin: Theme.space.xs
            text: root.entry?.name ?? ""
            color: Theme.fgMuted
            font.pixelSize: Theme.font.small
            elide: Text.ElideRight
        }

        Repeater {
            model: root.rows
            Loader {
                id: rowLoader
                required property var modelData
                required property int index
                Layout.fillWidth: true
                sourceComponent: modelData.sep ? sepComp : rowComp

                Component {
                    id: sepComp
                    Item {
                        implicitHeight: 1 + Theme.space.xs * 2
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - Theme.space.s * 2
                            height: 1
                            color: Theme.border
                        }
                    }
                }
                Component {
                    id: rowComp
                    MenuRow {
                        iconName: rowLoader.modelData.icon
                        label: rowLoader.modelData.label.replace(/_/g, "__")
                        onClicked: root.trigger(rowLoader.index)
                        // Keyboard selection looks like hover.
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius.s
                            color: Theme.hover
                            visible: root.current === rowLoader.index
                        }
                    }
                }
            }
        }
    }
}
