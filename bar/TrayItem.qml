// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.theme

// One tray icon. Left click activates the app (or opens its menu if that's all
// it offers), right click opens the menu, middle click is secondary activate,
// scroll is forwarded to the app.
BarButton {
    id: root

    required property SystemTrayItem item

    padding: Theme.space.xs + 2

    function openMenu(): void {
        if (item.hasMenu)
            menuLoader.active = true;
    }

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            if (item.onlyMenu)
                openMenu();
            else
                item.activate();
        } else if (mouse.button === Qt.RightButton) {
            openMenu();
        } else {
            item.secondaryActivate();
        }
    }
    onStepped: dir => item.scroll(dir, false)

    IconImage {
        source: root.item.icon
        implicitSize: Theme.font.icon
    }

    // The menu window only exists while it is open.
    LazyLoader {
        id: menuLoader
        active: false

        TrayMenu {
            handle: root.item.menu
            anchorItem: root
            onDismissed: menuLoader.active = false
        }
    }
}
