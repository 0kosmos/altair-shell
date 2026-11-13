-- SPDX-License-Identifier: GPL-3.0-or-later
-- Altair — Hyprland integration (Hyprland 0.57+ Lua config).
--
-- This folder is linked to ~/.config/hypr/altair/, which is on Hyprland's Lua
-- module path (~/.config/hypr/?/init.lua). Load it from your hyprland.lua with
-- ONE line:
--
--     require("altair").setup({ terminal = "kitty" })
--
-- (or, on an NVIDIA-only desktop:  require("altair").setup({ terminal = "kitty", nvidia_egl_only = true }) )
--
-- Options (all optional):
--   terminal  = command for the escape-hatch terminal (default: $TERMINAL or "kitty")
--   mod       = main modifier (default: "SUPER")
--   autostart = start the shell when Hyprland starts (default: true)
--   nvidia_egl_only = true: load only NVIDIA's EGL driver into the shell. Saves
--               ~100 MB RAM on NVIDIA-only desktops (Mesa is otherwise loaded too).
--               Do NOT use on laptops where an Intel/AMD GPU drives the screen.
--
-- The escape hatches below are plain Hyprland binds, so they work even when the
-- shell has crashed or hangs:
--   MOD + SHIFT + R       restart Altair
--   MOD + SHIFT + Return  open a terminal

local M = {}

local NVIDIA_EGL = "/usr/share/glvnd/egl_vendor.d/10_nvidia.json"

function M.setup(opts)
    opts = opts or {}
    local mod = opts.mod or "SUPER"
    local terminal = opts.terminal or os.getenv("TERMINAL") or "kitty"

    -- -n: never start a second copy if one is already running.
    local start = "qs -c altair -n -d"
    if opts.nvidia_egl_only then
        start = "__EGL_VENDOR_LIBRARY_FILENAMES=" .. NVIDIA_EGL .. " " .. start
    end

    -- Kill any running instance, wait for it to exit (max ~2 s), then start a
    -- fresh one. The wait matters: `qs kill` returns before the process is gone,
    -- and starting too early would hit -n and leave NO shell running. (`qs list`
    -- prints a message even when nothing runs, so look for an "Instance" line.)
    local restart = "qs kill -c altair >/dev/null 2>&1; "
        .. "for i in $(seq 20); do qs list -c altair 2>/dev/null | grep -q '^Instance' || break; sleep 0.1; done; "
        .. start

    if opts.autostart ~= false then
        hl.on("hyprland.start", function()
            hl.exec_cmd(start)
        end)
    end

    -- Escape hatches.
    hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd(restart))
    hl.bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd(terminal))

    -- Altair animates its own surfaces; stop Hyprland from animating them too.
    hl.layer_rule({
        name    = "altair-no-anim",
        match   = { namespace = "^altair-" },
        no_anim = true,
    })
end

return M
