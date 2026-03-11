# home/gui.nix — GUI layer (Wayland / Hyprland) for nixbox
# Imports base.nix and adds everything that requires a display server.
{ config, pkgs, lib, ... }:

{
  imports = [ ./base.nix ];

  # ── GUI catppuccin modules ─────────────────────────────────────────────
  catppuccin.kitty.enable    = true;
  catppuccin.waybar.enable   = true;
  catppuccin.hyprland.enable = true;
  catppuccin.hyprlock.enable = true;
  catppuccin.mako.enable     = true;

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

  # ── Screen lock: hyprlock + hypridle ──────────────────────────────────
  programs.hyprlock.enable = true;

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd         = "hyprlock";
        before_sleep_cmd = "hyprlock";
        after_sleep_cmd  = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout    = 300;
          on-timeout = "hyprlock";
        }
        {
          timeout    = 600;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume  = "hyprctl dispatch dpms on";
        }
      ];
    };
  };

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

  # ── Wayland packages ──────────────────────────────────────────────────
  home.packages = with pkgs; [
    # Wayland essentials
    wofi                # launcher
    grim                # screenshot
    slurp               # region select
    wl-clipboard        # wl-copy / wl-paste
    wl-clip-persist     # keeps clipboard contents alive after source app closes
    cliphist            # clipboard history manager
    thunar              # GTK file manager (Super+E)
    swww                # wallpaper daemon (wayland-native)
    networkmanagerapplet # nm-applet for tray WiFi/VPN management

    # Media / function keys
    brightnessctl
    playerctl
    swayosd
    pwvucontrol         # PipeWire volume mixer
    wlogout             # Wayland logout/power menu

    # Credentials (GUI — KeePassXC requires a running display)
    keepassxc
    git-credential-keepassxc
  ];

  # ── Hyprland ──────────────────────────────────────────────────────────
  wayland.windowManager.hyprland = {
    enable         = true;
    systemd.enable = false;
    extraConfig    = builtins.readFile ../config/hypr/hyprland.conf;
  };

  # ── Waybar ────────────────────────────────────────────────────────────
  programs.waybar = {
    enable = true;
    settings = [{
      layer    = "top";
      position = "top";
      margin-top    = 6;
      margin-left   = 12;
      margin-right  = 12;
      spacing       = 4;

      "modules-left"   = [ "hyprland/workspaces" "hyprland/submap" "hyprland/window" ];
      "modules-center" = [ "clock" ];
      "modules-right"  = [ "mpris" "idle_inhibitor" "backlight" "battery" "pulseaudio" "network" "custom/bluetooth" "tray" "custom/power" ];

      "hyprland/workspaces" = {
        format         = "{name}";
        on-click       = "activate";
        on-scroll-up   = "hyprctl dispatch workspace e+1";
        on-scroll-down = "hyprctl dispatch workspace e-1";
      };

      "hyprland/submap" = {
        format  = " {}";
        tooltip = false;
      };

      "hyprland/window" = {
        format           = "{}";
        max-length       = 50;
        separate-outputs = true;
      };

      clock = {
        format         = "{:%a %d %b  %H:%M}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };

      battery = {
        format          = "{capacity}% {icon}";
        format-charging = "{capacity}% 󰂄";
        format-plugged  = "{capacity}% 󰚥";
        format-full     = "󰁹 full";
        format-icons    = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
        states = {
          warning  = 30;
          critical = 15;
        };
        tooltip-format = "{timeTo} — {power:.1f}W";
      };

      mpris = {
        format         = "{player_icon} {title} - {artist}";
        format-paused  = "{player_icon} {title}";
        player-icons   = { default = ""; spotify = "󰓇"; firefox = "󰈹"; chromium = ""; };
        status-icons   = { paused = ""; };
        max-length     = 40;
        tooltip        = false;
      };

      "idle_inhibitor" = {
        format = "{icon}";
        format-icons = {
          activated   = "󰒳";
          deactivated = "󰒲";
        };
        tooltip = false;
      };

      backlight = {
        format       = "{icon} {percent}%";
        format-icons = [ "󰃞" "󰃟" "󰃠" ];
        tooltip      = false;
      };

      network = {
        format-wifi         = "";
        format-ethernet     = " {ipaddr}";
        format-disconnected = "󰤭";
        tooltip-format      = "{ifname}: {ipaddr}/{cidr}\n{gwaddr} — {bandwidthUpBytes} up {bandwidthDownBytes} down";
        on-click            = "nm-connection-editor";
      };

      pulseaudio = {
        format         = "{icon} {volume}%";
        format-muted   = "󰝟 muted";
        format-icons   = { default = [ "󰕿" "󰖀" "󰕾" ]; };
        on-click       = "pwvucontrol";
        tooltip-format = "{desc} — {volume}%";
      };

      "custom/bluetooth" = {
        exec = builtins.toString (pkgs.writeShellScript "waybar-bluetooth" ''
          device=$(bluetoothctl info 2>/dev/null | grep "Name:" | head -1 | sed 's/.*Name: //')
          if [ -n "$device" ]; then
            echo "󰂯 $device"
          else
            echo "󰂲"
          fi
        '');
        interval   = 5;
        on-click   = "blueman-manager";
        tooltip    = false;
      };

      "custom/power" = {
        format   = "󰐥";
        on-click = "wlogout";
        tooltip  = false;
      };

      tray = { spacing = 8; };
    }];

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 13px;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background: transparent;
        color: @text;
      }

      .modules-left,
      .modules-center,
      .modules-right {
        background: @surface0;
        border-radius: 12px;
        padding: 0 6px;
        margin: 0 4px;
      }

      #workspaces { padding: 0 2px; }

      #workspaces button {
        padding: 4px 10px;
        color: @subtext1;
        background: transparent;
        border-radius: 8px;
        transition: all 0.15s ease;
      }

      #workspaces button:hover {
        background: @surface1;
        color: @text;
      }

      #workspaces button.active {
        background: @mauve;
        color: @base;
        font-weight: bold;
      }

      #workspaces button.urgent {
        background: @red;
        color: @base;
      }

      #submap {
        padding: 4px 10px;
        color: @peach;
        font-weight: bold;
      }

      #window {
        padding: 4px 12px;
        color: @subtext0;
        font-style: italic;
      }

      #clock {
        padding: 4px 14px;
        color: @text;
        font-weight: 600;
      }

      #battery,
      #pulseaudio,
      #network,
      #backlight,
      #idle-inhibitor,
      #mpris,
      #custom-bluetooth,
      #tray,
      #custom-power {
        padding: 4px 10px;
        transition: color 0.15s ease;
      }

      #mpris            { color: @mauve;    }
      #idle-inhibitor   { color: @peach;    }
      #backlight        { color: @yellow;   }
      #battery          { color: @green;    }
      #pulseaudio       { color: @sapphire; }
      #network          { color: @teal;     }
      #custom-bluetooth { color: @blue;     }

      #battery:hover,
      #pulseaudio:hover,
      #network:hover,
      #backlight:hover,
      #idle-inhibitor:hover,
      #custom-bluetooth:hover,
      #mpris:hover {
        color: @text;
      }

      #battery.charging { color: @green; }
      #battery.plugged  { color: @teal;  }
      #battery.warning:not(.charging)  { color: @yellow; }
      #battery.critical:not(.charging) { color: @red; font-weight: bold; }

      #idle-inhibitor.activated { color: @red; }

      #custom-power {
        color: @red;
        padding: 4px 12px;
        font-size: 15px;
      }

      #custom-power:hover {
        color: @base;
        background: @red;
        border-radius: 0 12px 12px 0;
      }

      #tray { padding: 4px 8px; }
      #tray > .passive        { -gtk-icon-effect: dim; }
      #tray > .needs-attention { -gtk-icon-effect: highlight; }
    '';
  };

  # ── Mako (notifications) ──────────────────────────────────────────────
  home.file.".config/mako/config".source = ../config/mako/config;

  # ── Wofi (launcher) ───────────────────────────────────────────────────
  home.file.".config/wofi".source = ../config/wofi;
}
