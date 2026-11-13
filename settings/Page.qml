// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

// Base for a settings page: a scrollable column with a title. Put SettingRows,
// Sections, etc. inside as children.
Flickable {
    id: root

    property string title
    default property alias content: column.data

    // Double-click on an empty part of the page (the window re-centres).
    signal backgroundDoubleClicked()

    // Smooth keyboard scrolling (the window calls these for arrows, PageUp/
    // PageDown, Home/End). Repeated calls retarget the running animation, so
    // holding a key glides instead of jumping.
    readonly property real maxY: Math.max(0, contentHeight - height)
    function scrollBy(dy: real): void {
        const from = scroller.running ? scroller.to : contentY;
        scrollTo(from + dy);
    }
    // At the top (direction -1) or bottom (+1), counting a scroll that is
    // already gliding there. A page that fits is at both ends.
    function atEnd(direction: int): bool {
        const y = scroller.running ? scroller.to : contentY;
        return direction > 0 ? y >= maxY - 1 : y <= 1;
    }

    function scrollTo(y: real): void {
        scroller.stop();
        scroller.to = Math.max(0, Math.min(maxY, y));
        scroller.start();
    }
    NumberAnimation {
        id: scroller
        target: root
        property: "contentY"
        duration: Theme.anim.normal
        easing.type: Theme.anim.easing
    }

    contentHeight: column.implicitHeight + Theme.space.xl * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Behind the page's content: catches double-clicks that no control took.
    // (Parented explicitly: children of a Page otherwise go into the column.)
    MouseArea {
        parent: root.contentItem
        z: -1
        width: root.width
        height: Math.max(root.contentHeight, root.height)
        onDoubleClicked: root.backgroundDoubleClicked()
    }

    ColumnLayout {
        id: column
        x: Theme.space.xl
        y: Theme.space.xl
        width: root.width - Theme.space.xl * 2
        spacing: Theme.space.l

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.space.xs
            text: root.title
            font.pixelSize: Theme.font.title + 4
            font.weight: Font.DemiBold
        }
    }
}
