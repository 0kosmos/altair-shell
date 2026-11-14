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
--   icon_theme = icon theme for app/tray icons (default: your GTK icon theme from
--               gtk-3.0/settings.ini; Qt alone often finds no theme on Hyprland)
--   launcher_key = keys for the app launcher (default: MOD + SPACE, false = none)
--   notifications_key = keys for the notification centre (default: MOD + N)
--   settings_key = keys for Altair Settings (default: MOD + comma)
--   wallpaper_key = keys for the wallpaper picker (default: MOD + W)
--   workspace_prev_key = previous workspace by number (default: MOD + CTRL + left)
--   workspace_next_key = next workspace by number (default: MOD + CTRL + right)
--   last_workspace_key = back to the last-used workspace (default: MOD + Tab)
--   alttab    = Alt+Tab window switcher (default: true)
--   (any key option: false = no bind)
--
-- The escape hatches below are plain Hyprland binds, so they work even when the
-- shell has crashed or hangs:
--   MOD + SHIFT + R       restart Altair
--   MOD + SHIFT + Return  open a terminal

local M = {}

local NVIDIA_EGL = "/usr/share/glvnd/egl_vendor.d/10_nvidia.json"

local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Read gtk-icon-theme-name from the user's GTK 3 (or 4) settings, if any.
local function gtk_icon_theme()
    local base = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
    for _, v in ipairs({ "gtk-3.0", "gtk-4.0" }) do
        local f = io.open(base .. "/" .. v .. "/settings.ini", "r")
        if f then
            for line in f:lines() do
                local name = line:match("^%s*gtk%-icon%-theme%-name%s*=%s*(.-)%s*$")
                if name and name ~= "" then
                    f:close()
                    return name
                end
            end
            f:close()
        end
    end
    return nil
end

function M.setup(opts)
    opts = opts or {}
    local mod = opts.mod or "SUPER"
    local terminal = opts.terminal or os.getenv("TERMINAL") or "kitty"

    -- -n: never start a second copy if one is already running.
    local start = "qs -c altair -n -d"
    if opts.nvidia_egl_only then
        start = "__EGL_VENDOR_LIBRARY_FILENAMES=" .. NVIDIA_EGL .. " " .. start
    end
    local icon_theme = opts.icon_theme or gtk_icon_theme()
    if icon_theme then
        start = "QS_ICON_THEME=" .. shell_quote(icon_theme) .. " " .. start
    end

    -- Stop: SIGKILL exactly the processes `qs list -c altair` reports, and
    -- wait (max ~2 s) until they are gone. Not `qs kill`: that asks the shell
    -- to quit over IPC, which a hung shell cannot answer (the restart then hit
    -- -n and did nothing), and a normal quit can crash inside Quickshell's
    -- Wayland cleanup, after which its crash handler relaunches the shell and
    -- races the new one. SIGKILL loses nothing: settings are saved as they
    -- change, and the live-wallpaper process exits when the shell is gone.
    local stop = "pids=$(qs list -c altair 2>/dev/null | sed -n 's/^ *Process ID: *//p'); "
        .. "[ -n \"$pids\" ] && kill -9 $pids 2>/dev/null; "
        .. "for i in $(seq 20); do alive=; for p in $pids; do kill -0 $p 2>/dev/null && alive=1; done; "
        .. "[ -z \"$alive\" ] && break; sleep 0.1; done; "
    local restart = stop .. start

    -- Exposed so install.sh can stop/(re)start the shell with the same settings:
    --   hyprctl eval 'hl.exec_cmd(require("altair").restart_cmd)'
    M.start_cmd = start
    M.stop_cmd = stop
    M.restart_cmd = restart

    if opts.autostart ~= false then
        hl.on("hyprland.start", function()
            hl.exec_cmd(start)
        end)
    end

    -- Escape hatches.
    hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd(restart))
    hl.bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd(terminal))

    -- Panels.
    local ipc = "qs -c altair ipc call panels toggle "
    if opts.launcher_key ~= false then
        hl.bind(opts.launcher_key or (mod .. " + SPACE"), hl.dsp.exec_cmd(ipc .. "launcher"))
    end
    if opts.notifications_key ~= false then
        hl.bind(opts.notifications_key or (mod .. " + N"), hl.dsp.exec_cmd(ipc .. "notifications"))
    end
    if opts.wallpaper_key ~= false then
        hl.bind(opts.wallpaper_key or (mod .. " + W"), hl.dsp.exec_cmd(ipc .. "wallpaper"))
    end
    if opts.settings_key ~= false then
        hl.bind(opts.settings_key or (mod .. " + comma"), hl.dsp.exec_cmd(ipc .. "settings"))
    end

    -- Workspaces. Animated by Hyprland (style/speed set by Altair at runtime).
    if opts.workspace_prev_key ~= false then
        hl.bind(opts.workspace_prev_key or (mod .. " + CTRL + left"), hl.dsp.focus({ workspace = "r-1" }))
    end
    if opts.workspace_next_key ~= false then
        hl.bind(opts.workspace_next_key or (mod .. " + CTRL + right"), hl.dsp.focus({ workspace = "r+1" }))
    end
    if opts.last_workspace_key ~= false then
        hl.bind(opts.last_workspace_key or (mod .. " + Tab"), hl.dsp.focus({ workspace = "previous" }))
    end

    -- Alt+Tab (see alttab/AltTab.qml).
    --   Tab presses reach the shell as global shortcuts (no process per press).
    --   Releasing Alt emits a custom event on Hyprland's event socket instead:
    --   a global-shortcut event sent on a key RELEASE is only delivered with
    --   the next input event (tested on 0.57), so the switcher would wait for
    --   another key. ignore_mods: matches with or without Shift held (where the
    --   key can be Meta_L); non_consuming: apps still see Alt (e.g. menu bars).
    if opts.alttab ~= false then
        local g = function(name) return hl.dsp.global("altair:alttab-" .. name) end
        hl.bind("ALT + Tab", g("next"), { repeating = true })
        hl.bind("ALT + SHIFT + Tab", g("prev"), { repeating = true })
        local released = hl.dsp.event("altair:alttab-release")
        local opt = { release = true, ignore_mods = true, non_consuming = true }
        hl.bind("Alt_L", released, opt)
        hl.bind("Meta_L", released, opt)
    end

    -- The Settings window is a normal toplevel window (class org.quickshell):
    -- float it, centred, at a sensible size instead of tiling it.
    hl.window_rule({
        name   = "altair-settings",
        match  = { class = "^org\\.quickshell$", title = "^Altair Settings$" },
        float  = true,
        center = true,
        size   = { 1120, 700 },
        -- Matches the corner radius Altair draws (Theme.radius.l).
        rounding = 18,
        -- Altair animates the window's content itself (a calm fade-in). Hyprland's
        -- own open animation (often a springy pop-in) made it wobble.
        no_anim = true,
        -- Never made see-through by a default window opacity (Settings >
        -- Transparency); it draws its own translucent glass.
        opacity = "1 override 1 override",
    })

    -- Altair animates its own surfaces; stop Hyprland from animating them too.
    hl.layer_rule({
        name    = "altair-no-anim",
        match   = { namespace = "^altair-" },
        no_anim = true,
    })
end

return M
