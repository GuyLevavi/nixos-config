#!/usr/bin/env bash
# wallpaper-select — rofi thumbnail picker for hyprpaper
#
# Usage: wallpaper-select
# Keybind: Super+W (configured in hyprland.conf)
#
# Finds image files in ~/Pictures/wallpapers/, shows them as thumbnails
# in a rofi grid, applies the selected wallpaper via hyprpaper IPC, and
# persists the choice to ~/.config/hypr/.wallpaper_last for wallpaper-init.

set -euo pipefail

WALLPAPER_DIR="${HOME}/Pictures/wallpapers"
LAST_FILE="${HOME}/.config/hypr/.wallpaper_last"
ROFI_CONFIG="${HOME}/.config/rofi/wallpaper.rasi"

# Ensure wallpaper directory exists
if [[ ! -d "${WALLPAPER_DIR}" ]]; then
    notify-send -u normal "Wallpaper Selector" \
        "No wallpaper directory found.\nCreate: ${WALLPAPER_DIR}"
    exit 0
fi

# Collect image files (non-recursive; add -maxdepth 2 for subdirs)
mapfile -t images < <(find "${WALLPAPER_DIR}" \
    -maxdepth 1 \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \) \
    | sort)

if [[ ${#images[@]} -eq 0 ]]; then
    notify-send -u normal "Wallpaper Selector" \
        "No images found in ${WALLPAPER_DIR}"
    exit 0
fi

# Build rofi input: each line is "display_name\x00icon\x1fabsolute_path\x1f"
# When rofi renders an icon field that is an absolute path to an image,
# it renders the image as the icon — giving us thumbnails for free.
rofi_input=""
for img in "${images[@]}"; do
    name=$(basename "${img}")
    # Format: "name\0icon\x1fpath\x1f"
    rofi_input+="${name}\x00icon\x1f${img}\x1f\n"
done

# Launch rofi in dmenu mode with our wallpaper config
selected=$(printf '%b' "${rofi_input}" \
    | rofi -dmenu \
        -show-icons \
        -config "${ROFI_CONFIG}" \
        -p "  wallpaper" \
        -format 'i' \
    2>/dev/null) || true

# Empty = user dismissed (Esc)
[[ -z "${selected}" ]] && exit 0

# selected is the 0-based index; resolve to path
selected_path="${images[${selected}]}"

[[ -f "${selected_path}" ]] || {
    notify-send -u critical "Wallpaper Selector" "File not found: ${selected_path}"
    exit 1
}

# Apply via hyprpaper IPC
hyprctl hyprpaper preload "${selected_path}"
hyprctl hyprpaper wallpaper ",${selected_path}"

# Persist for wallpaper-init on next login
mkdir -p "$(dirname "${LAST_FILE}")"
echo "${selected_path}" > "${LAST_FILE}"

notify-send -u low "Wallpaper" "$(basename "${selected_path}")"
