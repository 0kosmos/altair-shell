// Altair — entry point. Run with `qs -c altair` (or `qs -p <repo>` while developing).
import QtQuick
import Quickshell
import qs.core
import qs.theme

ShellRoot {
    Ipc {}

    // Singletons are created lazily; touching Config here makes sure the config
    // file is loaded (or created) at startup rather than on first use.
    Component.onCompleted: console.info("altair " + ShellState.version + " starting, config: " + Config.path)

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready)
                console.info("altair: config ready (valid=" + Config.valid + ", accent=" + Theme.accent + ")");
        }
    }
}
