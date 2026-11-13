import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

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
        target: "settings"

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
    }
}
