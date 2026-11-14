// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.core

// CPU and memory use (from /proc, every 2 s) and optionally the GPU
// temperature (nvidia-smi, every 5 s). Reads ONLY while something shows them
// (`users` > 0: widgets register themselves) and not while the focused
// workspace has a fullscreen window over the desktop. No users = no timers.
Singleton {
    id: root

    property int users: 0
    readonly property bool paused: Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false
    readonly property bool active: users > 0 && !paused
    readonly property bool gpuWanted: Config.ready && Config.widgets.gpuTemp

    property real cpu: 0                 // 0–1
    property real memUsed: 0             // bytes
    property real memTotal: 0
    property int gpuTemp: -1             // °C, -1 = unknown / off

    property var lastCpu: null           // { total, idle }

    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: root.active
        onTriggered: root.read()
    }

    function read(): void {
        stat.reload();
        const line = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        // user nice system idle iowait irq softirq steal
        const idle = (line[3] || 0) + (line[4] || 0);
        const total = line.slice(0, 8).reduce((a, b) => a + (b || 0), 0);
        if (lastCpu && total > lastCpu.total)
            cpu = 1 - (idle - lastCpu.idle) / (total - lastCpu.total);
        lastCpu = { total, idle };

        meminfo.reload();
        const kb = key => {
            const m = meminfo.text().match(new RegExp("^" + key + ":\\s+(\\d+)", "m"));
            return m ? Number(m[1]) * 1024 : 0;
        };
        memTotal = kb("MemTotal");
        memUsed = memTotal - kb("MemAvailable");
    }

    FileView {
        id: stat
        path: "/proc/stat"
        blockLoading: true
    }
    FileView {
        id: meminfo
        path: "/proc/meminfo"
        blockLoading: true
    }

    // GPU temperature: NVIDIA only (nvidia-smi), off by default.
    Timer {
        interval: 5000
        repeat: true
        triggeredOnStart: true
        running: root.active && root.gpuWanted
        onTriggered: if (!smi.running) smi.running = true
    }
    onGpuWantedChanged: if (!gpuWanted) gpuTemp = -1
    Process {
        id: smi
        command: ["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = parseInt(this.text.trim());
                root.gpuTemp = isNaN(t) ? -1 : t;
            }
        }
        onExited: code => { if (code !== 0) root.gpuTemp = -1; }
    }
}
