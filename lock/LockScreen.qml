// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The session lock (ext-session-lock-v1): created only while locking, with
// one LockSurface per monitor. Hyprland keeps the screen covered until
// Locker.unlock(); if this process dies while locked, the session stays
// locked (see services/Locker.qml for how the shell takes it back).
Scope {
    id: root

    // Stays loaded until the compositor has really let go, so the lock
    // object is never destroyed while still locked.
    property bool held: false
    Connections {
        target: Locker
        function onLockedChanged() {
            if (Locker.locked)
                root.held = true;
        }
    }

    LazyLoader {
        active: Locker.locked || root.held

        WlSessionLock {
            id: lock
            locked: Locker.locked
            onSecureChanged: Locker.secure = secure
            onLockedChanged: {
                if (!locked) {
                    Locker.secure = false;
                    Qt.callLater(() => root.held = false);
                }
            }

            WlSessionLockSurface {
                color: "#000000"
                LockSurface {
                    anchors.fill: parent
                }
            }
        }
    }
}
