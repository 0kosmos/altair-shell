// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.core

// Notification daemon (org.freedesktop.Notifications) and simple history.
//
// Every notification is kept ("tracked") until the user dismisses it or the
// history grows past maxHistory; that tracked list *is* the history. Popups are
// a separate, short-lived list: a popup timing out only hides the popup.
Singleton {
    id: root

    readonly property int maxPopups: 5
    readonly property int maxHistory: 50
    readonly property int defaultTimeout: 5000   // ms, when the app doesn't say

    // Shown as popups right now, newest first.
    property list<var> popups: []

    // The history, newest first. Transient notifications never enter it.
    readonly property var history: server.trackedNotifications.values.filter(n => !n.transient).reverse()
    readonly property int count: history.length

    readonly property bool dnd: Config.notifications.doNotDisturb
    readonly property bool centerOpen: ShellState.openPanel === "notifications"

    // Arrival time (ms since epoch) by notification id, for "5 min" labels.
    property var times: ({})
    // Ticks every 30 s while the notification centre is open, to refresh labels.
    property real now: Date.now()

    // Emitted when a popup should (re)start its timeout, e.g. after the app
    // replaced the notification's content.
    signal popupShown(var notification)

    // Popup duration in ms; 0 = stay until closed.
    // NOTE: expireTimeout arrives in milliseconds (measured with notify-send),
    // although the Quickshell docs say seconds. -1 = server default, 0 = never.
    function timeoutFor(n): int {
        if (!n || n.urgency === NotificationUrgency.Critical || n.expireTimeout === 0)
            return 0;
        return n.expireTimeout > 0 ? n.expireTimeout : defaultTimeout;
    }

    function show(n): void {
        if (centerOpen)
            return;  // the open centre already lists it
        if (dnd && n.urgency !== NotificationUrgency.Critical)
            return;
        // Too many: the oldest popups simply leave the screen (still in history).
        popups = [n, ...popups.filter(p => p && p !== n)].slice(0, maxPopups);
        popupShown(n);
    }

    // Popup timed out or was clicked away; the notification stays in history.
    function hidePopup(n): void {
        popups = popups.filter(p => p && p !== n);
        if (n && n.transient)
            n.expire();
    }

    // Remove for good (the app is told the user closed it).
    function dismiss(n): void {
        popups = popups.filter(p => p && p !== n);
        if (n)
            n.dismiss();
    }

    function clearAll(): void {
        popups = [];
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
    }

    // Click on a notification: run its default action if it has one. The
    // server closes it afterwards unless the app marked it resident.
    function invokeDefault(n): bool {
        const action = n?.actions.find(a => a.identifier === "default");
        if (!action)
            return false;
        action.invoke();
        return true;
    }

    function stamp(n): void {
        const t = Object.assign({}, times);
        t[n.id] = Date.now();
        times = t;
    }

    // "now", "5 min", "3 h", or a date for older ones.
    function ago(n): string {
        const t = times[n?.id];
        if (!t)
            return "";
        const s = Math.max(0, (now - t) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + " min";
        if (s < 86400)
            return Math.floor(s / 3600) + " h";
        return Qt.locale().toString(new Date(t), Locale.ShortFormat);
    }

    // Keep supported markup (b, i, u) for Text.StyledText, but drop images
    // and links: StyledText would otherwise fetch <img> URLs (tracking pixels).
    function sanitize(body: string): string {
        return body
            .replace(/<img\b[^>]*>/gi, "")
            .replace(/<\/?a\b[^>]*>/gi, "")
            .replace(/\n/g, "<br>");
    }

    onCenterOpenChanged: {
        if (centerOpen) {
            popups = [];
            now = Date.now();
        }
    }

    Timer {
        running: root.centerOpen
        interval: 30000
        repeat: true
        onTriggered: root.now = Date.now()
    }

    NotificationServer {
        id: server

        keepOnReload: true          // survive QML hot reloads
        persistenceSupported: true  // we keep notifications after the popup
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true;
            root.stamp(n);
            n.closed.connect(() => root.popups = root.popups.filter(p => p && p !== n));

            // Notifications carried over from before a reload were shown already.
            if (!n.lastGeneration) {
                root.show(n);
                // Apps can replace a notification's content (same id): show it again.
                const refresh = () => {
                    root.stamp(n);
                    root.show(n);
                };
                n.summaryChanged.connect(refresh);
                n.bodyChanged.connect(refresh);
            }

            // Cap the history: drop the oldest.
            const tracked = server.trackedNotifications.values;
            for (let i = 0; i < tracked.length - root.maxHistory; i++)
                tracked[i].dismiss();
        }
    }
}
