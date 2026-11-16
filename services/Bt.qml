// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth (BlueZ) via Quickshell.Bluetooth. Named Bt because "Bluetooth"
// is Quickshell's own type. Needs the bluetooth service (bluetoothd) and an
// adapter; without them `available` is false and the bar shows no button.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool blocked: adapter?.state === BluetoothAdapterState.Blocked
    function setEnabled(on: bool): void {
        if (adapter)
            adapter.enabled = on;
    }

    readonly property var devices: adapter ? adapter.devices.values : []
    // Paired devices, connected ones first.
    readonly property var paired: devices.filter(d => d.paired || d.bonded)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // Found by a scan, not paired yet (nameless ones are mostly beacons).
    readonly property var found: devices.filter(d => !d.paired && !d.bonded && d.deviceName !== "")
    readonly property var connected: devices.filter(d => d.connected)

    // Scanning (discovery) only while the menu is open (users > 0).
    property int scanUsers: 0
    Binding {
        target: root.adapter
        property: "discovering"
        value: root.scanUsers > 0 && root.enabled
        when: root.adapter !== null && root.enabled
    }

    readonly property string icon: !enabled ? "bluetooth_disabled"
        : connected.length > 0 ? "bluetooth_connected" : "bluetooth"

    // Material Symbols icon for a device (BlueZ icon names).
    function deviceIcon(d: var): string {
        const i = d?.icon ?? "";
        if (i.startsWith("audio-headset") || i.startsWith("audio-headphones")) return "headphones";
        if (i.startsWith("audio")) return "speaker";
        if (i === "input-mouse") return "mouse";
        if (i === "input-keyboard") return "keyboard";
        if (i === "input-gaming") return "sports_esports";
        if (i === "input-tablet") return "stylus";
        if (i.startsWith("phone")) return "smartphone";
        if (i === "computer") return "computer";
        if (i.startsWith("camera")) return "photo_camera";
        if (i === "printer") return "print";
        return "bluetooth";
    }

    // Pair, then trust (so it reconnects by itself) and connect.
    function pairAndConnect(d: var): void {
        pending = d;
        d.pair();
    }
    property var pending: null
    Connections {
        target: root.pending
        function onPairedChanged(): void {
            const d = root.pending;
            if (d && d.paired) {
                d.trusted = true;
                d.connect();
                root.pending = null;
            }
        }
    }
}
