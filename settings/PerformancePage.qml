// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.components
import qs.core
import qs.theme

// Low-power switch and a live readout of the shell's own CPU and memory use.
// The readout reads /proc/self every 2 s, only while this page is shown.
Page {
    id: page
    title: "Performance"

    SettingRow {
        title: "Low-power mode"
        description: "Turns off blur, liquid glass and all animations in one go."
        Toggle {
            checked: Config.performance.lowPower
            onToggled: value => Config.performance.lowPower = value
        }
    }

    Section { text: "Altair right now" }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space.m

        Stat { label: "CPU"; value: page.cpu < 0 ? "…" : page.cpu.toFixed(1) + " %" }
        Stat { label: "Memory (PSS)"; value: page.pssMiB < 0 ? "…" : page.pssMiB.toFixed(0) + " MiB" }
    }

    StyledText {
        Layout.fillWidth: true
        text: "CPU is the share of one core, averaged over 2 s. PSS counts shared libraries fairly. For longer measurements run scripts/perf.sh from the repository."
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
        wrapMode: Text.Wrap
    }

    // ---- Sampling -------------------------------------------------------------
    property real cpu: -1
    property real pssMiB: -1
    property real lastTicks: -1
    property real lastTime: 0

    FileView { id: stat; path: "/proc/self/stat"; blockLoading: true }
    FileView { id: rollup; path: "/proc/self/smaps_rollup"; blockLoading: true }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            rollup.reload();
            // Fields after "(comm) ": utime and stime are the 12th and 13th.
            const t = stat.text();
            const f = t.slice(t.lastIndexOf(")") + 2).split(" ");
            const ticks = Number(f[11]) + Number(f[12]);
            const now = Date.now();
            // Linux reports CPU time in 1/100 s (USER_HZ).
            if (page.lastTicks >= 0)
                page.cpu = (ticks - page.lastTicks) / 100 / ((now - page.lastTime) / 1000) * 100;
            page.lastTicks = ticks;
            page.lastTime = now;

            const m = rollup.text().match(/^Pss:\s+(\d+)/m);
            if (m)
                page.pssMiB = Number(m[1]) / 1024;
        }
    }

    component Stat: Rectangle {
        id: statCard
        property string label
        property string value

        Layout.fillWidth: true
        implicitHeight: 72
        radius: Theme.radius.m
        color: Theme.surfaceRaised
        border.width: 1
        border.color: Theme.border

        Column {
            anchors.left: parent.left
            anchors.leftMargin: Theme.space.l
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                text: statCard.label
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
            }
            StyledText {
                text: statCard.value
                font.pixelSize: Theme.font.title + 4
                font.weight: Font.DemiBold
                tabular: true
            }
        }
    }
}
