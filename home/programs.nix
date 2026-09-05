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
      # Padding is charged in whole cells (11.04 x 24.5 logical px here), so
      # x-padding costs a column whenever a cell boundary lands inside it:
      # never at 2, at ~a third of window widths at 4, always at 8.
      window-padding-x = 4;
      window-padding-y = 0;
      # Not "extend": that duplicates the nearest grid row, which smears a
      # second copy of lualine's colours into the padding.
      window-padding-color = "background";
      # Spreads the undrawable (size mod cell) remainder across both edges
      # instead of dumping it at the bottom.
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
