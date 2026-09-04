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
      window-padding-x = 8;
      window-padding-y = 8;
      # Paint padding + grid remainder by extending edge cells, or full-bg apps
      # (nvim/btop) show theme-bg bands. Must be extend-always: plain "extend"
      # refuses rows with powerline glyphs — i.e. nvim's lualine/bufferline.
      window-padding-color = "extend-always";
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
    hyprlock
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
