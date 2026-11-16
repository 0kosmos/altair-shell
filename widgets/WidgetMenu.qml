// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.core
import qs.services
import qs.theme

// Right-click menu on a desktop widget: its style, the music visualizer,
// opacity (for its whole group), edit mode, detach, remove, settings.
// Its own Overlay window (the widget layer sits below the windows), at the
// pointer; clicking outside closes it.
PanelWindow {
    id: root

    required property var anchorWindow
    required property point at
    required property string itemId
    signal dismissed()

    readonly property var item: Widgets.byId(itemId)
    readonly property var type: Widgets.typeType(item?.type ?? "")
    readonly property var styles: Widgets.stylesFor(item)
    readonly property var visModes: Widgets.visModes(item)
    // The widget and everything joined to it (opacity is for all of them).
    readonly property var group: Widgets.groupOf(itemId)

    screen: anchorWindow.screen
    WlrLayershell.namespace: "altair-widget-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true
    anchors.left: true
    readonly property int menuWidth: 264
    readonly property int menuHeight: list.implicitHeight + Theme.space.xs * 2
    margins.left: at.x + menuWidth > anchorWindow.width - 8 ? Math.max(8, at.x - menuWidth) : at.x
    margins.top: at.y + menuHeight > anchorWindow.height - 8 ? Math.max(8, at.y - menuHeight) : at.y
    implicitWidth: menuWidth
    implicitHeight: menuHeight
    color: "transparent"

    // The widget was removed meanwhile (e.g. by undo): nothing to show.
    onItemChanged: if (!item) close()

    property bool closing: false
    function close(): void {
        if (closing)
            return;
        closing = true;
        background.opacity = 0;
        background.scale = 0.97;
        closeTimer.start();
    }
    Timer {
        id: closeTimer
        interval: Theme.anim.fast + 20
        onTriggered: root.dismissed()
    }
    function then(f): void {
        close();
        Qt.callLater(f);
    }

    HyprlandFocusGrab {
        active: !root.closing
        windows: [root]
        onCleared: root.close()
    }

    BackgroundEffect.blurRegion: Theme.blur ? blurShape : null
    Region {
        id: blurShape
        item: background
        radius: Theme.radius.m
    }

    GlassBackground {
        id: background
        animate: true
        anchors.fill: parent
        radius: Theme.radius.m
        solidity: Theme.blur ? 0.3 : 0.6
        opacity: 0
        scale: 0.96
        transformOrigin: Item.TopLeft
        Component.onCompleted: {
            opacity = 1;
            scale = 1;
        }
        Behavior on opacity { NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.anim.normal; easing.type: Easing.OutQuint } }
    }

    ColumnLayout {
        id: list
        focus: true
        Keys.onEscapePressed: root.close()
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space.xs
        spacing: 0
        opacity: background.opacity

        // Title.
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.space.s
            spacing: Theme.space.s
            Icon {
                name: root.type?.icon ?? "widgets"
                color: Theme.accent
            }
            StyledText {
                Layout.fillWidth: true
                text: root.type?.name ?? "Widget"
                font.weight: Font.DemiBold
            }
            StyledText {
                visible: root.group.length > 1
                text: root.group.length + " joined"
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
            }
        }

        // Style.
        Label_ { visible: root.styles.length > 1; text: "Style" }
        Repeater {
            model: root.styles.length > 1 ? root.styles : []
            MenuRow {
                required property var modelData
                Layout.fillWidth: true
                label: modelData.name
                checkable: true
                checked: Widgets.styleOf(root.item) === modelData.id
                onClicked: Widgets.update(root.itemId, { style: modelData.id })
            }
        }

        // Music: built-in visualizer.
        Label_ { visible: root.visModes.length > 1; text: "Visualizer" }
        Repeater {
            model: root.visModes.length > 1 ? root.visModes : []
            MenuRow {
                required property var modelData
                Layout.fillWidth: true
                label: Widgets.visNames[modelData] ?? modelData
                checkable: true
                checked: Widgets.visOf(root.item) === modelData
                onClicked: Widgets.update(root.itemId, { vis: modelData })
            }
        }

        // Opacity, for the whole group.
        Label_ { text: root.group.length > 1 ? "Opacity (whole group)" : "Opacity" }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.space.m
            Layout.rightMargin: Theme.space.m
            Layout.bottomMargin: Theme.space.xs
            spacing: Theme.space.s
            Slider {
                Layout.fillWidth: true
                from: 20
                to: 100
                stepSize: 5
                showTicks: false
                value: Math.round((root.item?.opacity ?? 1) * 100)
                onMoved: v => Widgets.updateMany(root.group, { opacity: v / 100 })
            }
            StyledText {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                text: Math.round((root.item?.opacity ?? 1) * 100) + "%"
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
                tabular: true
            }
        }

        Sep {}
        MenuRow {
            Layout.fillWidth: true
            iconName: "edit"
            label: "Edit widgets"
            onClicked: root.then(() => {
                Widgets.editing = true;
                Widgets.selected = root.itemId;
            })
        }
        MenuRow {
            Layout.fillWidth: true
            visible: !!root.item?.attachedTo
            iconName: "link_off"
            label: "Detach from group"
            onClicked: root.then(() => Widgets.detachRequested(root.itemId))
        }
        MenuRow {
            Layout.fillWidth: true
            iconName: "tune"
            label: "Widget settings"
            onClicked: root.then(() => ShellState.openSettings("widgets"))
        }
        Sep {}
        MenuRow {
            Layout.fillWidth: true
            iconName: "delete"
            label: "Remove widget"
            onClicked: root.then(() => Widgets.removeRequested(root.itemId))
        }
    }

    component Label_: StyledText {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.space.m
        Layout.topMargin: Theme.space.xs
        Layout.bottomMargin: 2
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
    }
    component Sep: Item {
        Layout.fillWidth: true
        implicitHeight: 1 + Theme.space.xs * 2
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - Theme.space.s * 2
            height: 1
            color: Theme.border
        }
    }
}
