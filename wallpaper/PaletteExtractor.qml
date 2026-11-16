// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.services

// Reads a wallpaper's colours for WallpaperTheme (auto themes): draws the
// picture into a 48x27 Canvas and hands the pixels over. Invisible (opacity
// 0), lives in the wallpaper window; it only paints when asked.
Canvas {
    id: root

    width: 48
    height: 27
    opacity: 0
    renderStrategy: Canvas.Immediate

    property string path: ""
    property var callback: null

    Component.onCompleted: WallpaperTheme.extractor = root
    Component.onDestruction: if (WallpaperTheme.extractor === root) WallpaperTheme.extractor = null

    function extract(file: string, cb): void {
        if (!file) {
            cb(null);
            return;
        }
        if (path)
            unloadImage(Wallpapers.url(path));
        path = file;
        callback = cb;
        const u = Wallpapers.url(file);
        if (isImageLoaded(u))
            requestPaint();
        else
            loadImage(u);
    }
    onImageLoaded: requestPaint()

    onPaint: {
        if (!path || !callback)
            return;
        const u = Wallpapers.url(path);
        if (!isImageLoaded(u)) {
            if (isImageError(u)) {
                const cb = callback;
                callback = null;
                cb(null);
            }
            return;
        }
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        ctx.drawImage(u, 0, 0, width, height);
        const data = ctx.getImageData(0, 0, width, height).data;
        const colors = WallpaperTheme.colors(data);
        // Free the full-size picture again.
        unloadImage(u);
        path = "";
        const cb = callback;
        callback = null;
        cb(colors);
    }
}
