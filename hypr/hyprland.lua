-- Out-of-store symlink: edit + `hyprctl reload`, no rebuild.
-- require() resolves next to ~/.config/hypr/hyprland.lua, not this repo path.

require("binds")

-- Docked 1080p panel: scale 1, not the fractional default below.
hl.monitor({ output = "desc:ASUSTek COMPUTER INC ASUS VG249 0x00019552", mode = "highrr", position = "auto", scale = 1 })

-- Generic default for both laptops (`hyprctl monitors` for names).
hl.monitor({ output = "", mode = "highrr", position = "auto", scale = 1.25 })

hl.config({
    input = {
        kb_layout = "us,il",
        kb_options = "grp:alt_shift_toggle,caps:escape",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
            tap_to_click = true,
            scroll_factor = 0.6,
        },
    },

    cursor = {
        -- Hide after 4s idle; any motion brings it back.
        inactive_timeout = 4,
        -- ...and immediately on typing (off by default in Hyprland).
        hide_on_key_press = true,
    },

    general = {
        -- One gap constant, 8. gaps_in is a HALF-gap in Hyprland, so
        -- gaps_in = gaps_out / 2. The bar mirrors this in home/noctalia.nix —
        -- change both together or the islands drift off the window grid.
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        -- overridden by noctalia.apply_theme() (end of file) on theme switch
        col = {
            active_border = "rgba(89b4faee)",
            inactive_border = "rgba(45475aaa)",
        },
        layout = "dwindle",
        allow_tearing = false,
        resize_on_border = true,
    },

    decoration = {
        rounding = 8,
        active_opacity = 1.0,
        -- 0.85 + blur = the islands' frosted material (capsule opacity in noctalia.nix).
        inactive_opacity = 0.85,
        blur = {
            enabled = true,
            size = 6,
            passes = 2,
            new_optimizations = true,
        },
        shadow = {
            enabled = true,
            range = 12,
            render_power = 3,
        },
    },

    animations = { enabled = true },

    dwindle = {
        preserve_split = true,
        force_split = 2, -- new windows always open right/bottom (Omarchy-style)
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        vrr = 1,
    },

    -- vfr is debug-only since 0.55 but there's no prod replacement for the battery win
    debug = { vfr = true },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.curve("smooth", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "smooth" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "smooth", style = "slide" })

local dialogs = "^(Open File|Save File|Choose Files)$"
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "file-dialogs", match = { title = dialogs }, float = true, size = "60% 60%" })
hl.window_rule({ name = "ghostty-opacity", match = { class = "^(ghostty)$" }, opacity = "0.95 0.85" })
-- blank XWayland windows on dGPU
hl.window_rule({ name = "xwvb-no-anim", match = { class = "^(xwaylandvideobridge)$" }, no_anim = true })

hl.layer_rule({
    name = "noctalia_blur",
    -- Namespaces are "noctalia-bar-<name>"; an exact-match ^(noctalia)$ blurs nothing.
    match = { namespace = "^(noctalia-bar-.*)$" },
    blur = true,
    -- Only the 0.85-alpha islands frost; the strip itself is transparent.
    ignore_alpha = 0.2,
})

-- Noctalia is a systemd user unit (home/noctalia.nix) and owns idle too.
hl.on("hyprland.start", function()
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("monitor-watch") -- disable the internal panel whenever an external monitor is present
end)

-- Both runtime-written and absent on a fresh install, hence pcall.
-- Noctalia's apply.sh appends to this file unless it finds `require("noctalia")`.
local ok, noctalia = pcall(require, "noctalia")
if ok then noctalia.apply_theme() end

-- Written by monitor-watch (home/scripts.nix): disable the panel while docked,
-- empty otherwise. A required file, not inline, so it survives reloads.
pcall(require, "monitor-state")
