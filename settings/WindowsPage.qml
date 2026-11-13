// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.services
import qs.theme

// Settings that change how Hyprland treats all windows. They are applied at
// runtime (hyprctl eval); hyprland.lua is never edited, and switching back
// restores your own values.
Page {
    title: "Windows"

    SettingRow {
        title: "Borders"
        description: Hypr.borderMode === "accent" ? "The focused window gets the accent colour, others a soft grey."
            : Hypr.borderMode === "none" ? "No visible borders around windows."
            : "The colours from your Hyprland config."
        Segmented {
            options: [{ label: "Accent", value: "accent" }, { label: "Hyprland", value: "hyprland" }, { label: "None", value: "none" }]
            current: Hypr.borderMode
            onSelected: value => Config.appearance.windowBorders = value
        }
    }

    SettingRow {
        title: "Resize by dragging edges"
        description: "Drag a window's edge or corner to resize it, like on Windows. Works for floating and tiled windows. (SUPER + right mouse button drag always works too.)"
        Toggle {
            checked: Config.windows.resizeOnBorder
            onToggled: value => Config.windows.resizeOnBorder = value
        }
    }

    SettingRow {
        title: "Smooth resizing and dragging"
        description: "Windows glide after the mouse when you resize or drag them, with a calm curve (no bounce). Also used when tiled windows make room for each other. Off: instant, as in your Hyprland config."
        Toggle {
            checked: Config.windows.smoothResize
            onToggled: value => Config.windows.smoothResize = value
        }
    }
}
