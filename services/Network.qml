// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Current network connection, from NetworkManager via Quickshell.Networking.
// Note: the Networking backend connects lazily on first access, so values
// appear a moment after startup; everything here is a binding and updates then.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values

    // Prefer a connected wired device, then a connected Wi-Fi device.
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi && d.connected) ?? null
    readonly property var wifiNetwork: wifi ? (wifi.networks.values.find(n => n.connected) ?? null) : null

    readonly property string kind: wired ? "wired" : wifi ? "wifi" : "none"
    readonly property string name: wired ? "Wired" : (wifiNetwork?.name ?? "")

    // 0.0 – 1.0. Normalised defensively in case a backend reports 0 – 100.
    readonly property real strength: {
        const s = wifiNetwork?.signalStrength ?? 0;
        return s > 1 ? s / 100 : s;
    }

    // Connected but without full internet access (captive portal, no route, ...).
    // If NetworkManager can't check connectivity, trust the link state.
    readonly property bool limited: kind !== "none" && Networking.canCheckConnectivity
        && Networking.connectivity !== NetworkConnectivity.Full
        && Networking.connectivity !== NetworkConnectivity.Unknown

    // Material Symbols icon name for the current state.
    readonly property string icon: {
        if (kind === "none")
            return "signal_disconnected";
        if (limited)
            return "public_off";
        if (kind === "wired")
            return "lan";
        if (strength > 0.75)
            return "signal_wifi_4_bar";
        if (strength > 0.5)
            return "network_wifi_3_bar";
        if (strength > 0.25)
            return "network_wifi_2_bar";
        return "network_wifi_1_bar";
    }
}
