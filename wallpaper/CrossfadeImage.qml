// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import qs.services
import qs.theme

// Two image slots: a new picture loads into the hidden slot, fades in over
// the visible one, then the old slot is emptied to free its memory.
Item {
    id: fader

    property string path
    property int duration: 600
    property Image front: null

    onPathChanged: show()
    Component.onCompleted: show()

    function show(): void {
        if (!path || (front && front.path === path))
            return;
        const next = front === slotA ? slotB : slotA;
        next.opacity = 0;
        next.z = 1;
        if (front)
            front.z = 0;
        next.path = path;   // starts loading; fades in when ready
    }

    Slot { id: slotA }
    Slot { id: slotB }

    component Slot: Image {
        id: img

        property string path: ""

        anchors.fill: parent
        source: Wallpapers.url(path)
        sourceSize: Qt.size(fader.width * Screen.devicePixelRatio, fader.height * Screen.devicePixelRatio)
        fillMode: Wallpapers.fill === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        asynchronous: true
        cache: false        // no second copy in Qt's pixmap cache
        smooth: true
        opacity: 0

        onStatusChanged: {
            if (status === Image.Ready && path !== "" && fader.front !== img)
                fadeIn.restart();
            else if (status === Image.Error && path !== "")
                console.warn("altair: cannot load wallpaper " + path);
        }

        NumberAnimation {
            id: fadeIn
            target: img
            property: "opacity"
            to: 1
            duration: Theme.animations ? fader.duration : 0
            easing.type: Easing.InOutQuad
            onFinished: {
                const old = fader.front;
                fader.front = img;
                // Drop the previous image so only one is held in memory.
                if (old && old !== img) {
                    old.path = "";
                    old.opacity = 0;
                }
            }
        }
    }
}
