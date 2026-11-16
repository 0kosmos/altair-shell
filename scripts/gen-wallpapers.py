#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Altair's default wallpapers: soft "mesh gradients" (a dark base colour and
# a few large Gaussian colour blobs), original to Altair.
#
#   scripts/gen-wallpapers.py [output-dir]
#
# Writes small 480x270 sources (PPM, then PNG via ffmpeg) into
# assets/wallpapers/. install.sh turns them into 1920x1080 wallpapers with a
# fine grain (so the gradients don't band); see install_wallpapers there.
# Pure standard library (+ ffmpeg for the PNG conversion).
import math
import os
import subprocess
import sys
import tempfile

W, H = 480, 270


def hexc(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))


# name: (base colour, [(colour, centre x, centre y, radius, strength)])
DESIGNS = {
    "aurora":  ("#0a0e1c", [("#3b5bdb", .22, .78, .38, .9), ("#7c5cff", .78, .25, .33, .8), ("#1aa3c8", .55, .9, .25, .55)]),
    "dusk":    ("#120b18", [("#c2507a", .25, .8, .36, .85), ("#6a3fb5", .75, .3, .36, .85), ("#f08a5d", .9, .95, .22, .5)]),
    "lagoon":  ("#06141a", [("#1f9e8f", .2, .3, .38, .8), ("#2563a8", .8, .75, .4, .8), ("#7fd1c1", .6, .15, .2, .45)]),
    "ember":   ("#140b08", [("#d9622b", .3, .75, .35, .85), ("#8c2f39", .8, .35, .35, .8), ("#f2b45a", .65, .95, .22, .5)]),
    "glacier": ("#0c1219", [("#5d8fc4", .25, .25, .4, .75), ("#a7c7e7", .8, .8, .3, .55), ("#3c4f7a", .7, .2, .35, .8)]),
}


def render(base, blobs):
    b = hexc(base)
    px = bytearray()
    for y in range(H):
        for x in range(W):
            u, v = x / W, y / H * (H / W)  # keep blobs round
            r, g, bl = b
            for col, cx, cy, rad, a in blobs:
                c = hexc(col)
                d2 = (u - cx) ** 2 + (v - cy * (H / W)) ** 2
                w = a * math.exp(-d2 / (2 * (rad * 0.6) ** 2))
                r, g, bl = r + (c[0] - r) * w, g + (c[1] - g) * w, bl + (c[2] - bl) * w
            px += bytes(max(0, min(255, int(ch * 255))) for ch in (r, g, bl))
    return px


out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets", "wallpapers")
os.makedirs(out, exist_ok=True)
with tempfile.TemporaryDirectory() as tmp:
    for name, (base, blobs) in DESIGNS.items():
        ppm = os.path.join(tmp, name + ".ppm")
        with open(ppm, "wb") as f:
            f.write(f"P6 {W} {H} 255\n".encode())
            f.write(render(base, blobs))
        png = os.path.join(out, f"altair-{name}.png")
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", ppm, png], check=True)
        print("wrote", os.path.normpath(png))
