#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Turn raw 1920x1080 screenshots into the README images.
#
#   docs/screenshots/make.sh <dir with raw PNGs>
#
# Expects desktop.png, settings.png, wallpapers.png and launcher.png in that
# directory (take them with `grim` on an empty workspace, with a wallpaper
# you may publish). Writes docs/screenshots/<name>.png.
# Needs: vips (libvips), python3, qml (qt6-declarative); Inter font.
set -euo pipefail

RAW="$(cd "${1:?usage: make.sh <dir with raw screenshots>}" && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT

v() { vips "$@" 2>/dev/null; }   # vips, without its optional-plugin warnings
# The Qt 6 qml runtime (plain `qml` on PATH may be Qt 5's, e.g. from KDE).
QML=""
for q in /usr/lib/qt6/bin/qml "$(command -v qml6 || true)" "$(command -v qml || true)"; do
    [[ -x "$q" ]] && "$q" --version 2>/dev/null | grep -q 'Runtime 6' && { QML="$q"; break; }
done
[[ -n "$QML" ]] || { echo "Qt 6 qml runtime not found (package qt6-declarative)" >&2; exit 1; }

# name | caption | background glow colours (two)
SHOTS=(
    "desktop|A clean, fast desktop shell for Hyprland|#4a5fd0|#7b5cff"
    "settings|Settings: palettes, accent colours, blur and liquid glass|#3f6fd8|#5a4fcf"
    "wallpapers|Pictures and live wallpapers, picked from a carousel|#d0662f|#8c2f4a"
    "launcher|An app launcher that learns what you use|#3b6fd6|#1aa3c8"
)

# Background: a dark base with two soft glows, rendered small and upscaled.
background() {
    python3 - "$1" "$2" "$3" <<'EOF'
import math, sys
out, c1, c2 = sys.argv[1:4]
W, H = 400, 250
hexc = lambda h: tuple(int(h[i:i+2], 16) / 255 for i in (1, 3, 5))
base = hexc("#0b0d14")
blobs = [(hexc(c1), .72, .62, .30, .55), (hexc(c2), .95, .25, .25, .40)]
px = bytearray()
for y in range(H):
    for x in range(W):
        u, vv = x / W, y / W
        r, g, b = base
        for c, cx, cy, rad, a in blobs:
            w = a * math.exp(-((u - cx) ** 2 + (vv - cy * H / W) ** 2) / (2 * rad * rad))
            r, g, b = r + (c[0] - r) * w, g + (c[1] - g) * w, b + (c[2] - b) * w
        px += bytes(max(0, min(255, int(ch * 255))) for ch in (r, g, b))
open(out, "wb").write(f"P6 {W} {H} 255\n".encode() + px)
EOF
}

for entry in "${SHOTS[@]}"; do
    IFS='|' read -r name caption glow1 glow2 <<<"$entry"
    src="$RAW/$name.png"
    [[ -f "$src" ]] || { echo "skipping $name: $src not found"; continue; }
    echo "==> $name"

    # Rounded corners (radius 32 at 1920x1080) as an alpha channel.
    v sdf "$WORK/m.v" 1920 1080 rounded-box --a "0 0" --b "1920 1080" --corners "32 32 32 32"
    v linear "$WORK/m.v" "$WORK/ma.v" -- -255 127.5
    v cast "$WORK/ma.v" "$WORK/mask.v" uchar
    v extract_band "$src" "$WORK/rgb.v" 0 --n 3
    v bandjoin "$WORK/rgb.v $WORK/mask.v" "$WORK/$name-shot.png"

    # Soft shadow: the same shape on a padded canvas, blurred, 70 % black.
    v sdf "$WORK/s.v" 2200 1360 rounded-box --a "140 140" --b "2060 1220" --corners "32 32 32 32"
    v linear "$WORK/s.v" "$WORK/sa.v" -- -255 127.5
    v cast "$WORK/sa.v" "$WORK/sb.v" uchar
    v gaussblur "$WORK/sb.v" "$WORK/sc.v" 42
    v linear "$WORK/sc.v" "$WORK/sd.v" 0.7 0
    v cast "$WORK/sd.v" "$WORK/se.v" uchar
    v black "$WORK/k.v" 2200 1360 --bands 3
    v cast "$WORK/k.v" "$WORK/kb.v" uchar
    v bandjoin "$WORK/kb.v $WORK/se.v" "$WORK/$name-shadow.png"

    # Background with glows (upscaled, grain against banding).
    background "$WORK/bg.ppm" "$glow1" "$glow2"
    v resize "$WORK/bg.ppm" "$WORK/bgr.v" 4 --kernel lanczos3
    v gaussblur "$WORK/bgr.v" "$WORK/$name-bg.png" 4

    QT_QPA_PLATFORM=offscreen "$QML" "$HERE/compose.qml" -- "$WORK" "$name" "$WORK/$name-out.png" "$caption" >/dev/null 2>&1
    # Smaller file: strip metadata, maximum PNG compression.
    v copy "$WORK/$name-out.png" "$HERE/$name.png[compression=9,strip]"
    echo "    $HERE/$name.png"
done
