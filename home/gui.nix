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

  # Permanent fix: delete stale GTK backup before HM link generation runs,
  # otherwise a leftover .gtkrc-2.0.backup from a prior failed activation
  # causes subsequent activations to abort.
  home.activation.removeGtkBackup = lib.hm.dag.entryBefore ["linkGeneration"] ''
    rm -f "${config.home.homeDirectory}/.gtkrc-2.0.backup"
  '';

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
    # Kvantum: Catppuccin Qt theme (override selects mocha+mauve specifically)
    (catppuccin-kde.override { flavour = ["mocha"]; accents = ["mauve"]; })
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
      colorScheme = "CatppuccinMochaMauve";
      cursor = {
        theme = "catppuccin-mocha-dark-cursors";
        size  = 24;
      };
    };

    fonts = {
      general    = { family = "Noto Sans";              pointSize = 11; };
      fixedWidth = { family = "JetBrainsMono Nerd Font"; pointSize = 11; };
      small      = { family = "Noto Sans";              pointSize = 9;  };
      toolbar    = { family = "Noto Sans";              pointSize = 11; };
      menu       = { family = "Noto Sans";              pointSize = 11; };
      windowTitle = { family = "Noto Sans";             pointSize = 11; };
    };

    kwin = {
      virtualDesktops = {
        number = 4;
        rows   = 1;
      };
    };

    configFile = {
      # Polonium auto-tiling
      "kwinrc"."Plugins"."poloniumEnabled" = true;

      # ── A: Active window border ──────────────────────────────────────────
      # OutlineIntensity 3 = OutlineHigh — strong colored edge on active window
      "breezerc"."Common"."OutlineIntensity" = 3;
      # Border size: Tiny gives a slim colored line like Hyprland's border
      "kwinrc"."org.kde.kdecoration2"."BorderSize"     = "Tiny";
      "kwinrc"."org.kde.kdecoration2"."BorderSizeAuto" = false;

      # ── B: KWin visual effects ───────────────────────────────────────────
      "kwinrc"."Plugins"."blurEnabled"            = true;
      "kwinrc"."Plugins"."wobblywindowsEnabled"   = true;
      "kwinrc"."Plugins"."magiclampEnabled"       = true;
      "kwinrc"."Effect-blur"."BlurStrength"       = 6;   # 1–15; 6 = tasteful

      # ── C: Alt+Tab — instant cycle, no popup ────────────────────────────
      "kwinrc"."TabBox"."ShowTabBox" = false;
    };

    panels = [
      {
        location = "top";
        height   = 36;
        floating = true;
        widgets  = [
          # Left: workspace pager (numbered boxes)
          "org.kde.plasma.pager"

          # Spacer → clock → spacer (centers the clock)
          "org.kde.plasma.panelspacer"
          {
            digitalClock = {
              time.format             = "24h";
              calendar.firstDayOfWeek = "monday";
            };
          }
          "org.kde.plasma.panelspacer"

          # Right: system tray (network, BT, volume, notifications)
          {
            systemTray.items = {
              shown = [
                "org.kde.plasma.bluetooth"
                "org.kde.plasma.networkmanagement"
                "org.kde.plasma.volume"
              ];
            };
          }
        ];
      }
    ];

    shortcuts = {
      kwin = {
        # Window state
        "Window Maximize"   = "Meta+M";
        "Window Fullscreen" = "Meta+F";
        "Window Close"      = "Meta+Q";

        # Move window in tiling grid (vim-style; Meta+L is lock, not focus)
        "Move Window Left"  = "Meta+Shift+H";
        "Move Window Down"  = "Meta+Shift+J";
        "Move Window Up"    = "Meta+Shift+K";
        "Move Window Right" = "Meta+Shift+L";

        # Move window to another monitor (Ctrl variant frees H/L for tiling)
        "Window to Left Screen"  = "Meta+Ctrl+H";
        "Window to Right Screen" = "Meta+Ctrl+L";

        # Virtual desktop switching
        "Switch to Desktop 1" = "Meta+1";
        "Switch to Desktop 2" = "Meta+2";
        "Switch to Desktop 3" = "Meta+3";
        "Switch to Desktop 4" = "Meta+4";

        # Move window to desktop
        "Window to Desktop 1" = "Meta+Shift+1";
        "Window to Desktop 2" = "Meta+Shift+2";
        "Window to Desktop 3" = "Meta+Shift+3";
        "Window to Desktop 4" = "Meta+Shift+4";
      };

      krunner."display" = "Meta+Space";

      ksmserver = {
        "Lock Session" = "Meta+L";       # Meta+L = lock (no focus shortcuts to conflict)
        "Log Out"      = "Meta+Shift+E"; # power / logout menu
      };

      # App launchers
      "kitty.desktop"."_launch"         = "Meta+Return";
      "google-chrome.desktop"."_launch" = "Meta+B";
      "thunar.desktop"."_launch"        = "Meta+E";

      # Clipboard history (Klipper — built-in KDE replacement for cliphist+wofi)
      "klipper"."show-clipboard-history" = "Meta+V";

      # Screenshots (Spectacle — replaces grim+slurp)
      "spectacle"."RectangularRegionScreenShot" = "Print";
      "spectacle"."FullScreenScreenShot"        = "Meta+Print";
    };
  };
}
