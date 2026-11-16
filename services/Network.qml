// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
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

    // ---- For the network menu (connections/NetworkPanel.qml) -------------------

    // The Wi-Fi card, connected or not (null if there is none).
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardware: Networking.wifiHardwareEnabled
    function setWifi(on: bool): void {
        Networking.wifiEnabled = on;
    }

    // Scanning for Wi-Fi networks: only while the menu is open (users > 0).
    property int scanUsers: 0
    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.scanUsers > 0 && root.wifiEnabled
        when: root.wifiDevice !== null
    }

    // Visible networks: connected first, then saved ones, then by signal.
    // Hidden networks (no name) are left out.
    readonly property var wifiNetworks: {
        if (!wifiDevice || !wifiEnabled)
            return [];
        const l = wifiDevice.networks.values.filter(n => n.name !== "");
        return l.sort((a, b) => (b.connected - a.connected) || (b.known - a.known)
                                || ((b.signalStrength ?? 0) - (a.signalStrength ?? 0)));
    }
    function signalOf(n: var): real {
        const s = n?.signalStrength ?? 0;
        return s > 1 ? s / 100 : s;
    }
    function wifiIcon(s: real): string {
        return s > 0.75 ? "signal_wifi_4_bar" : s > 0.5 ? "network_wifi_3_bar"
            : s > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }
    function secured(n: var): bool {
        const t = n?.security;
        return t !== undefined && t !== WifiSecurityType.Open && t !== WifiSecurityType.Unknown;
    }

    // A failed connection attempt, in words.
    function failText(reason: int): string {
        if (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout
                || reason === ConnectionFailReason.WifiClientFailed)
            return "Could not connect. Wrong password?";
        if (reason === ConnectionFailReason.WifiNetworkLost)
            return "The network went out of range.";
        return "Could not connect.";
    }

    // The active device (wired before Wi-Fi), for the details.
    readonly property var activeDevice: wired ?? wifi
    readonly property string linkSpeed: {
        const s = wired?.linkSpeed ?? 0;
        return s <= 0 ? "" : s >= 1000 ? (s / 1000) + " Gbit/s" : s + " Mbit/s";
    }

    // IP address, gateway, DNS and MAC: not in Quickshell's API, so read once
    // from nmcli when the menu opens (refreshDetails()), never polled.
    property var details: ({})
    function refreshDetails(): void {
        if (!activeDevice)
            return;
        detailsProc.command = ["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,GENERAL.HWADDR", "device", "show", activeDevice.name];
        detailsProc.running = true;
    }
    Process {
        id: detailsProc
        stdout: StdioCollector {
            onStreamFinished: {
                const d = { ip: "", gateway: "", dns: [], ip6: "", mac: "" };
                for (const line of text.split("\n")) {
                    const i = line.indexOf(":");
                    if (i < 0)
                        continue;
                    const k = line.slice(0, i), v = line.slice(i + 1).replace(/\\:/g, ":");
                    if (k.startsWith("IP4.ADDRESS") && !d.ip) d.ip = v;
                    else if (k === "IP4.GATEWAY") d.gateway = v;
                    else if (k.startsWith("IP4.DNS")) d.dns.push(v);
                    else if (k.startsWith("IP6.ADDRESS") && !d.ip6 && !v.startsWith("fe80")) d.ip6 = v;
                    else if (k === "GENERAL.HWADDR") d.mac = v;
                }
                root.details = d;
            }
        }
    }

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
