// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.core
import qs.services

// All IPC entry points in one place. Hyprland keybinds call these, e.g.
//   qs -c altair ipc call panels toggle launcher
// List everything with:  qs -c altair ipc show
// Note: IPC functions need explicit argument and return types or they are not exposed.
Scope {
    IpcHandler {
        target: "panels"

        function toggle(name: string): void {
            ShellState.toggle(name);
        }
        function open(name: string): void {
            ShellState.open(name);
        }
        function close(): void {
            ShellState.close();
        }
        // Name of the open panel, empty if none.
        function current(): string {
            return ShellState.openPanel;
        }
    }

    IpcHandler {
        target: "shell"

        function ping(): string {
            return "altair " + ShellState.version;
        }
        function reloadConfig(): void {
            Config.reload();
        }
        function configPath(): string {
            return Config.path;
        }
    }

    IpcHandler {
        target: "notifications"

        function clearAll(): void {
            Notifs.clearAll();
        }
        function toggleDnd(): bool {
            Config.notifications.doNotDisturb = !Config.notifications.doNotDisturb;
            return Config.notifications.doNotDisturb;
        }
        function count(): int {
            return Notifs.count;
        }
    }

    IpcHandler {
        target: "wallpaper"

        // Absolute path to an image; empty = back to Hyprland's own background.
        function set(path: string): void {
            Wallpapers.set(path);
        }
        function current(): string {
            return Wallpapers.current;
        }
        function setFolder(path: string): void {
            Config.wallpaper.folder = path;
        }
    }

    IpcHandler {
        target: "settings"

        // Settings window back to its default size, centred.
        function recenter(): void {
            Hypr.resetWindowByTitle("Altair Settings", 1120, 700);
        }

        // "#RRGGBB", or "mono" for the theme-adaptive monochrome accent.
        function setAccent(value: string): void {
            Config.appearance.accent = value;
        }
        function setTheme(value: string): void {
            Config.appearance.theme = value;
        }
        function toggleLowPower(): bool {
            Config.performance.lowPower = !Config.performance.lowPower;
            return Config.performance.lowPower;
        }
        function setBlur(enabled: bool): void {
            Config.effects.blur = enabled;
        }
        // 1–10, or -1 for Hyprland's own setting.
        function setBlurStrength(value: int): void {
            Config.effects.blurStrength = value < 1 ? -1 : Math.min(10, value);
        }
        function setLiquidGlass(enabled: bool): void {
            Config.effects.liquidGlass = enabled;
        }
        function setAnimations(enabled: bool): void {
            Config.effects.animations = enabled;
        }
        function setBarPosition(position: string): void {
            Config.appearance.barPosition = position === "bottom" ? "bottom" : "top";
        }
    }

    IpcHandler {
        target: "widgets"

        // Desktop widgets' edit mode (SUPER + D).
        function toggleEdit(): bool {
            Widgets.editing = !Widgets.editing;
            return Widgets.editing;
        }
        function edit(on: bool): void {
            Widgets.editing = on;
        }
        function count(): int {
            return Widgets.items.length;
        }
    }

    IpcHandler {
        target: "recorder"

        // Start/stop recording the focused monitor (60 fps). Returns whether
        // it is recording afterwards.
        function toggle(): bool {
            Recorder.toggle();
            return !Recorder.recording;
        }
        function recording(): bool {
            return Recorder.recording;
        }
    }

    IpcHandler {
        target: "dock"

        // Show/hide the dock (Settings > Dock > Show dock). Returns the new state.
        function toggle(): bool {
            Config.dock.enabled = !Config.dock.enabled;
            return Config.dock.enabled;
        }
        // Pin an app (desktop id, e.g. "firefox") at a position (-1 = end).
        function pin(id: string, at: int): void {
            DockApps.pin(id, at);
        }
        function unpin(id: string): void {
            DockApps.unpin(id);
        }
        // Show an auto-hidden dock for two seconds.
        function peek(): void {
            DockApps.peek();
        }
        // Apps in the dock, one per line: key, pinned, window count, focused.
        function list(): string {
            return DockApps.items.map(i => i.key + (i.pinned ? " pinned" : "") + " " + i.windows.length + (i.windows.indexOf(Hyprland.activeToplevel) !== -1 ? " focused" : "")).join("\n") + "\nactive: " + (Hyprland.activeToplevel?.address ?? "none");
        }
    }
}
