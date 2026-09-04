{ pkgs, ... }:
{
  # Colours come from Noctalia's ghostty template at runtime; only non-colour
  # settings belong here. `theme = noctalia` points at the file it writes.
  # Ghostty doesn't hot-reload — ctrl+shift+, or a new window after a switch.
  programs.ghostty = {
    enable = true;
    settings = {
      theme = "noctalia";
      font-family = "JetBrainsMono Nerd Font";
      font-size = 14;
      window-decoration = false;
      # Both were 8 — the real source of the visible dead border on every edge
      # (8 logical px/edge = 10 physical at this panel's 1.25 scale), costing a
      # whole text row + 2 columns: measured 34x137 at 8 vs 35x139 at 0 on the
      # same fullscreen window. x=2 is free — it lands on the same 35x139 grid
      # because it just absorbs leftover sub-cell remainder (7px -> 3px) into
      # deliberate padding, so text doesn't sit flush against the screen edge.
      window-padding-x = 2;
      window-padding-y = 0;
      # Flat fill, not extend: this theme's background already equals nvim's
      # own editor bg (both #0b0e14, matugen-driven), so a flat fill is a
      # perfect blend. "extend[-always]" instead duplicates the *nearest grid
      # row* — when that row is a status line (lualine), it smears a second
      # fake copy of the status line's own colour into the padding.
      window-padding-color = "background";
      # What remains after padding=0 is pure cell-grid quantisation, which every
      # terminal emulator has: only whole cells can be drawn, so
      # (size mod cell) is undrawable. Cell here is ~11.05 x 24.5 logical px, so
      # fullscreen leaves 864 - 35*24.5 = 6.5 px total. Balance spreads that as
      # ~3px/edge rather than dumping it all at the bottom. (window-step-resize,
      # the real "snap to whole cells" fix, is macOS-only and moot under tiling.)
      window-padding-balance = true;
      confirm-close-surface = false;
    };
  };

  # Minimal monochrome cursor: Noctalia can't theme it, so pick one that stays
  # legible on any palette. No gtk.enable here (it needs the gtk module, which
  # the ownership rule keeps off); Wayland apps read XCURSOR_THEME from the env.
  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    hyprcursor.enable = true;
  };

  programs.bat.enable = true;
  programs.eza.enable = true;
  programs.ripgrep.enable = true;
  services.hypridle.enable = true; # config is the out-of-store symlink

  home.packages = with pkgs; [
    # screenshots / media
    # hyprlock removed 2026-09-04: Noctalia has its own native lock screen
    # (ext-session-lock), triggered via `loginctl lock-session` in
    # hypr/hypridle.conf — hyprlock was dead weight bypassing it.
    hyprpicker
    grim
    slurp
    wf-recorder
    cliphist
    imv
    mpv
    unzip
    jq
    btop
    helix # zero-config editor fallback next to lazyvim

    # CLI (no home-manager module)
    fd
    dust
    yazi
    podman-compose
    lazydocker

    # dev
    python3
    uv
    nodejs
    claude-code
  ];
}
