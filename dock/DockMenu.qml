// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.services
import qs.theme

// Right-click menu of a dock app: its windows (when there are several), the
// app's own actions from its .desktop file (e.g. "New private window"),
// open / new window, pin / unpin, close. Clicking outside closes it.
PopupWindow {
    id: root

    required property Item anchorItem
    required property var item
    property string position: "bottom"
    signal dismissed()

    readonly property int menuWidth: 248
    readonly property int gap: 10
    readonly property var entry: item?.entry ?? null
    readonly property var windows: item?.windows ?? []
    readonly property var actions: entry ? Array.from(entry.actions ?? []) : []

    // Opens toward the screen's centre.
    anchor.item: anchorItem
    anchor.rect.x: position === "left" ? anchorItem.width + gap : position === "right" ? -gap : 0
    anchor.rect.y: position === "bottom" ? -gap : 0
    anchor.rect.width: position === "bottom" ? anchorItem.width : 1
    anchor.rect.height: position === "bottom" ? 1 : anchorItem.height
    anchor.edges: position === "left" ? Edges.Right : position === "right" ? Edges.Left : Edges.Top
    anchor.gravity: position === "left" ? Edges.Right : position === "right" ? Edges.Left : Edges.Top

    grabFocus: true
    visible: true
    color: "transparent"
    implicitWidth: menuWidth
    implicitHeight: list.implicitHeight + Theme.space.xs * 2

    onVisibleChanged: if (!visible) dismissed()

    function close(): void {
        visible = false;
    }

    // The app quit while its menu was open (and wasn't pinned): nothing to show.
    onItemChanged: if (!item) close()

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

        opacity: 0
        transform: Translate {
            id: slide
            x: root.position === "left" ? -6 : root.position === "right" ? 6 : 0
            y: root.position === "bottom" ? 6 : 0
            Behavior on x { NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing } }
            Behavior on y { NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing } }
        }
        Component.onCompleted: {
            opacity = 1;
            slide.x = 0;
            slide.y = 0;
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing }
        }
    }

    ColumnLayout {
        id: list
        anchors.fill: parent
        anchors.margins: Theme.space.xs
        spacing: 0
        opacity: background.opacity
        transform: Translate { x: slide.x; y: slide.y }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.space.s
            Layout.rightMargin: Theme.space.s
            Layout.topMargin: Theme.space.xs
            Layout.bottomMargin: Theme.space.xs
            text: root.entry?.name || root.item?.appId || ""
            color: Theme.fgMuted
            font.pixelSize: Theme.font.small
            elide: Text.ElideRight
        }

        // Several windows: pick one.
        Repeater {
            model: root.windows.length > 1 ? root.windows : []
            MenuRow {
                required property var modelData
                iconName: modelData === Hyprland.activeToplevel ? "radio_button_checked" : "web_asset"
                label: (modelData.title || root.entry?.name || "").replace(/_/g, "__")
                onClicked: {
                    DockApps.focus(modelData);
                    root.close();
                }
            }
        }
        Separator { visible: root.windows.length > 1 }

        // Actions from the .desktop file.
        Repeater {
            model: root.actions
            MenuRow {
                required property var modelData
                iconName: "bolt"
                label: modelData.name.replace(/_/g, "__")
                onClicked: {
                    Hypr.exec(Array.from(modelData.command), root.entry.workingDirectory);
                    root.close();
                }
            }
        }
        Separator { visible: root.actions.length > 0 }

        MenuRow {
            visible: !!root.entry
            iconName: root.windows.length > 0 ? "add" : "open_in_new"
            label: root.windows.length > 0 ? "New window" : "Open"
            onClicked: {
                DockApps.launch(root.item);
                root.close();
            }
        }
        MenuRow {
            visible: !!root.entry
            iconName: "keep"
            label: root.item?.pinned ? "Unpin from dock" : "Pin to dock"
            onClicked: {
                if (root.item.pinned)
                    DockApps.unpin(root.item.key);
                else
                    DockApps.pin(root.item.key, -1);
                root.close();
            }
        }
        MenuRow {
            visible: root.windows.length > 0
            iconName: "close"
            label: root.windows.length > 1 ? "Close all " + root.windows.length + " windows" : "Close"
            onClicked: {
                DockApps.closeAll(root.item);
                root.close();
            }
        }
    }

    component Separator: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1 + Theme.space.xs * 2
        color: "transparent"
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - Theme.space.s * 2
            height: 1
            color: Theme.border
        }
    }
}
