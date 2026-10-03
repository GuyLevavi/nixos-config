{
  inputs,
  pkgs,
  lib,
  config,
  hostName,
  ...
}:
let
  # Noctalia has no theme template for zed/tmux/nvim, so one hook script
  # rewrites each consumer's theme file. Theme names live in one table so the
  # arms cannot drift from the palette Noctalia reports.
  builtinThemes = {
    "Ayu" = { dark = "Ayu Dark"; light = "Ayu Light"; nvim = { dark = "ayu-mirage"; light = "ayu-light"; }; };
    "Catppuccin" = { dark = "Catppuccin Mocha"; light = "Catppuccin Latte"; nvim = { dark = "catppuccin-mocha"; light = "catppuccin-latte"; }; };
    "Dracula" = { dark = "Dracula"; light = "Dracula Light (Alucard)"; nvim = { dark = "dracula"; light = "dracula"; }; };
    "Eldritch" = { dark = "Eldritch"; light = "Eldritch Dusk"; nvim = { dark = "eldritch"; light = "eldritch"; }; };
    "Gruvbox" = { dark = "Gruvbox Dark"; light = "Gruvbox Light"; nvim = { dark = "gruvbox"; light = "gruvbox"; }; };
    "Kanagawa" = { dark = "Kanagawa Wave"; light = "Kanagawa Lotus"; nvim = { dark = "kanagawa-wave"; light = "kanagawa-lotus"; }; };
    "Nord" = { dark = "Nord Dark"; light = "Nord Light"; nvim = { dark = "nord"; light = "nord"; }; };
    "Rosé Pine" = { dark = "Rosé Pine"; light = "Rosé Pine Dawn"; nvim = { dark = "rose-pine"; light = "rose-pine-dawn"; }; };
    "Tokyo-Night" = { dark = "Tokyo Night"; light = "Tokyo Night Light"; nvim = { dark = "tokyonight-night"; light = "tokyonight-day"; }; };
  };
  caseArms =
    mk:
    lib.concatStrings (
      (map (n: mk n builtinThemes.${n}) (lib.attrNames builtinThemes))
      ++ [ "          *) ;;" ]
    );
  zedCase = caseArms (n: t: "          \"${n}\") dark=\"${t.dark}\"; light=\"${t.light}\" ;;\n");
  nvimCase = caseArms (n: t: "          \"${n}\") scheme=\"${t.nvim.dark}\"; [ \"$mode\" = light ] && scheme=\"${t.nvim.light}\" ;;\n");

  themeSync = pkgs.writeShellApplication {
    name = "noctalia-theme-sync";
    runtimeInputs = [
      pkgs.jq
      pkgs.gawk
      pkgs.tmux
      config.programs.noctalia.package
    ];
    text = ''
      cfg="''${XDG_CONFIG_HOME:-$HOME/.config}"

      # Reads $source/$name/$mode; fails when the IPC socket is down
      # (tty, ssh, early boot) — callers then leave their file alone.
      get_scheme() {
        local line
        line="$(noctalia msg color-scheme-get 2>/dev/null || true)"
        [ -n "$line" ] || return 1
        source="''${line%% *}"
        name="''${line#* }"
        mode="$(noctalia msg theme-mode-get 2>/dev/null || true)"
        [ "$mode" = "light" ] || mode="dark"
      }

      # theme block of ~/.config/zed/settings.json; seed in home/zed.nix, and
      # zed live-reloads the file.
      sync_zed() {
        get_scheme || return 0
        local dark="Catppuccin Mocha" light="Catppuccin Latte" target
        if [ "$source" = "builtin" ]; then
          case "$name" in
      ${zedCase}
          esac
        fi

        target="$cfg/zed/settings.json"
        mkdir -p "$(dirname "$target")"
        [ -f "$target" ] || printf '{}\n' >"$target"

        # Unchanged -> no write; every write makes zed reload settings.
        if jq -e --arg d "$dark" --arg l "$light" --arg m "$mode" \
          '.theme.mode == $m and .theme.dark == $d and .theme.light == $l' "$target" >/dev/null 2>&1; then
          return 0
        fi

        # write-then-rename so zed never reads a half-written file
        jq --arg d "$dark" --arg l "$light" --arg m "$mode" \
          '.theme = {mode: $m, dark: $d, light: $l}' "$target" >"$target.tmp"
        mv -f "$target.tmp" "$target"
      }

      # palette.conf for home/tmux.nix, parsed from the ghostty theme Noctalia
      # already writes (so community/custom palettes work too).
      sync_tmux() {
        local theme_file="$cfg/ghostty/themes/noctalia" out
        [ -f "$theme_file" ] || return 0

        local p0="" p4="" p5="" p7="" p8=""
        eval "$(awk -F= '
          /^palette = / { gsub(/[[:space:]]/, "", $2); gsub(/[[:space:]]/, "", $3); print "p" $2 "=" $3 }
        ' "$theme_file")"
        [ -n "$p4" ] || return 0

        out="$cfg/tmux/palette.conf"
        mkdir -p "$(dirname "$out")"
        {
          printf 'set -g status-style "bg=%s,fg=%s"\n' "$p0" "$p7"
          printf 'set -g status-left "#[bg=%s,fg=%s,bold] #S #[bg=%s,fg=%s,nobold]"\n' "$p4" "$p0" "$p0" "$p4"
          printf 'set -g status-right "#[fg=%s]#h #[fg=%s]%%H:%%M "\n' "$p8" "$p4"
          printf 'setw -g window-status-style "fg=%s,bg=%s"\n' "$p8" "$p0"
          printf 'setw -g window-status-current-style "fg=%s,bg=%s,bold"\n' "$p0" "$p4"
          printf 'set -g message-style "bg=%s,fg=%s"\n' "$p8" "$p7"
          printf 'set -g mode-style "bg=%s,fg=%s"\n' "$p4" "$p0"
          printf 'setw -g clock-mode-colour "%s"\n' "$p5"
          printf 'set -g pane-border-style "fg=%s"\n' "$p8"
          printf 'set -g pane-active-border-style "fg=%s"\n' "$p4"
          printf 'set -g popup-style "bg=%s,fg=%s"\n' "$p0" "$p7"
          printf 'set -g popup-border-style "fg=%s"\n' "$p8"
        } >"$out.tmp"

        # Unchanged -> no write, no needless live reload.
        if cmp -s "$out.tmp" "$out" 2>/dev/null; then
          rm -f "$out.tmp"
          return 0
        fi
        mv -f "$out.tmp" "$out"

        # Apply in place if a server is running; a no-op at login.
        tmux source-file "$out" >/dev/null 2>&1 || true
      }

      # theme.lua for nvim/init.lua: same builtin name -> a hand-tuned
      # colorscheme plugin (installed by vim.pack in nvim/init.lua).
      sync_nvim() {
        get_scheme || return 0
        local scheme="catppuccin-mocha" out
        [ "$mode" = "light" ] && scheme="catppuccin-latte"
        if [ "$source" = "builtin" ]; then
          case "$name" in
      ${nvimCase}
          esac
        fi

        out="''${XDG_STATE_HOME:-$HOME/.local/state}/nvim/theme.lua"
        mkdir -p "$(dirname "$out")"
        {
          printf "vim.o.background = '%s'\n" "$mode"
          printf "vim.cmd.colorscheme '%s'\n" "$scheme"
        } >"$out.tmp"

        # Unchanged -> no write; nvim reads this only at startup.
        if cmp -s "$out.tmp" "$out" 2>/dev/null; then
          rm -f "$out.tmp"
          return 0
        fi
        mv -f "$out.tmp" "$out"
      }

      sync_zed || true
      sync_tmux || true
      sync_nvim || true
    '';
  };
  syncTheme = lib.getExe themeSync;

  # One material for the five islands; padding feeds the pills' 2px radius (8 - 6).
  mkGroup = id: members: {
    inherit id members;
    fill = "surface";
    opacity = 0.85;
    padding = 6;
    radius = 8; # matches hypr/hyprland.conf decoration.rounding
  };

  # gpubox is PRIME sync (dGPU always on, real NVML stats); cpubox's iGPU has no
  # VRAM and shows no GPU island at all. Nothing polls GPU stats unless a GPU
  # widget is displayed.
  statsMembers = [ "cpu" "ram" "cputemp" ];
  # Mirrors the CPU island: usage, memory, temp.
  gpuMembers = [ "gpu" "gpuvram" "gputemp" ];
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true; # user service, bound to graphical-session.target

    # Seeds ~/.config/noctalia/config.toml; the GUI's
    # ~/.local/state/noctalia/settings.toml overrides per-key.
    #
    # GOTCHA: touching [bar.default] in the GUI copies the whole table into
    # settings.toml, shadowing everything below — strip it after geometry edits.
    settings = {
      # One constant, 8: islands sit 8 from the screen edges, 8 apart, 8 above
      # the windows (gaps_out supplies the last). margin_ends must stay 0 — it
      # stacks with padding.
      bar.default = {
        background_opacity = 0.0;
        shadow = false; # a bar-wide shadow hazes the top of the windows below
        margin_edge = 8;
        margin_ends = 0;
        concave_edge_corners = false; # needs margin_edge = 0
        thickness = 30; # stock is 34; compact DMS-style footprint
        padding = 8; # lane inset: island edges on the window grid
        widget_spacing = 8; # island and widget gaps share one knob
        capsule_thickness = 1.0; # islands fill the strip; top edge at margin_edge
        capsule_radius = 2; # pills sit 6 inside the 8px island (concentric)
        # `end` is right-anchored, so media at its head keeps a fixed right
        # edge while its title changes; under `start` the active-window title
        # would shove it around.
        start = [ "group:left" ];
        center = [ "group:mid" ];
        end =
          [
            "group:media"
            "group:stats"
          ]
          ++ lib.optionals (hostName == "gpubox") [ "group:gpu" ]
          ++ [ "group:sys" ];
        capsule_group =
          [
            (mkGroup "left" [
              "workspaces"
              "active_window"
            ])
            (mkGroup "media" [ "media" ])
            (mkGroup "mid" [ "clock" ])
            (mkGroup "stats" statsMembers)
          ]
          ++ lib.optionals (hostName == "gpubox") [ (mkGroup "gpu" gpuMembers) ]
          ++ [
            (mkGroup "sys" [
              "volume"
              "battery"
              "tray"
              "network"
              "bluetooth"
              "control-center"
            ])
          ];
      };

      # Resource gauges + media; referenced by the capsule groups above.
      widget = {
        # Scrolling titles are a marquee in peripheral vision; keep off.
        active_window = {
          max_length = 260;
          title_scroll = "none";
        };
        media = {
          hide_when_no_media = true;
          max_length = 260;
        };
        cpu = {
          type = "sysmon";
          stat = "cpu_usage";
        };
        ram = {
          type = "sysmon";
          stat = "ram_pct";
        };
        cputemp = {
          type = "sysmon";
          stat = "cpu_temp";
        };
        # Icon only; the expanded view has the SSID.
        network.show_label = false;
      }
      // lib.optionalAttrs (hostName == "gpubox") {
        # Glyphs mirror the CPU island row-for-row.
        gpu = {
          type = "sysmon";
          stat = "gpu_usage";
          glyph = "cpu-usage";
        };
        gpuvram = {
          type = "sysmon";
          stat = "gpu_vram";
        };
        gputemp = {
          type = "sysmon";
          stat = "gpu_temp";
          glyph = "cpu-temperature";
        };
      };

      # 8 (window rounding) + 8 (gaps_out) = 16.
      shell.screen_corners = {
        enabled = true;
        size = 16;
      };

      # Noctalia owns idle (hypridle was just a timer around these same actions);
      # it locks before suspend via logind's PrepareForSleep.
      #
      # GOTCHA: as with [bar.default], opening Settings → Idle in the GUI copies
      # this table into settings.toml and shadows everything below.
      idle = {
        # Fullscreen fade before the action; cancels on input. Global, not
        # per-behavior.
        pre_action_fade_seconds = 3.0;

        behavior = {
          # Long timeouts: the machine is left unattended so a phone can reach
          # the sessions; locking hides the screen for free.
          lock = {
            enabled = true;
            action = "lock";
            timeout = 1800; # 30 min
          };

          # This second, shorter timeout applies only once already locked.
          "screen-off" = {
            enabled = true;
            action = "screen_off";
            timeout = 2400; # 40 min while unlocked
            locked_timeout = 120; # 2 min once locked
          };

          # Declared and off: suspending would cut off remote sessions. Lid
          # close off AC is the backstop (modules/laptop.nix).
          suspend = {
            enabled = false;
            action = "lock_and_suspend";
            timeout = 7200; # 2 h, if ever turned back on
          };
        };
      };


      # Palette sync on every change and at login.
      hooks = {
        started = [ syncTheme ];
        colors_changed = [ syncTheme ];
        theme_mode_changed = [ syncTheme ];
      };

      theme = {
        builtin = "Catppuccin";
        templates = {
          builtin_ids = [
            "btop"
            "gtk3"
            "gtk4"
            "ghostty"
            "hyprland"
            "qt"
            "starship"
          ];
        };
      };
    };
  };

  # A rebuild re-seeds the Nix theme block into settings.json (Nix wins the
  # merge) and `started` doesn't fire on a live session — re-sync after it.
  home.activation.themeSync = lib.hm.dag.entryAfter [ "zedSettingsActivation" ] ''
    run ${syncTheme} || true
  '';
}
