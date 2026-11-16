#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Altair installer for Arch-based systems (Arch, EndeavourOS, CachyOS, ...).
#
#   ./install.sh               install (asks before every change)
#   ./install.sh --dry-run     show what would happen, change nothing
#   ./install.sh --uninstall   remove Altair again
#
# Options:
#   --yes        answer yes to every question (unattended)
#   --dev        link this git checkout instead of copying it (for development)
#   --no-start   don't reload Hyprland or (re)start the shell at the end
#   -h, --help   this text
#
# Promises (see CONTRIBUTING.md): sudo is used only for `pacman -S`, after
# listing the packages; `rm -rf` is only ever run on Altair's own install
# directory; your hyprland.lua is backed up before it is touched, and only a
# clearly marked block is added or removed; existing files that are not
# Altair's are renamed (*.bak-altair-<date>), never deleted. Your settings,
# cache and state are never deleted.
set -euo pipefail

# ---- Packages ---------------------------------------------------------------
# Keep this list in sync with the "Dependencies" section of README.md.
REQUIRED=(
    quickshell                     # the shell toolkit (Qt/QML)
    qt6-multimedia                 # live (video) wallpapers: QML module
    qt6-multimedia-ffmpeg          # live (video) wallpapers: decoder
    inter-font                     # UI font
    ttf-material-symbols-variable  # icons
    pipewire wireplumber           # volume, UI sounds (pw-play)
    libvips                        # wallpaper thumbnails
    ffmpeg                         # video wallpaper thumbnails and still frames
    sound-theme-freedesktop        # notification sound
    xdg-utils                      # "Open folder" fallback
)
OPTIONAL=(
    networkmanager                 # network status and menu in the bar
    bluez                          # Bluetooth menu (enable bluetooth.service yourself)
    ddcutil                        # monitor brightness/contrast over DDC/CI (desktop PCs)
    upower                         # battery in the bar (laptops)
    libnotify                      # "Send test" notification button
    cava                           # music visualizer (Music widget)
    libpulse                       # pactl: routes the music player into the equalizer
    gpu-screen-recorder            # screen recorder button (60 fps, GPU-encoded)
    cliphist                       # clipboard history (SUPER + SHIFT + V, opt-in)
    wl-clipboard                   # wl-paste / wl-copy for the clipboard history
)
MIN_HYPRLAND="0.55"                # first version with the Lua config

# ---- Paths ------------------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

INSTALL_DIR="$DATA_HOME/altair"
QS_LINK="$CONFIG_HOME/quickshell/altair"
HYPR_DIR="$CONFIG_HOME/hypr"
HYPR_LINK="$HYPR_DIR/altair"
HYPR_CONF="$HYPR_DIR/hyprland.lua"
DESKTOP_FILE="$DATA_HOME/applications/altair-settings.desktop"

BLOCK_BEGIN="-- >>> altair (added by install.sh; remove with ./install.sh --uninstall)"
BLOCK_END="-- <<< altair"
STAMP="$(date +%Y%m%d-%H%M%S)"

# ---- Options ------------------------------------------------------------------
DRY=0 YES=0 DEV=0 START=1 MODE=install
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY=1 ;;
        --yes|-y) YES=1 ;;
        --dev) DEV=1 ;;
        --no-start) START=0 ;;
        --uninstall) MODE=uninstall ;;
        -h|--help) sed -n '3,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 2 ;;
    esac
done

# ---- Helpers ------------------------------------------------------------------
if [[ -t 1 ]]; then B=$'\e[1m' D=$'\e[2m' G=$'\e[32m' Y=$'\e[33m' R=$'\e[31m' N=$'\e[0m'; else B="" D="" G="" Y="" R="" N=""; fi
say()  { printf '%s\n' "$*"; }
step() { printf '\n%s==> %s%s\n' "$B" "$*" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '%sError:%s %s\n' "$R" "$N" "$*" >&2; exit 1; }

# Run a command, or only print it in --dry-run mode.
run() {
    if (( DRY )); then
        printf '  %swould run:%s %s\n' "$D" "$N" "$(printf '%q ' "$@")"
    else
        "$@"
    fi
}

# Yes/no question; default no. --yes answers yes; --dry-run answers yes
# (to show everything that would happen) without changing anything.
ask() {
    if (( YES || DRY )); then printf '  %s [y/N] y\n' "$1"; return 0; fi
    local reply
    read -r -p "  $1 [y/N] " reply || true
    [[ "$reply" =~ ^[YyJj] ]]
}

# Move something that is in the way (and not ours) aside instead of deleting it.
move_aside() {
    local path="$1"
    if [[ -e "$path" || -L "$path" ]]; then
        warn "$path exists and is not Altair's; keeping it as $path.bak-altair-$STAMP"
        run mv -- "$path" "$path.bak-altair-$STAMP"
    fi
}

# Point a symlink at a target. Our own old links are replaced; anything else
# is moved aside first.
link() {
    local target="$1" path="$2"
    run mkdir -p -- "$(dirname "$path")"
    if [[ -L "$path" ]]; then
        local current; current="$(readlink -- "$path")"
        if [[ "$current" == "$target" ]]; then ok "$path already points to $target"; return; fi
        if [[ "$current" == *altair* ]]; then
            run ln -sfn -- "$target" "$path"; ok "$path -> $target (was $current)"; return
        fi
    fi
    move_aside "$path"
    run ln -sfn -- "$target" "$path"
    ok "$path -> $target"
}

version_ge() { [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]; }

# rm -rf, but only on Altair's own install directory.
remove_install_dir() {
    [[ "$INSTALL_DIR" == "$DATA_HOME/altair" && "$INSTALL_DIR" == "$HOME"/* && -n "$HOME" ]] \
        || die "refusing to delete unexpected path: $INSTALL_DIR"
    if [[ -d "$INSTALL_DIR" && ! -L "$INSTALL_DIR" ]]; then
        run rm -rf -- "$INSTALL_DIR"
        ok "removed $INSTALL_DIR"
    fi
}

hypr_running() { [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null; }

# ---- Checks ---------------------------------------------------------------------
preflight() {
    step "Checking your system"
    (( EUID != 0 )) || die "run this as your normal user, not as root (it asks for sudo only for pacman)"
    command -v pacman >/dev/null || die "pacman not found: install.sh supports Arch-based systems only. See README.md for a manual install."
    ok "Arch-based system (pacman)"

    if command -v hyprctl >/dev/null && hyprctl version >/dev/null 2>&1; then
        local v; v="$(hyprctl version | sed -n 's/^Hyprland \([0-9.]*\).*/\1/p' | head -n1)"
        if [[ -n "$v" ]] && version_ge "$v" "$MIN_HYPRLAND"; then ok "Hyprland $v"
        else warn "Hyprland ${v:-?} is older than $MIN_HYPRLAND; Altair needs the Lua config (0.55+)"; fi
    elif command -v Hyprland >/dev/null || command -v hyprland >/dev/null; then
        ok "Hyprland installed (not running right now)"
    else
        warn "Hyprland not found; install it first (pacman -S hyprland)"
    fi
}

# ---- Install ------------------------------------------------------------------------
install_packages() {
    step "Packages"
    local missing=() p
    for p in "${REQUIRED[@]}"; do pacman -Qi "$p" >/dev/null 2>&1 || missing+=("$p"); done
    local opt_missing=()
    for p in "${OPTIONAL[@]}"; do pacman -Qi "$p" >/dev/null 2>&1 || opt_missing+=("$p"); done

    if (( ${#opt_missing[@]} )); then
        say "  Optional, for extra features: ${opt_missing[*]}"
        if ask "Install the optional packages too?"; then missing+=("${opt_missing[@]}"); fi
    fi
    if (( ${#missing[@]} == 0 )); then ok "everything needed is installed"; return; fi

    say "  To install with pacman: ${B}${missing[*]}${N}"
    if ask "Run 'sudo pacman -S --needed ${missing[*]}'?"; then
        run sudo pacman -S --needed -- "${missing[@]}"
    else
        warn "skipped; Altair may not work fully without: ${missing[*]}"
    fi
}

install_files() {
    step "Files"
    if (( DEV )); then
        say "  --dev: linking this checkout ($REPO_DIR) instead of copying it"
        link "$REPO_DIR" "$QS_LINK"
        link "$REPO_DIR/hypr" "$HYPR_LINK"
        link "$REPO_DIR/data/altair-settings.desktop" "$DESKTOP_FILE"
        return
    fi

    # Copy only the files that belong to the shell (tracked by git if this is a
    # checkout), into a fresh install directory.
    remove_install_dir
    run mkdir -p -- "$INSTALL_DIR"
    if git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if (( DRY )); then
            say "  ${D}would copy $(git -C "$REPO_DIR" ls-files | wc -l) tracked files to $INSTALL_DIR${N}"
        else
            git -C "$REPO_DIR" ls-files -z | (cd "$REPO_DIR" && xargs -0 cp --parents -t "$INSTALL_DIR")
        fi
    else
        run cp -a -- "$REPO_DIR/." "$INSTALL_DIR/"
    fi
    ok "Altair copied to $INSTALL_DIR"
    link "$INSTALL_DIR" "$QS_LINK"
    link "$INSTALL_DIR/hypr" "$HYPR_LINK"
    link "$INSTALL_DIR/data/altair-settings.desktop" "$DESKTOP_FILE"
}

# Terminal for the SUPER+SHIFT+Return escape hatch.
# Altair's own wallpapers (assets/wallpapers, see scripts/gen-wallpapers.py):
# small sources, made 1920x1080 here with a fine grain so the gradients
# don't band. Into the picker's default folder; existing files are kept.
WALL_DIR="$HOME/Pictures/Wallpapers"
install_wallpapers() {
    step "Wallpapers"
    command -v ffmpeg >/dev/null || { warn "ffmpeg missing: skipped Altair's wallpapers"; return 0; }
    run mkdir -p -- "$WALL_DIR"
    local src dst made=0
    for src in "$REPO_DIR"/assets/wallpapers/altair-*.png; do
        dst="$WALL_DIR/$(basename "$src")"
        [[ -e "$dst" ]] && continue
        run ffmpeg -loglevel error -n -i "$src" -vf "scale=1920:1080:flags=lanczos,noise=alls=7:allf=u" -frames:v 1 "$dst"
        made=$((made + 1))
    done
    if (( made )); then ok "$made wallpapers added to $WALL_DIR (SUPER + W)"; else ok "Altair's wallpapers are already in $WALL_DIR"; fi
}

pick_terminal() {
    if [[ -n "${TERMINAL:-}" ]] && command -v "${TERMINAL%% *}" >/dev/null; then echo "$TERMINAL"; return; fi
    local t
    for t in kitty foot alacritty wezterm ghostty konsole gnome-terminal xterm; do
        command -v "$t" >/dev/null && { echo "$t"; return; }
    done
    echo kitty
}

# true if every GPU is NVIDIA (then loading only NVIDIA's EGL saves ~100 MB).
nvidia_only() {
    local v vendors=()
    for v in /sys/class/drm/card[0-9]*/device/vendor; do
        [[ -r "$v" ]] && vendors+=("$(cat "$v")")
    done
    (( ${#vendors[@]} )) || return 1
    for v in "${vendors[@]}"; do [[ "$v" == "0x10de" ]] || return 1; done
}

configure_hyprland() {
    step "Hyprland config"
    if [[ ! -f "$HYPR_CONF" ]]; then
        warn "$HYPR_CONF not found. Altair needs Hyprland's Lua config (0.55+)."
        warn "Add this line to it yourself once it exists:  require(\"altair\").setup({ terminal = \"kitty\" })"
        return
    fi
    if grep -qE '^[^-]*require\(["'\'']altair["'\'']\)' "$HYPR_CONF"; then
        ok "hyprland.lua already loads Altair (left unchanged)"
        return
    fi

    local term opts
    term="$(pick_terminal)"
    opts="terminal = \"$term\""
    if nvidia_only; then
        opts="$opts, nvidia_egl_only = true"
        say "  NVIDIA-only system detected: adding nvidia_egl_only = true (saves ~100 MB in the shell)."
    fi
    local line="require(\"altair\").setup({ $opts })"

    say "  Altair is loaded by one line at the end of $HYPR_CONF:"
    say "    ${B}${line}${N}"
    say "  It adds the shell's keybinds and starts it with Hyprland. A backup is made first."
    if ! ask "Add it?"; then
        warn "skipped; add the line above to $HYPR_CONF yourself"
        return
    fi
    run cp -p -- "$HYPR_CONF" "$HYPR_CONF.bak-altair-$STAMP"
    ok "backup: $HYPR_CONF.bak-altair-$STAMP"
    if (( DRY )); then
        say "  ${D}would append to $HYPR_CONF:${N}"; printf '    %s\n' "$BLOCK_BEGIN" "$line" "$BLOCK_END"
    else
        printf '\n%s\n%s\n%s\n' "$BLOCK_BEGIN" "$line" "$BLOCK_END" >> "$HYPR_CONF"
    fi
    ok "added to hyprland.lua"
}

start_shell() {
    (( START )) || { say "  (--no-start: not touching the running session)"; return; }
    if ! hypr_running; then
        say "  Hyprland isn't running here; Altair starts with your next Hyprland session."
        return
    fi
    step "Starting Altair"
    run hyprctl reload
    # The module knows the exact start command (environment, options).
    run hyprctl eval 'local ok, a = pcall(require, "altair"); if ok and a.restart_cmd then hl.exec_cmd(a.restart_cmd) end'
    ok "Altair (re)started"
}

do_install() {
    preflight
    install_packages
    install_files
    install_wallpapers
    configure_hyprland
    start_shell
    step "Done"
    cat <<EOF
  ${B}SUPER + Space${N}           app launcher
  ${B}SUPER + W${N}               wallpaper picker
  ${B}SUPER + N${N}               notification centre
  ${B}SUPER + ,${N}               settings
  ${B}SUPER + SHIFT + R${N}       restart Altair
  ${B}SUPER + SHIFT + Return${N}  terminal (works even if Altair is down)

  Settings are stored in ${CONFIG_HOME}/altair/config.json.
EOF
    (( DRY )) && say $'\n  '"${Y}Dry run: nothing was changed.${N}"
    return 0
}

# ---- Uninstall --------------------------------------------------------------------------
# Remove a link only if it is ours (points into an Altair install or checkout).
unlink_ours() {
    local path="$1"
    if [[ -L "$path" ]]; then
        if [[ "$(readlink -- "$path")" == *altair* ]]; then run rm -f -- "$path"; ok "removed link $path"
        else warn "$path points elsewhere; left alone"; fi
    elif [[ -e "$path" ]]; then
        warn "$path is not a link created by Altair; left alone"
    fi
}

unconfigure_hyprland() {
    [[ -f "$HYPR_CONF" ]] || return 0
    local has_block=0 has_line=0
    grep -qF -- "$BLOCK_BEGIN" "$HYPR_CONF" && has_block=1
    grep -qE '^[^-]*require\(["'\'']altair["'\'']\)' "$HYPR_CONF" && has_line=1
    (( has_block || has_line )) || { ok "hyprland.lua doesn't load Altair"; return; }

    say "  Remove the Altair line(s) from $HYPR_CONF? (backup first)"
    ask "Edit hyprland.lua?" || { warn "left unchanged; remove the require(\"altair\") line yourself"; return; }
    run cp -p -- "$HYPR_CONF" "$HYPR_CONF.bak-altair-$STAMP"
    ok "backup: $HYPR_CONF.bak-altair-$STAMP"
    if (( DRY )); then
        say "  ${D}would remove the marked block and any require(\"altair\") line${N}"
    else
        # Drop the marked block (and the blank line install.sh put before it),
        # then any remaining stand-alone require line. Blank lines are held
        # back until we know they don't precede the block.
        awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
            $0 == b { skip = 1; pend = (pend > 0 ? pend - 1 : 0); next }
            skip { if ($0 == e) skip = 0; next }
            /^[^-]*require\(["\x27]altair["\x27]\)/ { next }
            $0 == "" { pend++; next }
            { while (pend > 0) { print ""; pend-- } print }
            END { while (pend > 0) { print ""; pend-- } }' "$HYPR_CONF.bak-altair-$STAMP" > "$HYPR_CONF"
    fi
    ok "Altair removed from hyprland.lua"
}

do_uninstall() {
    step "Uninstalling Altair"
    # Hard stop of exactly our instances (see stop_cmd in hypr/init.lua for why
    # not `qs kill`).
    if command -v qs >/dev/null; then
        local pids
        pids=$(qs list -c altair 2>/dev/null | sed -n 's/^ *Process ID: *//p')
        [[ -n "$pids" ]] && { run kill -9 $pids 2>/dev/null || true; }
    fi
    unlink_ours "$QS_LINK"
    unlink_ours "$HYPR_LINK"
    unlink_ours "$DESKTOP_FILE"
    [[ -f "$DESKTOP_FILE" ]] && grep -q 'qs -c altair' "$DESKTOP_FILE" && { run rm -f -- "$DESKTOP_FILE"; ok "removed $DESKTOP_FILE"; }
    remove_install_dir
    unconfigure_hyprland
    # Altair changes some Hyprland options at runtime (blur strength, borders,
    # resizing, opacity) and adds window rules (transparency); re-reading the
    # config restores your own values and drops those rules.
    if (( START )) && hypr_running; then run hyprctl reload >/dev/null; ok "Hyprland config reloaded (your own look is back)"; fi

    step "Done"
    cat <<EOF
  Packages were left installed. Your settings and caches were kept; delete
  them yourself if you don't need them any more:
    ${CONFIG_HOME}/altair      settings
    ${STATE_HOME}/altair       launcher history, remembered Hyprland values
    ${CACHE_HOME}/altair       wallpaper thumbnails
    ${WALL_DIR}/altair-*.png   Altair's wallpapers
EOF
    (( DRY )) && say $'\n  '"${Y}Dry run: nothing was changed.${N}"
    return 0
}

if [[ "$MODE" == uninstall ]]; then do_uninstall; else do_install; fi
