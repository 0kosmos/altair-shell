// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell

// Opening folders and files from the shell.
// Folders go to the file manager through the org.freedesktop.FileManager1
// D-Bus interface (Dolphin, Nautilus, Thunar, Nemo… implement it), not
// `xdg-open`: on a plain Hyprland setup the default "folder" app is often a
// terminal (kitty registers kitty-open.desktop for inode/directory).
// Everything is started through Hyprland (like apps from the launcher), so
// it gets Hyprland's environment and focus, not the shell's.
Singleton {
    id: root

    readonly property string fallbackManagers: "dolphin nautilus thunar nemo pcmanfm-qt pcmanfm caja"

    function uri(path: string): string {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    // Open a folder in the file manager.
    function showFolder(path: string): void {
        run("ShowFolders", path, path);
    }

    // Open the folder that holds `path`, with that file selected.
    function showItem(path: string): void {
        run("ShowItems", path, path.slice(0, path.lastIndexOf("/")) || "/");
    }

    // Open a file with its default app (videos in the video player, …).
    function open(path: string): void {
        Hypr.exec(["xdg-open", path], "");
    }

    // FileManager1 first; else the first file manager installed; else xdg-open.
    function run(method: string, path: string, folder: string): void {
        const script = 'busctl --user call org.freedesktop.FileManager1 /org/freedesktop/FileManager1 '
            + 'org.freedesktop.FileManager1 "$1" ass 1 "$2" "" >/dev/null 2>&1 && exit 0; '
            + 'for fm in ' + fallbackManagers + '; do command -v "$fm" >/dev/null && exec "$fm" "$3"; done; '
            + 'exec xdg-open "$3"';
        Hypr.exec(["sh", "-c", script, "sh", method, uri(path), folder], "");
    }
}
