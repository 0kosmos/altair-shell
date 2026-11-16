// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.services
import qs.theme

// The lock screen's password field. It never shows text: one mark per typed
// character, animated in the style chosen in Settings > Lock screen
// (lock.typing): "pop" | "wave" | "glow" | "shapes" | "bars" | "minimal".
// The marks follow Locker.buffer's length, so typing, deleting, clearing and
// a rejected password all animate the same way. Wrong password: the field
// shakes and the marks turn red as they go; right password: they turn the
// accent colour and the field shows a tick.
Item {
    id: root

    property string style: "pop"
    readonly property bool animated: Theme.animations && style !== "minimal"
    // Bound to the lock by default; Settings' preview sets live: false and
    // drives count/status itself.
    property bool live: true
    property int count: Locker.buffer.length
    property string status: Locker.status
    readonly property bool failed: status === "failed" || status === "error"
    readonly property color markColor: status === "success" ? Theme.accent : failed ? Theme.critical : Theme.fg

    implicitWidth: 320
    implicitHeight: 54

    // ---- Keep one model row per character ----------------------------------------------
    ListModel { id: marks }
    property int serial: 0
    onCountChanged: sync()
    Component.onCompleted: sync()
    function sync(): void {
        while (marks.count < count) {
            // A random seed per mark: shape, bar height, a little variety.
            marks.append({ seed: Math.random(), n: serial++ });
            if (style === "wave")
                wave.started();
            if (style === "glow")
                glowPulse.restart();
        }
        if (marks.count > count)
            marks.remove(count, marks.count - count);
    }

    // ---- Field -----------------------------------------------------------------------
    Item {
        id: field
        width: parent.width
        height: parent.height
        transform: Translate { id: shakeX }

        Rectangle {
            anchors.fill: parent
            radius: Theme.pill(height)
            color: Qt.alpha(Theme.fg, root.activeFocus || root.count > 0 ? 0.10 : 0.07)
            border.width: 1
            border.color: root.failed ? Qt.alpha(Theme.critical, 0.7)
                : root.status === "success" ? Theme.accent
                : Qt.alpha(Theme.fg, 0.16)
            Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
            Behavior on border.color { ColorAnimation { duration: Theme.anim.fast } }
        }

        // "glow": a soft accent ring that flares on every keystroke.
        Rectangle {
            id: glowRing
            anchors.fill: parent
            anchors.margins: -3
            radius: Theme.pill(height)
            color: "transparent"
            border.width: 3
            border.color: Qt.alpha(Theme.accent, 0.55)
            opacity: 0
            visible: root.style === "glow"
            NumberAnimation on opacity {
                id: glowPulse
                running: false
                from: 1; to: 0
                duration: 520
                easing.type: Easing.OutCubic
            }
        }

        // Placeholder / second question / "checking".
        StyledText {
            anchors.centerIn: parent
            width: parent.width - 48
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.status === "prompt" ? Locker.prompt
                : root.status === "checking" ? ""
                : root.status === "success" ? ""
                : "Enter password"
            color: Theme.fgDisabled
            font.pixelSize: Theme.font.body
            opacity: root.count === 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.anim.fast } }
        }

        Icon {
            anchors.centerIn: parent
            name: "check"
            size: 26
            color: Theme.accent
            opacity: root.status === "success" ? 1 : 0
            scale: root.status === "success" ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: Theme.anim.normal } }
            Behavior on scale { NumberAnimation { duration: Theme.anim.normal; easing.type: Easing.OutBack } }
        }

        // ---- Marks ---------------------------------------------------------------------
        ListView {
            id: list
            anchors.centerIn: parent
            width: Math.min(contentWidth, parent.width - 40)
            height: parent.height
            orientation: ListView.Horizontal
            interactive: false
            spacing: root.style === "bars" ? 4 : 7
            clip: contentWidth > parent.width - 40
            model: marks
            onCountChanged: positionViewAtEnd()
            // Checking: the marks breathe until PAM answers.
            opacity: root.status === "checking" ? breath.value : 1
            QtObject {
                id: breath
                property real value: 1
                SequentialAnimation on value {
                    running: root.status === "checking" && Theme.animations
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 420; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 420; easing.type: Easing.InOutSine }
                    onRunningChanged: if (!running) breath.value = 1
                }
            }

            delegate: Item {
                id: mark
                required property int index
                required property real seed
                width: root.style === "bars" ? 4 : root.style === "shapes" ? 15 : 12
                height: list.height

                Item {
                    id: body
                    anchors.centerIn: parent
                    width: parent.width
                    height: root.style === "bars" ? 10 + mark.seed * 16 : 12
                    transform: Translate { id: lift }

                    // pop / wave / glow / bars / minimal: a dot (or a bar).
                    // shapes: one of six drawn shapes (no icon font: its
                    // filled glyphs show seams at this size).
                    readonly property int shape: root.style === "shapes" ? Math.floor(mark.seed * 6) : 0
                    Rectangle {
                        anchors.centerIn: parent
                        // 0 dot, 1 rounded square, 2 diamond, 3 ring, 4 tall pill, 5 wide pill
                        readonly property size dims: root.style !== "shapes" ? Qt.size(parent.width, parent.height)
                            : [Qt.size(12, 12), Qt.size(11, 11), Qt.size(10, 10), Qt.size(12, 12), Qt.size(6, 14), Qt.size(15, 7)][body.shape]
                        width: dims.width
                        height: dims.height
                        radius: root.style === "bars" ? 2 : body.shape === 1 ? 3 : body.shape === 2 ? 2 : Math.min(width, height) / 2
                        rotation: body.shape === 2 ? 45 : 0
                        color: body.shape === 3 ? "transparent" : root.markColor
                        border.width: body.shape === 3 ? 2.5 : 0
                        border.color: root.markColor
                        Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
                        // "glow": a soft halo behind each dot.
                        Rectangle {
                            visible: root.style === "glow"
                            anchors.centerIn: parent
                            width: 20; height: 20; radius: 10
                            z: -1
                            color: Qt.alpha(root.status === "idle" ? Theme.accent : root.markColor, 0.28)
                        }
                    }
                }

                // "wave": every mark hops, the newest first, like a ripple.
                Connections {
                    target: wave
                    enabled: root.style === "wave" && root.animated
                    function onStarted() {
                        hop.delay = Math.max(0, list.count - 1 - mark.index) * 28;
                        hop.restart();
                    }
                }
                SequentialAnimation {
                    id: hop
                    property int delay: 0
                    PauseAnimation { duration: hop.delay }
                    NumberAnimation { target: lift; property: "y"; to: -7; duration: 110; easing.type: Easing.OutQuad }
                    NumberAnimation { target: lift; property: "y"; to: 0; duration: 260; easing.type: Easing.OutBounce }
                }
            }

            // Entering / leaving / gliding aside, per style.
            add: Transition {
                enabled: root.animated
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: root.style === "glow" ? 280 : 160 }
                    NumberAnimation {
                        property: "scale"
                        from: root.style === "glow" ? 1.8 : 0
                        to: 1
                        duration: root.style === "glow" ? 360 : 300
                        easing.type: root.style === "glow" ? Easing.OutCubic : Easing.OutBack
                        easing.overshoot: 2.2
                    }
                    NumberAnimation {
                        property: "rotation"
                        from: root.style === "shapes" ? -160 : 0
                        to: 0
                        duration: 380
                        easing.type: Easing.OutBack
                    }
                    NumberAnimation {
                        property: "y"
                        from: root.style === "bars" ? 18 : 0
                        to: 0
                        duration: 260
                        easing.type: Easing.OutBack
                    }
                }
            }
            remove: Transition {
                enabled: root.animated
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: root.failed ? 380 : 160 }
                    NumberAnimation { property: "scale"; to: root.failed ? 0.6 : 0; duration: root.failed ? 380 : 180; easing.type: Easing.InBack }
                    // A rejected password: the marks drop away.
                    NumberAnimation { property: "y"; to: root.failed ? 26 : 0; duration: 380; easing.type: Easing.InQuad }
                }
            }
            displaced: Transition {
                enabled: root.animated
                NumberAnimation { properties: "x"; duration: 200; easing.type: Easing.OutCubic }
            }
        }
    }

    // Fired for every new mark in the "wave" style (each mark listens).
    QtObject { id: wave; signal started() }

    // ---- Wrong password: shake -----------------------------------------------------------
    function shakeNow(): void {
        if (Theme.animations)
            shake.restart();
    }
    Connections {
        target: Locker
        enabled: root.live
        function onRejected() {
            if (Theme.animations)
                shake.restart();
        }
    }
    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeX; property: "x"; to: -14; duration: 60; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeX; property: "x"; to: 11; duration: 80; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeX; property: "x"; to: -7; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeX; property: "x"; to: 4; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60; easing.type: Easing.OutQuad }
    }
}
