// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Laptop battery state from UPower. `present` is false on desktops, and the bar
// hides the battery indicator then.
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: device !== null && device.isPresent && device.isLaptopBattery

    // 0.0 – 1.0. Normalised defensively in case it is reported as 0 – 100.
    readonly property real level: {
        const p = device?.percentage ?? 0;
        return p > 1 ? p / 100 : p;
    }

    readonly property bool charging: present && (device.state === UPowerDeviceState.Charging
        || device.state === UPowerDeviceState.FullyCharged || !UPower.onBattery)
    readonly property bool low: present && !charging && level < 0.15

    readonly property string icon: {
        if (charging)
            return "battery_charging_full";
        if (low)
            return "battery_alert";
        if (level >= 0.95)
            return "battery_full";
        // battery_0_bar … battery_6_bar
        return "battery_" + Math.max(0, Math.min(6, Math.round(level * 6))) + "_bar";
    }
}
