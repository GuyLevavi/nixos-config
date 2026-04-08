# home/gui.nix — GUI layer (Hyprland) for nixbox
# Imports base.nix and adds everything that requires a display server.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [ ./base.nix ];

  # ── GUI catppuccin modules ─────────────────────────────────────────────
  catppuccin.kitty.enable = true;
  catppuccin.hyprland.enable = true;
  catppuccin.waybar.enable = true;
  catppuccin.hyprlock.enable = true;
  catppuccin.swaync.enable = true;
  catppuccin.rofi.enable = true;
  catppuccin.zed.enable = true;
  catppuccin.zed.icons.enable = true;

  # ── Git credential override ────────────────────────────────────────────
  # KeePassXC runs as a tray app on nixbox; override the empty helper from base.
  programs.git.settings.credential.helper = lib.mkForce "keepassxc";

  # ── Hyprland ──────────────────────────────────────────────────────────
  # systemd.enable = false: uwsm manages the systemd user session; enabling
  # both causes double session management and broken environment activation.
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    extraConfig = builtins.readFile ../config/hypr/hyprland.conf;
  };

  # ── Kanshi (automatic monitor switching) ──────────────────────────────
  services.kanshi = {
    enable = true;
    settings = [
      {
        profile.name = "external";
        profile.outputs = [
          { criteria = "HDMI-A-1"; status = "enable"; position = "0,0"; mode = "1920x1080@120"; }
          { criteria = "eDP-1"; status = "disable"; }
        ];
        profile.exec = [ "systemctl --user restart waybar hyprpaper" ];
      }
      {
        profile.name = "internal";
        profile.outputs = [
          { criteria = "eDP-1"; status = "enable"; position = "0,0"; }
        ];
        profile.exec = [ "systemctl --user restart waybar hyprpaper" ];
      }
    ];
  };

  # ── Hyprpaper ─────────────────────────────────────────────────────────
  # Wallpaper daemon. waypaper manages preload/wallpaper via IPC.
  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;
    };
  };

  # ── Hyprlock ──────────────────────────────────────────────────────────
  programs.hyprlock.enable = true;

  # ── Hypridle ──────────────────────────────────────────────────────────
  # Only manages display power — does NOT lock. Lock is manual: Super+Shift+L.
  # before_sleep_cmd and lock_cmd removed intentionally; no auto-lock on idle.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 600; # 10 min → display off
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };

  # ── Waybar ────────────────────────────────────────────────────────────
  # Three floating pills: left / center / right.
  # catppuccin.waybar.enable prepends @import "mocha.css" — all @base,
  # @mauve, @text, etc. Catppuccin variables are available in the style.
  # Color-per-module scheme and workspace icons from Hyprlust.
  programs.waybar = {
    enable = true;
    settings = [
      {
        layer = "top";
        position = "top";
        height = 36;
        spacing = 4;
        margin-top = 6;
        fixed-center = true;

        modules-left = [
          "custom/menu"
          "hyprland/window"
        ];
        modules-center = [ "hyprland/workspaces" ];
        modules-right = [
          "clock"
          "battery"
          "network"
          "bluetooth"
          "pulseaudio"
          "tray"
          "custom/power"
        ];

        # ── Left ────────────────────────────────────────────────────────
        "custom/menu" = {
          format = "󱓟";
          tooltip = false;
          on-click = "pkill rofi || rofi -show drun";
        };

        "hyprland/window" = {
          format = "  {title}";
          max-length = 50;
          separate-outputs = true;
          rewrite = {
            "(.*) — Mozilla Firefox" = " Firefox";
            "(.*) - Google Chrome" = " Chrome";
            "nvim (.*)" = " Neovim";
            "^$" = "  Desktop";
          };
        };

        # ── Center ──────────────────────────────────────────────────────
        "hyprland/workspaces" = {
          format = "{icon}";
          show-special = false;
          active-only = false;
          on-click = "activate";
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
          all-outputs = true;
          sort-by-number = true;
          persistent-workspaces = {
            "1" = [ ];
            "2" = [ ];
            "3" = [ ];
            "4" = [ ];
          };
          format-icons = {
            "1" = "󰎤";
            "2" = "󰎧";
            "3" = "󰎪";
            "4" = "󰎭";
            focused = "";
            default = "";
            urgent = "";
          };
        };

        # ── Right ───────────────────────────────────────────────────────
        "clock" = {
          interval = 1;
          format = " {:%H:%M}";
          format-alt = " {:%a %d %b  %H:%M}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            on-scroll = 1;
            format = {
              months = "<span color='#cdd6f4'><b>{}</b></span>";
              days = "<span color='#cdd6f4'><b>{}</b></span>";
              weekdays = "<span color='#f9e2af'><b>{}</b></span>";
              today = "<span color='#f38ba8'><b><u>{}</u></b></span>";
            };
          };
        };

        "network" = {
          format-wifi = "󰤨  {essid}";
          format-ethernet = "󰈁  {ifname}";
          format-disconnected = "󰖪  Offline";
          format-linked = "󰈁  {ifname}";
          max-length = 20;
          tooltip-format-wifi = "{essid} ({signalStrength}%)\n{ipaddr}";
          tooltip-format-ethernet = "{ifname}\n{ipaddr}";
          on-click = "kitty --title nmtui nmtui";
        };

        "battery" = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = "󰂄 {capacity}%";
          format-plugged = "󰚥 {capacity}%";
          format-icons = [
            "󰁺"
            "󰁻"
            "󰁼"
            "󰁽"
            "󰁾"
            "󰁿"
            "󰂀"
            "󰂁"
            "󰂂"
            "󰁹"
          ];
          tooltip-format = "{timeTo}\n{power}W";
        };

        "bluetooth" = {
          format = "󰂯 {status}";
          format-connected = "󰂱 {device_alias}";
          format-connected-battery = "󰂱 {device_alias} {device_battery_percentage}%";
          tooltip-format = "{controller_alias}\n{num_connections} connected";
          tooltip-format-connected = "{controller_alias}\n{num_connections} connected\n\n{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}";
          on-click = "kitty --title bluetui bluetui";
        };

        "pulseaudio" = {
          format = "{icon} {volume}%";
          format-muted = "󰖁 Muted";
          format-icons = {
            default = [
              "󰕿"
              "󰖀"
              "󰕾"
            ];
          };
          scroll-step = 5;
          on-click = "pwvucontrol";
          tooltip-format = "{desc}\n{volume}%";
        };

        "tray" = {
          icon-size = 16;
          spacing = 6;
        };

        "custom/power" = {
          format = "󰐥";
          tooltip = false;
          on-click = "wlogout";
        };
      }
    ];

    style = ''
      /* Catppuccin Mocha palette injected via @import mocha.css (catppuccin.waybar) */

      * {
        all:         unset;
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-weight: bold;
        font-size:   14px;
        min-height:  0;
      }

      window#waybar {
        background: transparent;
      }

      window#waybar.hidden {
        opacity: 0.2;
      }

      /* ── Three floating pills ─────────────────────────────────────── */
      .modules-left,
      .modules-center,
      .modules-right {
        background:    alpha(@base, 0.70);
        border-radius: 10px;
        padding:       2px 8px;
        margin-top:    4px;
      }

      .modules-left  { margin-left:  8px; }
      .modules-right { margin-right: 8px; }

      /* ── Per-module padding ───────────────────────────────────────── */
      #clock,
      #network,
      #battery,
      #bluetooth,
      #pulseaudio,
      #tray,
      #window,
      #workspaces,
      #custom-menu,
      #custom-power {
        padding: 2px 8px;
        color:   @text;
      }

      /* ── Module accent colors (Hyprlust Catppuccin Mocha scheme) ──── */
      #window       { color: @mauve;     }
      #clock        { color: @yellow;    }
      #battery      { color: @green;     }
      #network      { color: @teal;      }
      #bluetooth    { color: @blue;      }
      #pulseaudio   { color: @sapphire;  }
      #custom-menu  { color: @rosewater; font-size: 16px; }
      #custom-power { color: @red;       font-size: 15px; }

      #pulseaudio.muted       { color: @overlay1; }
      #battery.warning        { color: @yellow;   }
      #battery.critical       { color: @red;       animation-name: blink; animation-duration: 1s; animation-timing-function: steps(1, end); animation-iteration-count: infinite; }
      #bluetooth.disabled     { color: @overlay1; }

      /* ── Tooltips ─────────────────────────────────────────────────── */
      tooltip {
        background:    alpha(@base, 0.95);
        border:        1px solid @surface1;
        border-radius: 8px;
        padding:       6px 10px;
        color:         @text;
      }

      tooltip label {
        color: @text;
      }

      /* ── Battery blink animation (critical) ──────────────────────── */
      @keyframes blink {
        to { color: @overlay1; }
      }

      /* ── Workspaces ───────────────────────────────────────────────── */
      #workspaces button {
        box-shadow:    none;
        text-shadow:   none;
        border-radius: 8px;
        padding:       2px 6px;
        color:         @surface2;
        transition:    all 0.25s cubic-bezier(.55,-0.68,.48,1.682);
      }

      #workspaces button:hover {
        background: alpha(@surface0, 0.6);
        color:      @overlay1;
      }

      #workspaces button.active {
        color:      @peach;
        padding:    2px 10px;
        transition: all 0.25s cubic-bezier(.55,-0.68,.48,1.682);
      }

      #workspaces button.urgent {
        color: @red;
      }

      /* ── Power button: red fill + right-cap radius on hover ───────── */
      #custom-power:hover {
        background:    @red;
        color:         @base;
        border-radius: 0 10px 10px 0;
        padding-right: 12px;
      }

      /* ── Tray ─────────────────────────────────────────────────────── */
      #tray > .passive         { -gtk-icon-effect: dim;       }
      #tray > .needs-attention { -gtk-icon-effect: highlight; }
    '';
  };

  # ── Swaync (notification center — replaces mako) ──────────────────────
  services.swaync.enable = true;

  # ── Rofi ──────────────────────────────────────────────────────────────
  # package = rofi-wayland for native Wayland rendering (no XWayland).
  # catppuccin.rofi.enable writes the Mocha theme; config.rasi sources it.
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    extraConfig = {
      modi = "drun,run,filebrowser";
      show-icons = true;
      display-drun = "Apps";
      display-run = "Run";
      display-filebrowser = "Files";
      drun-display-format = "{name}";
      hover-select = true;
      me-select-entry = "MouseSecondary";
      me-accept-entry = "MousePrimary";
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
      shell = "nu";
      confirm_os_window_close = 0;
      enable_audio_bell = false;
    };
  };

  # ── Zed Editor ────────────────────────────────────────────────────────
  # catppuccin.zed injects Mocha theme + catppuccin-icons extension.
  # extraPackages PATH-wraps the zeditor binary so LSP servers are found.
  # mutableUserSettings = true: Nix wins on rebuild, Zed can write between.
  programs.zed-editor = {
    enable = true;
    mutableUserSettings = true;

    extraPackages = with pkgs; [
      basedpyright             # Python LSP (matches nixvim)
      ruff                     # Python linter/formatter
      nixd                     # Nix LSP (flake-aware)
      nixpkgs-fmt              # Nix formatter
      bash-language-server              # Bash LSP
      yaml-language-server              # YAML LSP
      taplo                    # TOML LSP + formatter
      nodePackages.prettier    # YAML/JSON/Markdown formatter
    ];

    extensions = [
      "nix"
      "toml"
      "dockerfile"
      "env"
      "basedpyright"           # required: registers adapter name for language_servers
    ];
    # catppuccin module auto-adds "catppuccin" and "catppuccin-icons" — don't list here

    userSettings = {
      vim_mode = false;

      ui_font_family     = "JetBrainsMono Nerd Font";
      buffer_font_family = "JetBrainsMono Nerd Font";
      buffer_font_size   = 14;

      terminal.shell = { program = "nu"; };

      telemetry = {
        metrics     = false;
        diagnostics = false;
      };

      features.edit_prediction_provider = "none";

      format_on_save = "on";
      autosave = { after_delay.milliseconds = 1000; };

      languages = {
        Python = {
          # basedpyright first = it handles hover; "!pyright" disables the default
          language_servers = [ "basedpyright" "!pyright" "ruff" ];
          formatter = { language_server.name = "ruff"; };
        };
      };
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
  home.activation.removeGtkBackup = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
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
    package = pkgs.catppuccin-cursors.mochaDark;
    name = "catppuccin-mocha-dark-cursors";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # ── VSCode ─────────────────────────────────────────────────────────────
  # nix-vscode-extensions overlay (applied via flake.nix) exposes
  # pkgs.vscode-marketplace.<publisher>.<name> for all marketplace extensions.
  # mutableExtensionsDir = true: Nix manages the base set; marketplace installs coexist.
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    mutableExtensionsDir = true;
    extensions = with pkgs.vscode-marketplace; [
      # Python LSP stack (ruff = formatter+linter, basedpyright = types, python = picker)
      ms-python.python
      ms-python.debugpy  # Python debugger — also used by marimo for notebook debugging
      charliermarsh.ruff
      detachhead.basedpyright
      # Code quality
      usernamehw.errorlens
      streetsidesoftware.code-spell-checker
      # Theme — Catppuccin Mocha
      catppuccin.catppuccin-vsc
      catppuccin.catppuccin-vsc-icons
      # Nix
      jnoortheen.nix-ide
      # Data formats
      redhat.vscode-yaml
      tamasfe.even-better-toml
      mechatroner.rainbow-csv
      # Notebooks
      ms-toolsai.jupyter
      marimo-team.vscode-marimo
      # Git
      eamodio.gitlens
      mhutchie.git-graph
      # ML / Data science
      lakefs.lakefs-dvc
      njpwerner.autodocstring
      # AI — install Copilot + Copilot Chat via VSCode UI instead:
      # nix-vscode-extensions tracks latest versions which may require a newer
      # VSCode than nixpkgs provides; the UI auto-selects a compatible version.
      # mutableExtensionsDir = true makes this work alongside nix-managed ones.
    ];
    keybindings = [
      # Send selection / current line to debugger REPL (works when debugger is active)
      { key = "ctrl+alt+e"; command = "editor.debug.action.selectionToRepl"; when = "editorHasSelection && inDebugMode"; }
      { key = "ctrl+alt+e"; command = "editor.debug.action.selectionToRepl"; when = "!editorHasSelection && inDebugMode"; }
      # Useful additions:
      # ctrl+alt+b  → toggle sidebar          (workbench.action.toggleSidebarVisibility)
      # ctrl+alt+t  → focus terminal panel     (workbench.action.terminal.focus)
      # ctrl+alt+d  → go to definition         (already F12 by default)
    ];
    # userSettings intentionally absent — settings.json is owned by VSCode (fully writable).
    # Seeded once from config/vscode/settings.json by the activation script below.
    # Edit live in VSCode UI or directly in ~/.config/Code/User/settings.json.
    # Path-dependent values use ~/.nix-profile/bin/ which auto-updates with Nix upgrades.
  };

  # ── VSCode settings seed ───────────────────────────────────────────────
  # Copies config/vscode/settings.json to ~/.config/Code/User/settings.json
  # ONCE — only if the file does not already exist. After that VSCode owns it.
  # To reset to defaults: rm ~/.config/Code/User/settings.json && rb
  home.activation.vscodeSettingsSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings_dir="$HOME/.config/Code/User"
    settings_file="$settings_dir/settings.json"
    seed_file="${../config/vscode/settings.json}"
    if [ ! -f "$settings_file" ]; then
      $DRY_RUN_CMD mkdir -p "$settings_dir"
      $DRY_RUN_CMD cp "$seed_file" "$settings_file"
    fi
  '';

  # ── Packages ──────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    # LSP / formatter binaries for VSCode (neovim extraPackages don't expose to VSCode PATH)
    ruff          # Python formatter + linter (ruff.path in vscode settings points here)
    nixd          # Nix LSP (nix.serverPath points here)
    nixpkgs-fmt   # Nix formatter (nixd formatting.command points here)
    # marimo: nixpkgs build broken (uv-build.patch conflict on 0.19.4).
    # Use project venv marimo instead — set per-workspace in .vscode/settings.json.

    waypaper # GUI wallpaper picker (hyprpaper backend)

    # Credentials (GUI — KeePassXC requires a running display)
    keepassxc
    git-credential-keepassxc

    # Clipboard / file access
    wl-clipboard # wl-copy / wl-paste (CLI clipboard interop)
    thunar # GTK file manager (quick picks)
    pwvucontrol # PipeWire volume mixer

    # Hyprland ecosystem
    hyprpaper # wallpaper daemon
    swayosd # volume/brightness OSD popup
    wlogout # power/logout menu (Super+Shift+E)
    cliphist # clipboard history manager
    wl-clip-persist # persist clipboard when source app closes
    grim # screenshot (region capture)
    slurp # region selector (used with grim)
    playerctl # MPRIS media player control
    bluetui # bluetooth TUI manager (replaces blueman)
  ];

  # ── LD_LIBRARY_PATH: system libs for pip-installed compiled extensions ──
  # home.sessionVariables writes a .sh file — nushell never sources it.
  # Must set directly in nushell envFile. Empirically verified needed:
  #   libstdc++.so.6 — torch, zmq, and most C++ extensions
  #   libz.so.1      — numpy
  programs.nushell.envFile.text = lib.mkAfter ''
    $env.LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib"
  '';
}
