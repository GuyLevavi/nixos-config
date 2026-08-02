# home/gui.nix — Hyprland (your tuned animations) + apps.
# The shell around it — bar w/ media widget, launcher, clipboard history,
# notifications, lock, OSDs, wallpaper — is DMS (hosts/common.nix), driven
# here via `dms ipc` binds. No waybar/rofi/mako/swaync/hyprlock configs.
{ pkgs, ... }:
{
  imports = [ ./base.nix ];

  # ── Global session variables (Wayland + dark mode hints) ───────────────
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XCURSOR_SIZE = "24";
    QT_QPA_PLATFORM = "wayland";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    GDK_BACKEND = "wayland,x11";
    MOZ_ENABLE_WAYLAND = "1";
    SDL_VIDEODRIVER = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    OZONE_PLATFORM = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";
    # pip-installed compiled extensions dlopen() these at import time.
    LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib";
  };

  # ── Pointer / cursor ───────────────────────────────────────────────────
  home.pointerCursor = {
    enable = true;
    package = pkgs.catppuccin-cursors.mochaDark;
    name = "catppuccin-mocha-dark-cursors";
    size = 24;
    gtk.enable = true;
  };

  # ── GNOME / libadwaita apps (Nautilus, etc.) respect this for dark mode ─
  dconf.enable = true;
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # ── Hyprland ───────────────────────────────────────────────────────────
  # `hyprctl reload` applies on save. Docs: https://wiki.hypr.land
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang"; # keep legacy format; change to "lua" when migrating
    settings = {
      "$mod" = "SUPER";
      monitor = ",preferred,auto,1";

      exec-once = [ "wl-paste --watch cliphist store" ]; # history backend for DMS

      input = {
        kb_layout = "us,il";
        kb_model = "pc105"; # prevents xkbcomp "multiply defined" warnings from XWayland
        kb_options = "grp:alt_shift_toggle";
        follow_mouse = 1;
        touchpad.natural_scroll = true;
      };

      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        layout = "dwindle";
        resize_on_border = true;
        "col.active_border" = "rgb(cba6f7) rgb(89b4fa) 45deg";
        "col.inactive_border" = "rgb(6c7086)";
      };

      decoration = {
        rounding = 10;
        active_opacity = 1.0;
        inactive_opacity = 0.85;
        dim_inactive = true;
        dim_strength = 0.05;
        blur = {
          enabled = true;
          xray = true;
          size = 4;
          passes = 4;
          new_optimizations = true;
        };
        shadow = {
          enabled = true;
          range = 20;
          render_power = 3;
          color = "rgba(1e1e2e99)";
        };
      };

      # Your tuned MD3 curves — the "smooth" from the old config, verbatim.
      animations = {
        enabled = true;
        bezier = [
          "md3_decel,  0.05, 0.7,  0.1, 1.0"
          "md3_accel,  0.3,  0.0,  0.8, 0.15"
          "menu_decel, 0.1,  1.0,  0.0, 1.0"
          "menu_accel, 0.38, 0.04, 1.0, 0.07"
          "overshot,   0.05, 0.9,  0.1, 1.1"
        ];
        animation = [
          "windows,       1, 3,  md3_decel, popin 60%"
          "windowsIn,     1, 3,  md3_decel, popin 60%"
          "windowsOut,    1, 3,  md3_accel, popin 60%"
          "border,        1, 10, default"
          "fade,          1, 3,  md3_decel"
          "layersIn,      1, 3,  menu_decel, slide"
          "layersOut,     1, 2,  menu_accel"
          "workspaces,    1, 6,  menu_decel, slide"
        ];
      };

      # dwindle:pseudotile and misc:vfr were removed as config options in
      # Hyprland 0.55 — do not re-add. `pseudo` (bind below) still toggles
      # per-window pseudotiling; VFR throttling is now handled internally.
      dwindle = {
        preserve_split = true;
        force_split = 2; # always split to the right/bottom (new window opens beside current)
      };

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
        focus_on_activate = true;
      };

      binds.allow_workspace_cycles = true; # Super+Tab wraps 4 → 1

      bind = [
        "$mod,Return,exec,kitty"
        "$mod,Z,exec,zeditor"
        "$mod,B,exec,google-chrome-stable"
        "$mod,E,exec,nautilus"
        "$mod,Q,killactive"
        "$mod,F,fullscreen"
        "$mod,T,togglefloating"
        "$mod,P,pseudo"

        # DMS shell surfaces
        "$mod,Space,exec,dms ipc call spotlight toggle" # launcher
        "$mod,V,exec,dms ipc call clipboard toggle" # clipboard history
        "$mod,N,exec,dms ipc call notifications toggle"
        "$mod SHIFT,L,exec,dms ipc call lock lock"

        # Session
        "$mod SHIFT,E,exec,wlogout"
        "$mod,Escape,exec,wlogout"

        # Focus: vim keys + arrows (as before)
        "$mod,H,movefocus,l"
        "$mod,L,movefocus,r"
        "$mod,K,movefocus,u"
        "$mod,J,movefocus,d"
        "$mod,left,movefocus,l"
        "$mod,right,movefocus,r"
        "$mod,up,movefocus,u"
        "$mod,down,movefocus,d"
        "$mod SHIFT,H,movewindow,l"
        "$mod SHIFT,L,movewindow,r"
        "$mod SHIFT,K,movewindow,u"
        "$mod SHIFT,J,movewindow,d"

        # Workspace cycling (wraps due to allow_workspace_cycles)
        "$mod,TAB,workspace,m+1"
        "$mod SHIFT,TAB,workspace,m-1"

        # Alt+Tab window cycle
        "ALT,TAB,cyclenext"
        "ALT SHIFT,TAB,cyclenext,prev"

        "$mod,1,workspace,1"
        "$mod,2,workspace,2"
        "$mod,3,workspace,3"
        "$mod,4,workspace,4"
        "$mod SHIFT,1,movetoworkspace,1"
        "$mod SHIFT,2,movetoworkspace,2"
        "$mod SHIFT,3,movetoworkspace,3"
        "$mod SHIFT,4,movetoworkspace,4"

        ",Print,exec,grimblast copy area"
        "$mod,Print,exec,grimblast copy screen"
        "$mod SHIFT,S,exec,grimblast save area ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png"

        # Media keys
        ",XF86AudioPlay,exec,playerctl play-pause"
        ",XF86AudioNext,exec,playerctl next"
        ",XF86AudioPrev,exec,playerctl previous"
      ];

      binde = [
        "$mod ALT,H,resizeactive,-30 0"
        "$mod ALT,L,resizeactive,30 0"
        "$mod ALT,K,resizeactive,0 -30"
        "$mod ALT,J,resizeactive,0 30"
      ];

      bindm = [ "$mod,mouse:272,movewindow" "$mod,mouse:273,resizewindow" ];

      bindel = [
        ",XF86AudioRaiseVolume,exec,dms ipc call audio increment 3"
        ",XF86AudioLowerVolume,exec,dms ipc call audio decrement 3"
        ",XF86AudioMute,exec,dms ipc call audio mute"
        ",XF86MonBrightnessUp,exec,dms ipc call brightness increment 5"
        ",XF86MonBrightnessDown,exec,dms ipc call brightness decrement 5"
      ];
    };

    # Hyprland 0.54+ uses block syntax for windowrules (old `windowrule = rule, match` removed).
    extraConfig = ''
      windowrule {
        name = float-portals
        match:class = ^(xdg-desktop-portal-gtk)$
        float = yes
      }
      windowrule {
        name = float-open-file
        match:title = ^(Open File)(.*)$
        float = yes
      }
      windowrule {
        name = float-dialogs
        match:title = ^(Save File|Save As|Confirm|Warning)(.*)$
        float = yes
      }
      windowrule {
        name = float-system-tools
        match:class = ^(blueman-manager|nm-connection-editor|pwvucontrol)$
        float = yes
      }
      windowrule {
        name = float-tui-panels
        match:title = ^(nmtui|bluetui)$
        float = yes
        center = yes
        size = 700 500
      }
      windowrule {
        name = kitty-opacity
        match:class = ^(kitty)$
        opacity = 1.0 0.85
      }
      windowrule {
        name = immediate-fullscreen
        match:fullscreen = 1
        immediate = yes
      }
      windowrule {
        name = float-keepassxc
        match:class = ^(org.keepassxc.KeePassXC)$
        float = yes
        center = yes
        size = 900 600
      }
    '';
  };

  # Clipboard history backend (DMS's clipboard UI reads from cliphist).
  services.cliphist = { enable = true; allowImages = true; };

  # Idle → DMS lock after 5 min, screen off at 10.
  services.hypridle = {
    enable = true;
    settings = {
      general.lock_cmd = "dms ipc call lock lock";
      listener = [
        { timeout = 300; on-timeout = "dms ipc call lock lock"; }
        { timeout = 600; on-timeout = "hyprctl dispatch dpms off"; on-resume = "hyprctl dispatch dpms on"; }
      ];
    };
  };

  # ── Terminal ───────────────────────────────────────────────────────────
  programs.kitty = {
    enable = true;
    font = { name = "JetBrainsMono Nerd Font"; size = 12; };
    themeFile = "Catppuccin-Mocha";
  };

  # ── Editor: Zed (VSCode keymap, no vim mode) ──────────────────────────
  programs.zed-editor = {
    enable = true;
    mutableUserSettings = true;
    extraPackages = with pkgs; [
      basedpyright
      ruff
      nixd
      nixpkgs-fmt
      bash-language-server
      yaml-language-server
      taplo
    ];
    extensions = [ "nix" "toml" "dockerfile" "env" "basedpyright" "catppuccin" ];
    userSettings = {
      base_keymap = "VSCode";
      vim_mode = false;
      buffer_font_family = "JetBrainsMono Nerd Font";
      buffer_font_size = 14;
      terminal.shell.program = "fish";
      telemetry = { metrics = false; diagnostics = false; };
      format_on_save = "on";
      theme = { mode = "dark"; light = "Catppuccin Mocha"; dark = "Catppuccin Mocha"; };
      languages.Python = {
        language_servers = [ "basedpyright" "!pyright" "ruff" ];
        formatter.language_server.name = "ruff";
      };
    };
  };

  programs.google-chrome.enable = true;
  programs.firefox.enable = true;

  gtk = {
    enable = true;
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  home.packages = with pkgs; [
    # xdg-desktop-portal-gtk: the Hyprland HM module installs
    # xdg-desktop-portal-hyprland into this same per-user profile. XDG_DATA_DIRS
    # puts the user profile before the system one, and xdg-desktop-portal only
    # scans the first directory it finds any *.portal file in — so without gtk's
    # portal file living alongside hyprland's here, the daemon never discovers
    # it at all (regardless of xdg.portal.config routing), and libadwaita apps
    # (Nautilus) can't query dark-mode via the Settings portal.
    xdg-desktop-portal-gtk
    grimblast
    wl-clipboard # screenshots + clipboard plumbing
    wlogout # power/logout menu ($mod SHIFT,E / $mod,Escape)
    playerctl # media key binds
    spotify # shows in DMS bar's media widget (MPRIS)
    nautilus
    keepassxc
    opencode
    opencode-desktop # AI coding agent (TUI + desktop client)
    obsidian
    rclone # cloud sync — see rclone-bisync-* systemd services below
  ];

  # ── OpenCode ────────────────────────────────────────────────────────────
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    plugin = [ "opencode-browser" ];
    mcp = {
      context7 = {
        type = "local";
        command = [ "npx" "-y" "@upstash/context7-mcp" ];
        enabled = true;
      };
      playwright = {
        type = "local";
        command = [ "npx" "-y" "@playwright/mcp@latest" ];
        enabled = true;
      };
      browsermcp = {
        type = "local";
        command = [ "npx" "-y" "@browsermcp/mcp@0.1.3" ];
        enabled = true;
      };
      grep = {
        type = "remote";
        url = "https://mcp.grep.app";
        enabled = true;
      };
      sequential-thinking = {
        type = "local";
        command = [ "npx" "-y" "@modelcontextprotocol/server-sequential-thinking" ];
        enabled = true;
      };
      nixos = {
        type = "local";
        command = [ "nix" "run" "github:utensils/mcp-nixos" "--" ];
        enabled = true;
      };
    };
  };

  # ── Cloud sync: Obsidian vault (rclone bisync) ─────────────────────────
  # ~/GoogleDrive/Obsidian mirrors gdrive:Obsidian (just the vault, not the
  # whole Drive — full-Drive bisync was too slow to be worth it). Remote
  # "gdrive" is configured once, manually, via `rclone config` — OAuth can't
  # be declared in Nix. First sync was a manual
  # `rclone bisync gdrive:Obsidian ~/GoogleDrive/Obsidian --resync`
  # (bisync's own safety requirement) — already done; the vault was moved
  # here from OneDrive via `rclone copy`.
  systemd.user.services.rclone-bisync-gdrive = {
    Unit.Description = "Bisync ~/GoogleDrive/Obsidian with Google Drive remote";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.rclone}/bin/rclone bisync gdrive:Obsidian %h/GoogleDrive/Obsidian --conflict-resolve=newer --conflict-suffix=conflict";
    };
  };
  systemd.user.timers.rclone-bisync-gdrive = {
    Unit.Description = "Run rclone-bisync-gdrive every 5 minutes";
    Timer = { OnBootSec = "2m"; OnUnitActiveSec = "5m"; };
    Install.WantedBy = [ "timers.target" ];
  };

  programs.fish.shellAbbrs.syncvault = "systemctl --user start rclone-bisync-gdrive";
}
