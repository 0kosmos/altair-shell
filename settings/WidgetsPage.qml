// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.services
import qs.theme

// Desktop widgets: entry point to edit mode.
Page {
    title: "Widgets"

    SettingRow {
        title: "Edit widgets"
        description: (Widgets.items.length === 0 ? "No widgets on your desktop yet. "
                : Widgets.items.length + (Widgets.items.length === 1 ? " widget" : " widgets") + " on your desktop. ")
            + "In edit mode: add widgets from the dock at the bottom, drag to move (Shift: no snapping), drag the corner to resize, click a widget for its opacity slider and remove button. SUPER + D or Escape to leave."
        PillButton {
            text: "Edit"
            onClicked: {
                // Settings would sit under the edit layer: close it first.
                ShellState.settingsOpen = false;
                Widgets.editing = true;
            }
        }
    }
}
