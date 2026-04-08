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
    profiles = {
      external = {
        outputs = [
          {
            criteria = "HDMI-A-1";
            status = "enable";
            position = "0,0";
            mode = "1920x1080@120";
          }
          {
            criteria = "eDP-1";
            status = "disable";
          }
        ];
        exec = [ "systemctl --user restart waybar hyprpaper" ];
      };
      internal = {
        outputs = [
          {
            criteria = "eDP-1";
            status = "enable";
            position = "0,0";
          }
        ];
        exec = [ "systemctl --user restart waybar hyprpaper" ];
      };
    };
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
      charliermarsh.ruff
      detachhead.basedpyright
      # Code quality
      usernamehw.errorlens
      oderwat.indent-rainbow
      streetsidesoftware.code-spell-checker
      # Theme — Catppuccin Mocha
      catppuccin.catppuccin-vsc
      catppuccin.catppuccin-vsc-icons
      # Data formats
      redhat.vscode-yaml
      tamasfe.even-better-toml
      mechatroner.rainbow-csv
      # Notebooks
      ms-toolsai.jupyter
      marimo-team.vscode-marimo
      ms-toolsai.vscode-jupyter-powertoys
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
      { key = "ctrl+shift+`"; command = "workbench.action.terminal.new"; }
      { key = "ctrl+shift+e"; command = "workbench.view.explorer"; when = "!inputFocus"; }
    ];
    userSettings = {
      # ── Workbench ───────────────────────────────────────────────────────
      "workbench.activityBar.location" = "top";
      "workbench.statusBar.visible"    = true;
      "workbench.tips.enabled"         = false;
      "workbench.startupEditor"        = "none";
      "workbench.editor.tabSizing"     = "shrink";
      "workbench.colorTheme"           = "Catppuccin Mocha";
      "workbench.iconTheme"            = "catppuccin-mocha";
      "window.commandCenter"           = false;
      "breadcrumbs.enabled"            = true;
      # ── Explorer ────────────────────────────────────────────────────────
      "explorer.openEditors.visible"  = 0;
      "explorer.fileNesting.enabled"  = true;
      "explorer.fileNesting.patterns" = {
        "*.py"           = "\${capture}.pyc";
        "pyproject.toml" = "poetry.lock, .python-version, setup.cfg, setup.py";
      };
      # ── Editor chrome ───────────────────────────────────────────────────
      "editor.minimap.enabled"                 = false;
      "editor.lineNumbers"                     = "on";
      "editor.scrollbar.vertical"              = "auto";
      "editor.scrollbar.horizontal"            = "auto";
      "editor.overviewRulerBorder"             = false;
      "editor.renderLineHighlight"             = "line";
      "editor.glyphMargin"                     = true;
      "editor.lightbulb.enabled"               = "off";
      "editor.scrollBeyondLastLine"            = false;
      "editor.guides.indentation"              = false;
      "editor.wordWrap"                        = "off";
      "editor.suggest.preview"                 = true;
      "editor.inlineSuggest.enabled"           = true;
      "editor.bracketPairColorization.enabled" = true;
      "editor.guides.bracketPairs"             = "active";
      "editor.cursorBlinking"                  = "blink";
      "editor.cursorSmoothCaretAnimation"      = "off";
      "editor.semanticHighlighting.enabled"    = true;
      # ── Font ────────────────────────────────────────────────────────────
      "editor.fontFamily"    = "JetBrainsMono Nerd Font Mono, JetBrainsMono NF, JetBrains Mono, monospace";
      "editor.fontSize"      = 14;
      "editor.fontLigatures" = true;
      "editor.lineHeight"    = 1.65;
      "editor.letterSpacing" = 0.3;
      # ── Terminal — nushell ──────────────────────────────────────────────
      "terminal.integrated.fontFamily"           = "JetBrainsMono Nerd Font Mono, JetBrainsMono NF, monospace";
      "terminal.integrated.fontSize"             = 14;
      "terminal.integrated.lineHeight"           = 1.2;
      "terminal.integrated.cursorStyle"          = "line";
      "terminal.integrated.gpuAcceleration"      = "on";
      "terminal.integrated.defaultProfile.linux" = "nu";
      "terminal.integrated.profiles.linux"       = {
        "nu" = { "path" = "nu"; "icon" = "terminal"; };
      };
      # ── No italics (all themes) ─────────────────────────────────────────
      "editor.tokenColorCustomizations" = {
        "[*]" = {
          "textMateRules" = [{
            "scope" = [
              "comment" "keyword" "storage.type" "storage.modifier"
              "variable.language" "entity.name.type"
              "entity.other.inherited-class" "support.type" "support.class"
            ];
            "settings" = { "fontStyle" = ""; };
          }];
        };
      };
      # ── Git ─────────────────────────────────────────────────────────────
      "git.decorations.enabled" = false;
      "git.untrackedChanges"    = "hidden";
      # ── Python — disable legacy linters (Ruff + basedpyright handle everything)
      "python.defaultInterpreterPath" = "python3";
      "python.formatting.provider"    = "none";
      "python.linting.enabled"        = false;
      "python.linting.mypyEnabled"    = false;
      "python.linting.pylintEnabled"  = false;
      "python.linting.flake8Enabled"  = false;
      # ── basedpyright ────────────────────────────────────────────────────
      "basedpyright.analysis.typeCheckingMode"               = "standard";
      "basedpyright.analysis.inlayHints.variableTypes"       = true;
      "basedpyright.analysis.inlayHints.functionReturnTypes" = true;
      "basedpyright.analysis.inlayHints.callArgumentNames"   = "all";
      "basedpyright.analysis.inlayHints.pytestParameters"    = true;
      "basedpyright.analysis.autoImportCompletions"          = true;
      "basedpyright.analysis.indexing"                       = true;
      "basedpyright.analysis.packageIndexDepths" = [
        { "name" = "torch";       "depth" = 5; }
        { "name" = "torchvision"; "depth" = 4; }
        { "name" = "lightning";   "depth" = 4; }
        { "name" = "cv2";         "depth" = 3; }
        { "name" = "mlflow";      "depth" = 3; }
        { "name" = "fastapi";     "depth" = 4; }
        { "name" = "sqlalchemy";  "depth" = 3; }
        { "name" = "dagshub";     "depth" = 3; }
      ];
      "basedpyright.analysis.diagnosticSeverityOverrides" = {
        "reportUnusedImport"   = "none";
        "reportUnusedVariable" = "none";
      };
      # ── Ruff ────────────────────────────────────────────────────────────
      "ruff.enable"          = true;
      "ruff.organizeImports" = true;
      "ruff.fixAll"          = true;
      "[python]" = {
        "editor.defaultFormatter"  = "charliermarsh.ruff";
        "editor.formatOnSave"      = true;
        "editor.codeActionsOnSave" = {
          "source.fixAll.ruff"          = "explicit";
          "source.organizeImports.ruff" = "explicit";
        };
      };
      "[json]"  = { "editor.defaultFormatter" = "vscode.json-language-features"; "editor.formatOnSave" = true; };
      "[jsonc]" = { "editor.defaultFormatter" = "vscode.json-language-features"; "editor.formatOnSave" = true; };
      "[yaml]"  = { "editor.defaultFormatter" = "redhat.vscode-yaml";            "editor.formatOnSave" = true; };
      "[toml]"  = { "editor.defaultFormatter" = "tamasfe.even-better-toml";      "editor.formatOnSave" = true; };
      # ── Jupyter ─────────────────────────────────────────────────────────
      "jupyter.interactiveWindow.textEditor.executeSelection" = true;
      "jupyter.askForKernelRestart"   = false;
      "notebook.cellToolbarLocation"  = { "default" = "right"; };
      "notebook.formatOnSave.enabled" = true;
      "notebook.lineNumbers"          = "on";
      "notebook.output.scrolling"     = true;
      # ── Tool paths — PATH-relative (NixOS: binaries on PATH via Nix) ────
      "marimo.marimoPath" = "marimo";
      "dvc.dvcPath"       = "dvc";
      # ── GitLens — minimal (inline blame off, hover on demand) ───────────
      "gitlens.currentLine.enabled"        = false;
      "gitlens.hovers.currentLine.enabled" = true;
      "gitlens.hovers.currentLine.over"    = "line";
      "gitlens.codeLens.enabled"           = false;
      "gitlens.statusBar.enabled"          = false;
      # ── Error Lens ──────────────────────────────────────────────────────
      "errorLens.enabledDiagnosticLevels" = [ "error" "warning" ];
      "errorLens.followCursor"            = "allLines";
      "errorLens.delay"                   = 400;
      "errorLens.fontStyleItalic"         = false;
      "errorLens.messageMaxChars"         = 100;
      # ── AutoDocstring ───────────────────────────────────────────────────
      "autoDocstring.docstringFormat" = "numpy";
      # ── YAML ────────────────────────────────────────────────────────────
      "yaml.format.enable" = true;
      "yaml.schemas"       = {};
      # ── Files ───────────────────────────────────────────────────────────
      "files.trimTrailingWhitespace" = true;
      # ── Spell checker ───────────────────────────────────────────────────
      "cSpell.language" = "en";
      "cSpell.enabledFileTypes" = {
        "python"    = true;
        "markdown"  = true;
        "yaml"      = true;
        "toml"      = true;
        "plaintext" = false;
      };
    };
  };

  # ── Packages ──────────────────────────────────────────────────────────
  home.packages = with pkgs; [
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
}
