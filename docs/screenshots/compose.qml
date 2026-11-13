// SPDX-License-Identifier: GPL-3.0-or-later
// Presentation image for the README: a screenshot, gently tilted, with a soft
// shadow, a title and a caption. Rendered offscreen by make.sh:
//   qml compose.qml -- <work dir> <name> <out.png> <caption>
// The work dir holds <name>-bg.png, <name>-shot.png (rounded, with alpha) and
// <name>-shadow.png, prepared by make.sh. (Rounding, shadows and blur are
// done there with vips, because Qt's shader effects don't render offscreen.)
import QtQuick
import QtQuick.Window

Window {
    id: win
    width: 1600
    height: 1000
    visible: true
    color: "#0b0d14"

    readonly property var args: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)
    readonly property string dir: args[0]
    readonly property string name: args[1]
    readonly property string out: args[2]
    readonly property string caption: args[3]

    // Screenshot size in the image, and how much bigger the shadow image is
    // (make.sh pads it by 140 px per side at 1920x1080).
    readonly property real shotW: 1160
    readonly property real shotH: shotW * 1080 / 1920
    readonly property real k: shotW / 1920
    readonly property real pad: 140 * k

    Item {
        id: canvas
        anchors.fill: parent

        Image {
            anchors.fill: parent
            source: "file://" + win.dir + "/" + win.name + "-bg.png"
        }

        Text {
            x: 104
            y: 76
            text: "Altair"
            color: "#f2f3f7"
            font.family: "Inter"
            font.pixelSize: 68
            font.weight: Font.Bold
            font.letterSpacing: -1
        }
        Text {
            x: 106
            y: 166
            text: win.caption
            color: "#a3a9bd"
            font.family: "Inter"
            font.pixelSize: 27
        }

        Item {
            id: frame
            width: win.shotW
            height: win.shotH
            x: 290
            y: 276
            transform: [
                Rotation { origin.x: frame.width / 2; origin.y: frame.height / 2; axis { x: 0; y: 1; z: 0 } angle: -8 },
                Rotation { origin.x: frame.width / 2; origin.y: frame.height / 2; axis { x: 1; y: 0; z: 0 } angle: 4 }
            ]

            Image {
                x: -win.pad
                y: -win.pad + 26
                width: win.shotW + 2 * win.pad
                height: win.shotH + 2 * win.pad
                source: "file://" + win.dir + "/" + win.name + "-shadow.png"
                smooth: true
            }
            Image {
                id: shot
                anchors.fill: parent
                source: "file://" + win.dir + "/" + win.name + "-shot.png"
                smooth: true
                mipmap: true
            }
            // A fine light edge, like Altair's own panels.
            Rectangle {
                anchors.fill: parent
                radius: 32 * win.k
                color: "transparent"
                border.width: 1.5
                border.color: Qt.rgba(1, 1, 1, 0.14)
            }
        }
    }

    Timer {
        interval: 1000
        running: shot.status === Image.Ready
        onTriggered: canvas.grabToImage(result => {
            result.saveToFile(win.out);
            Qt.quit();
        })
    }
}
