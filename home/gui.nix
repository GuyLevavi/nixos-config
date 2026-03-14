# home/gui.nix — GUI layer (Hyprland) for nixbox
# Imports base.nix and adds everything that requires a display server.
{ config, pkgs, lib, ... }:

{
  imports = [ ./base.nix ];

  # ── GUI catppuccin modules ─────────────────────────────────────────────
  catppuccin.kitty.enable    = true;
  catppuccin.hyprland.enable = true;
  catppuccin.waybar.enable   = true;
  catppuccin.hyprlock.enable = true;
  catppuccin.swaync.enable   = true;
  catppuccin.rofi.enable     = true;

  # ── Git credential override ────────────────────────────────────────────
  # KeePassXC runs as a tray app on nixbox; override the empty helper from base.
  programs.git.settings.credential.helper = lib.mkForce "keepassxc";

  # ── Hyprland ──────────────────────────────────────────────────────────
  # systemd.enable = false: uwsm manages the systemd user session; enabling
  # both causes double session management and broken environment activation.
  wayland.windowManager.hyprland = {
    enable         = true;
    systemd.enable = false;
    extraConfig    = builtins.readFile ../config/hypr/hyprland.conf;
  };

  # ── Hyprpaper ─────────────────────────────────────────────────────────
  # Wallpaper daemon. Preload and wallpaper lines are commented out — drop in
  # your wallpaper path and uncomment when ready.
  programs.hyprpaper = {
    enable   = true;
    settings = {
      # preload  = [ "/home/gl/wallpapers/your-wallpaper.png" ];
      # wallpaper = [ ", /home/gl/wallpapers/your-wallpaper.png" ];
      splash = false;
    };
  };

  # ── Hyprlock ──────────────────────────────────────────────────────────
  programs.hyprlock.enable = true;

  # ── Hypridle ──────────────────────────────────────────────────────────
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        before_sleep_cmd = "hyprlock";
        after_sleep_cmd  = "hyprctl dispatch dpms on";
        lock_cmd         = "hyprlock";
      };
      listener = [
        {
          timeout    = 300; # 5 min
          on-timeout = "hyprlock";
        }
        {
          timeout    = 600; # 10 min
          on-timeout = "hyprctl dispatch dpms off";
          on-resume  = "hyprctl dispatch dpms on";
        }
      ];
    };
  };

  # ── Waybar (Hyprlust-inspired) ─────────────────────────────────────────
  # catppuccin.waybar.enable prepends @import "mocha.css" so @base, @mauve,
  # @text, etc. are available in the style string below.
  programs.waybar = {
    enable = true;
    settings = [{
      layer        = "top";
      position     = "top";
      height       = 34;
      width        = 1200;
      margin-top   = 5;
      margin-left  = 50;
      margin-right = 50;
      fixed-center = true;

      modules-left   = [ "custom/menu" "custom/separator#blank" "hyprland/window" ];
      modules-center = [ "hyprland/workspaces" ];
      modules-right  = [ "idle_inhibitor" "group/hub" "custom/power" ];

      # ── Left modules ────────────────────────────────────────────────
      "custom/menu" = {
        format   = "󱓟";
        tooltip  = true;
        exec     = "echo ; echo  app launcher";
        interval = 86400;
        on-click = "pkill rofi || rofi -show drun -modi run,drun,filebrowser,window";
      };

      "custom/separator#blank" = {
        format   = "";
        interval = "once";
        tooltip  = false;
      };

      "hyprland/window" = {
        format      = "󰣆 {title}";
        max-length  = 40;
        rewrite = {
          "(.*) — Mozilla Firefox"   = " Firefox";
          "^.*v( .*|$)"             = " Neovim";
          "^.*~$"                   = "󰄛 Kitty";
          "(.*) "                   = " Empty";
        };
      };

      # ── Center modules ───────────────────────────────────────────────
      "hyprland/workspaces" = {
        format              = " {icon} ";
        show-special        = false;
        active-only         = false;
        on-click            = "activate";
        on-scroll-up        = "hyprctl dispatch workspace e+1";
        on-scroll-down      = "hyprctl dispatch workspace e-1";
        all-outputs         = true;
        sort-by-number      = true;
        persistent-workspaces = {
          "1" = [];
          "2" = [];
          "3" = [];
          "4" = [];
        };
        format-icons = {
          "1"     = " ";
          "2"     = " ";
          "3"     = " ";
          "4"     = " ";
          focused = "";
          default = "";
        };
      };

      # ── Right modules ────────────────────────────────────────────────
      "idle_inhibitor" = {
        format       = "{icon}";
        format-icons = {
          activated   = " ";
          deactivated = " ";
        };
      };

      # group/hub: the right info pill — clock + network + bluetooth + audio + tray
      "group/hub" = {
        orientation = "inherit";
        modules     = [ "clock" "network" "bluetooth" "pulseaudio" "tray" ];
      };

      "clock" = {
        interval       = 1;
        format         = "{:%H:%M}";
        format-alt     = " {:%H:%M   %Y-%m-%d, %A}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
        calendar = {
          mode        = "year";
          mode-mon-col = 3;
          on-scroll   = 1;
          format = {
            months   = "<span color='#cdd6f4'><b>{}</b></span>";
            days     = "<span color='#cdd6f4'><b>{}</b></span>";
            weekdays = "<span color='#f9e2af'><b>{}</b></span>";
            today    = "<span color='#f38ba8'><b><u>{}</u></b></span>";
          };
        };
      };

      "network" = {
        format-wifi       = "󰤨";
        format-ethernet   = "󰈁";
        format-disconnected = "󰖪";
        format-linked     = "󰈁";
        tooltip           = true;
        tooltip-format-wifi = "{essid} ({signalStrength}%)";
        tooltip-format-ethernet = "{ifname}";
        tooltip-format-disconnected = "Disconnected";
        on-click          = "nm-connection-editor";
      };

      "bluetooth" = {
        format-on        = "";
        format-off       = "󰂲";
        format-disabled  = "";
        format-connected = "";
        tooltip          = true;
        tooltip-format   = "{controller_alias}\n{num_connections} connected";
        on-click         = "blueman-manager";
      };

      "pulseaudio" = {
        format         = "{icon} {volume}%";
        format-muted   = "󰖁";
        format-icons   = {
          default = [ "󰕿" "󰖀" "󰕾" ];
        };
        scroll-step    = 5;
        on-click       = "pwvucontrol";
        tooltip-format = "{desc} | {volume}%";
      };

      "tray" = {
        icon-size = 16;
        spacing   = 4;
      };

      "custom/power" = {
        format   = "⏻";
        tooltip  = true;
        exec     = "echo ; echo 󰟡 power";
        interval = 86400;
        on-click = "wlogout";
      };
    }];

    style = ''
      /* Catppuccin Mocha — colors provided via @import mocha.css from catppuccin.waybar */

      * {
        all:            unset;
        font-family:    "JetBrainsMono Nerd Font";
        font-weight:    bold;
        font-size:      13px;
        min-height:     0;
      }

      window#waybar {
        background:  transparent;
        border-radius: 12px;
      }

      window#waybar.hidden {
        opacity: 0.2;
      }

      /* ── Pills ───────────────────────────────────────────────────── */
      .modules-left,
      .modules-center,
      .modules-right {
        background:    alpha(@base, 0.85);
        border:        1px solid @overlay0;
        border-radius: 12px;
        padding:       2px 6px;
      }

      .modules-left,
      .modules-right {
        border-color: @blue;
      }

      /* ── Per-module padding ──────────────────────────────────────── */
      #clock,
      #network,
      #bluetooth,
      #pulseaudio,
      #idle_inhibitor,
      #tray,
      #window,
      #workspaces,
      #custom-menu,
      #custom-power {
        padding: 3px 6px;
      }

      /* ── Module accent colors (Hyprlust Catppuccin Mocha style) ──── */
      #window          { color: @mauve;     }
      #clock           { color: @yellow;    }
      #network         { color: @teal;      }
      #bluetooth       { color: @blue;      }
      #pulseaudio      { color: @sapphire;  }
      #pulseaudio.muted { color: @red;      }
      #idle_inhibitor  { color: @blue;      }
      #custom-menu     { color: @rosewater; }
      #custom-power    { color: @red;       }

      /* ── Workspaces ──────────────────────────────────────────────── */
      #workspaces button {
        box-shadow:   none;
        text-shadow:  none;
        border-radius: 9px;
        padding:      0 4px;
        transition:   all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
      }

      #workspaces button:hover {
        background-color: @surface0;
        color:            @overlay0;
        border-radius:    10px;
        padding:          0 2px;
      }

      #workspaces button.active {
        color:         @peach;
        border-radius: 10px;
        padding:       0 8px;
        transition:    all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
      }

      #workspaces button.urgent {
        color:         @red;
        border-radius: 0;
      }

      #workspaces button.persistent {
        color:         @surface1;
        border-radius: 10px;
      }

      /* ── Power button: red fill on hover, right-cap border-radius ── */
      #custom-power:hover {
        background:    @red;
        color:         @base;
        border-radius: 0 12px 12px 0;
      }

      /* ── Tray ────────────────────────────────────────────────────── */
      #tray > .passive       { -gtk-icon-effect: dim;       }
      #tray > .needs-attention { -gtk-icon-effect: highlight; }
    '';
  };

  # ── Swaync (notification center — replaces mako) ──────────────────────
  services.swaync.enable = true;

  # ── Rofi ──────────────────────────────────────────────────────────────
  # package = rofi-wayland for native Wayland rendering (no XWayland).
  # catppuccin.rofi.enable writes the Mocha theme; config.rasi sources it.
  programs.rofi = {
    enable  = true;
    package = pkgs.rofi-wayland;
    extraConfig = {
      modi              = "drun,run,filebrowser";
      show-icons        = true;
      display-drun      = "Apps";
      display-run       = "Run";
      display-filebrowser = "Files";
      drun-display-format = "{name}";
      hover-select      = true;
      me-select-entry   = "MouseSecondary";
      me-accept-entry   = "MousePrimary";
    };
  };

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

  # Permanent fix: delete stale GTK backup before HM link generation runs.
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
    # Credentials (GUI — KeePassXC requires a running display)
    keepassxc
    git-credential-keepassxc

    # Clipboard / file access
    wl-clipboard    # wl-copy / wl-paste (CLI clipboard interop)
    thunar          # GTK file manager (quick picks)
    pwvucontrol     # PipeWire volume mixer

    # Hyprland ecosystem
    hyprpaper       # wallpaper daemon
    rofi-wayland    # app launcher (wayland-native)
    swayosd         # volume/brightness OSD popup
    wlogout         # power/logout menu (Super+Shift+E)
    cliphist        # clipboard history manager
    wl-clip-persist # persist clipboard when source app closes
    grim            # screenshot (region capture)
    slurp           # region selector (used with grim)
    playerctl       # MPRIS media player control
    networkmanagerapplet  # nm-applet tray icon
    blueman         # bluetooth manager (blueman-manager on-click)
  ];
}
