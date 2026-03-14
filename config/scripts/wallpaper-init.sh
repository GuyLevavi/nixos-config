#!/usr/bin/env bash
# wallpaper-init — restore the last selected wallpaper on session start
#
# Called by exec-once in hyprland.conf. Reads the path written by
# wallpaper-select and re-applies it via hyprpaper IPC.
# Silently exits if no wallpaper has been chosen yet.

set -euo pipefail

LAST_FILE="${HOME}/.config/hypr/.wallpaper_last"

[[ -f "${LAST_FILE}" ]] || exit 0

img=$(cat "${LAST_FILE}")
img="${img%$'\n'}"   # strip trailing newline

[[ -f "${img}" ]] || exit 0

# Wait briefly for hyprpaper to finish starting up
sleep 0.5

hyprctl hyprpaper preload "${img}"
hyprctl hyprpaper wallpaper ",${img}"
