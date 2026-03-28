-- WezTerm config — NixOS WSL + Catppuccin Mocha
-- Place at %USERPROFILE%\.config\wezterm\wezterm.lua on Windows.
--
-- Features:
--   • Default domain: WSL:NixOS  (opens directly into nushell on NixOS)
--   • Catppuccin Mocha colour scheme
--   • Kitty image protocol enabled  (molten-nvim plots, image.nvim)
--   • JetBrains Mono Nerd Font, 13pt
--   • Tab bar on top, minimal chrome

local wezterm = require("wezterm")
local config  = wezterm.config_builder()

-- ── Default domain — NixOS WSL ───────────────────────────────────────────
config.default_domain = "WSL:NixOS"

-- ── Font ─────────────────────────────────────────────────────────────────
config.font      = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 13.0

-- ── Catppuccin Mocha colours ──────────────────────────────────────────────
-- WezTerm ships Catppuccin Mocha natively; just name it.
config.color_scheme = "Catppuccin Mocha"

-- ── Kitty image protocol ──────────────────────────────────────────────────
-- Enables inline image rendering in Neovim via image.nvim / molten-nvim.
-- WezTerm supports this natively; no extra terminal config needed.
config.enable_kitty_graphics = true

-- ── Tab bar ───────────────────────────────────────────────────────────────
config.enable_tab_bar         = true
config.use_fancy_tab_bar      = false   -- simpler retro-style tabs
config.tab_bar_at_bottom      = false   -- tabs at top
config.hide_tab_bar_if_only_one_tab = true

-- ── Window ───────────────────────────────────────────────────────────────
config.window_padding = { left = 6, right = 6, top = 4, bottom = 4 }

-- ── Scrollback ───────────────────────────────────────────────────────────
config.scrollback_lines = 10000

return config
