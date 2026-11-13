#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Compile shaders/*.frag to .qsb (Qt's shader format). The .qsb files are
# committed, so users don't need this; run it after editing a shader.
# Needs qsb from qt6-shadertools.
set -euo pipefail

cd "$(dirname "$0")/../shaders"
QSB="$(command -v qsb || echo /usr/lib/qt6/bin/qsb)"
[[ -x "$QSB" ]] || { echo "qsb not found (install qt6-shadertools)" >&2; exit 1; }

for f in *.frag; do
    "$QSB" --qt6 -o "$f.qsb" "$f"
    echo "built shaders/$f.qsb"
done
