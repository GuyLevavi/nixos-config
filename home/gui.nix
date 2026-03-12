# home/gui.nix — GUI layer (KDE Plasma 6) for nixbox
# Imports base.nix and adds everything that requires a display server.
{ config, pkgs, lib, ... }:

{
  imports = [ ./base.nix ];

  # ── GUI catppuccin modules ─────────────────────────────────────────────
  catppuccin.kitty.enable = true;

  # ── Git credential override ────────────────────────────────────────────
  # KeePassXC runs as a tray app on nixbox; override the empty helper from base.
  programs.git.settings.credential.helper = lib.mkForce "keepassxc";

  # ── Kitty ─────────────────────────────────────────────────────────────
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 14;
    };
    settings = {
      shell                   = "nu";
      confirm_os_window_close = 0;
      enable_audio_bell       = false;
    };
  };

  # ── Browsers ──────────────────────────────────────────────────────────
  programs.google-chrome = {
    enable = true;
    commandLineArgs = [
      "--enable-features=WebUIDarkMode"
      "--force-dark-mode"
      "--ozone-platform=wayland"
      "--enable-wayland-ime"
    ];
  };

  programs.firefox.enable = true;

  # ── GTK dark theme + icon theme ───────────────────────────────────────
  gtk = {
    enable = true;
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };
  catppuccin.gtk.icon = {
    enable = true;
    accent = "mauve";
  };

  # ── Cursor theme ──────────────────────────────────────────────────────
  home.pointerCursor = {
    package    = pkgs.catppuccin-cursors.mochaDark;
    name       = "catppuccin-mocha-dark-cursors";
    size       = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # ── Packages ──────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    # Kvantum: Catppuccin Qt theme
    catppuccin-kde
    kdePackages.qtstyleplugin-kvantum

    # Credentials (GUI — KeePassXC requires a running display)
    keepassxc
    git-credential-keepassxc

    # Clipboard / file access
    wl-clipboard    # wl-copy / wl-paste (CLI clipboard interop)
    thunar          # GTK file manager (quick picks)
    pwvucontrol     # PipeWire volume mixer
  ];

  # Point Kvantum at the Catppuccin-Mocha-Mauve theme
  home.file.".config/Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=Catppuccin-Mocha-Mauve
  '';

  # ── KDE Plasma configuration (plasma-manager) ─────────────────────────
  programs.plasma = {
    enable = true;

    workspace = {
      colorScheme = "BreezeDark";
      cursor = {
        theme = "catppuccin-mocha-dark-cursors";
        size  = 24;
      };
    };

    kwin = {
      virtualDesktops = {
        number = 4;
        rows   = 1;
      };
    };

    shortcuts = {
      # Window focus / movement (replicates Hyprland Super+hjkl feel)
      kwin = {
        "Window to Left Screen"  = "Meta+H";
        "Window to Right Screen" = "Meta+L";
        "Window Maximize"        = "Meta+M";
        "Window Close"           = "Meta+Q";
        # Virtual desktop switching
        "Switch to Desktop 1"    = "Meta+1";
        "Switch to Desktop 2"    = "Meta+2";
        "Switch to Desktop 3"    = "Meta+3";
        "Switch to Desktop 4"    = "Meta+4";
        # Move window to desktop
        "Window to Desktop 1"    = "Meta+Shift+1";
        "Window to Desktop 2"    = "Meta+Shift+2";
        "Window to Desktop 3"    = "Meta+Shift+3";
        "Window to Desktop 4"    = "Meta+Shift+4";
      };
      krunner = {
        "display" = "Meta+Space";
      };
    };
  };
}
