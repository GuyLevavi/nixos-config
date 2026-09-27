{
  inputs,
  pkgs,
  lib,
  config,
  hostName,
  ...
}:
let
  # Noctalia has no theme template for zed/opencode/tmux, so one hook script
  # rewrites each consumer's theme file. Hooks run it with no argument ("all");
  # subcommands exist for debugging. Theme names live in one table so the zed
  # and opencode arms cannot drift.
  builtinThemes = {
    "Ayu" = { dark = "Ayu Dark"; light = "Ayu Light"; opencode = "ayu"; };
    "Catppuccin" = { dark = "Catppuccin Mocha"; light = "Catppuccin Latte"; opencode = "catppuccin"; };
    "Dracula" = { dark = "Dracula"; light = "Dracula Light (Alucard)"; opencode = "noctalia-dracula"; };
    "Eldritch" = { dark = "Eldritch"; light = "Eldritch Dusk"; opencode = "noctalia-eldritch"; };
    "Gruvbox" = { dark = "Gruvbox Dark"; light = "Gruvbox Light"; opencode = "gruvbox"; };
    "Kanagawa" = { dark = "Kanagawa Wave"; light = "Kanagawa Lotus"; opencode = "kanagawa"; };
    "Nord" = { dark = "Nord Dark"; light = "Nord Light"; opencode = "nord"; };
    "Rosé Pine" = { dark = "Rosé Pine"; light = "Rosé Pine Dawn"; opencode = "noctalia-rose-pine"; };
    "Tokyo-Night" = { dark = "Tokyo Night"; light = "Tokyo Night Light"; opencode = "tokyonight"; };
  };
  caseArms =
    mk:
    lib.concatStrings (
      (map (n: mk n builtinThemes.${n}) (lib.attrNames builtinThemes))
      ++ [ "          *) ;;" ]
    );
  zedCase = caseArms (n: t: "          \"${n}\") dark=\"${t.dark}\"; light=\"${t.light}\" ;;\n");
  opencodeCase = caseArms (n: t: "          \"${n}\") theme=\"${t.opencode}\" ;;\n");

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

      # theme of ~/.config/opencode/tui.json; custom files below for the
      # palettes OpenCode has no builtin for.
      sync_opencode() {
        get_scheme || return 0
        local theme="catppuccin" target
        if [ "$source" = "builtin" ]; then
          case "$name" in
      ${opencodeCase}
          esac
        fi

        target="$cfg/opencode/tui.json"
        mkdir -p "$(dirname "$target")"
        [ -f "$target" ] || printf '{}\n' >"$target"

        if jq -e --arg t "$theme" '.theme == $t' "$target" >/dev/null 2>&1; then
          return 0
        fi

        jq --arg t "$theme" '.theme = $t' "$target" >"$target.tmp"
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

      case "''${1:-all}" in
        zed) sync_zed ;;
        opencode) sync_opencode ;;
        tmux) sync_tmux ;;
        all)
          sync_zed || true
          sync_opencode || true
          sync_tmux || true
          ;;
        *)
          echo "usage: $0 [zed|opencode|tmux]" >&2
          exit 2
          ;;
      esac
    '';
  };
  syncTheme = lib.getExe themeSync;

  # Custom OpenCode themes for palettes without a builtin twin.
  opencodeThemes = {
    "noctalia-rose-pine.json" = {
      "$schema" = "https://opencode.ai/theme.json";
      "defs" = {
        "base" = { "dark" = "#191724"; "light" = "#faf4ed"; };
        "surface" = { "dark" = "#1f1d2e"; "light" = "#fffaf3"; };
        "overlay" = { "dark" = "#26233a"; "light" = "#f2e9e1"; };
        "muted" = { "dark" = "#6e6a86"; "light" = "#9893a5"; };
        "subtle" = { "dark" = "#908caa"; "light" = "#797593"; };
        "text" = { "dark" = "#e0def4"; "light" = "#575279"; };
        "love" = { "dark" = "#eb6f92"; "light" = "#d7827e"; };
        "gold" = { "dark" = "#f6c177"; "light" = "#ea9d34"; };
        "rose" = { "dark" = "#ebbcba"; "light" = "#d7827e"; };
        "pine" = { "dark" = "#31748f"; "light" = "#56949f"; };
        "foam" = { "dark" = "#9ccfd8"; "light" = "#56949f"; };
        "iris" = { "dark" = "#c4a7e7"; "light" = "#907aa9"; };
        "highlight-low" = { "dark" = "#21202e"; "light" = "#f4ede8"; };
        "highlight-med" = { "dark" = "#403d52"; "light" = "#dfdad9"; };
        "highlight-high" = { "dark" = "#524f67"; "light" = "#cacacc"; };
      };
      "theme" = {
        "primary" = "iris";
        "secondary" = "foam";
        "accent" = "rose";
        "error" = "love";
        "warning" = "gold";
        "success" = "pine";
        "info" = "foam";
        "text" = "text";
        "textMuted" = "muted";
        "background" = "base";
        "backgroundPanel" = "surface";
        "backgroundElement" = "overlay";
        "border" = "highlight-low";
        "borderActive" = "highlight-med";
        "borderSubtle" = "highlight-low";
        "diffAdded" = "pine";
        "diffRemoved" = "love";
        "diffContext" = "muted";
        "diffHunkHeader" = "muted";
        "diffHighlightAdded" = "pine";
        "diffHighlightRemoved" = "love";
        "diffAddedBg" = "surface";
        "diffRemovedBg" = "surface";
        "diffContextBg" = "overlay";
        "diffLineNumber" = "subtle";
        "diffAddedLineNumberBg" = "surface";
        "diffRemovedLineNumberBg" = "surface";
        "markdownText" = "text";
        "markdownHeading" = "iris";
        "markdownLink" = "foam";
        "markdownLinkText" = "rose";
        "markdownCode" = "pine";
        "markdownBlockQuote" = "muted";
        "markdownEmph" = "gold";
        "markdownStrong" = "love";
        "markdownHorizontalRule" = "highlight-low";
        "markdownListItem" = "iris";
        "markdownListEnumeration" = "rose";
        "markdownImage" = "foam";
        "markdownImageText" = "rose";
        "markdownCodeBlock" = "text";
        "syntaxComment" = "muted";
        "syntaxKeyword" = "iris";
        "syntaxFunction" = "foam";
        "syntaxVariable" = "rose";
        "syntaxString" = "pine";
        "syntaxNumber" = "gold";
        "syntaxType" = "iris";
        "syntaxOperator" = "subtle";
        "syntaxPunctuation" = "text";
      };
    };
    "noctalia-dracula.json" = {
      "$schema" = "https://opencode.ai/theme.json";
      "defs" = {
        "bg" = { "dark" = "#282a36"; "light" = "#f8f8f2"; };
        "current" = { "dark" = "#44475a"; "light" = "#6272a4"; };
        "fg" = { "dark" = "#f8f8f2"; "light" = "#282a36"; };
        "comment" = { "dark" = "#6272a4"; "light" = "#6272a4"; };
        "cyan" = { "dark" = "#8be9fd"; "light" = "#0d8071"; };
        "green" = { "dark" = "#50fa7b"; "light" = "#0d8071"; };
        "orange" = { "dark" = "#ffb86c"; "light" = "#e05800"; };
        "pink" = { "dark" = "#ff79c6"; "light" = "#c9184a"; };
        "purple" = { "dark" = "#bd93f9"; "light" = "#6c3483"; };
        "red" = { "dark" = "#ff5555"; "light" = "#c9184a"; };
        "yellow" = { "dark" = "#f1fa8c"; "light" = "#c2952a"; };
      };
      "theme" = {
        "primary" = "purple";
        "secondary" = "cyan";
        "accent" = "pink";
        "error" = "red";
        "warning" = "orange";
        "success" = "green";
        "info" = "cyan";
        "text" = "fg";
        "textMuted" = "comment";
        "background" = "bg";
        "backgroundPanel" = "current";
        "backgroundElement" = "current";
        "border" = "current";
        "borderActive" = "purple";
        "borderSubtle" = "current";
        "diffAdded" = "green";
        "diffRemoved" = "red";
        "diffContext" = "comment";
        "diffHunkHeader" = "comment";
        "diffHighlightAdded" = "green";
        "diffHighlightRemoved" = "red";
        "diffAddedBg" = "current";
        "diffRemovedBg" = "current";
        "diffContextBg" = "current";
        "diffLineNumber" = "comment";
        "diffAddedLineNumberBg" = "current";
        "diffRemovedLineNumberBg" = "current";
        "markdownText" = "fg";
        "markdownHeading" = "purple";
        "markdownLink" = "cyan";
        "markdownLinkText" = "pink";
        "markdownCode" = "green";
        "markdownBlockQuote" = "comment";
        "markdownEmph" = "yellow";
        "markdownStrong" = "red";
        "markdownHorizontalRule" = "current";
        "markdownListItem" = "purple";
        "markdownListEnumeration" = "pink";
        "markdownImage" = "cyan";
        "markdownImageText" = "pink";
        "markdownCodeBlock" = "fg";
        "syntaxComment" = "comment";
        "syntaxKeyword" = "purple";
        "syntaxFunction" = "green";
        "syntaxVariable" = "pink";
        "syntaxString" = "green";
        "syntaxNumber" = "purple";
        "syntaxType" = "cyan";
        "syntaxOperator" = "pink";
        "syntaxPunctuation" = "fg";
      };
    };
    "noctalia-eldritch.json" = {
      "$schema" = "https://opencode.ai/theme.json";
      "defs" = {
        "bg" = { "dark" = "#0d0c1c"; "light" = "#fdf6e3"; };
        "surface" = { "dark" = "#12111e"; "light" = "#f4f0d9"; };
        "overlay" = { "dark" = "#1c1b30"; "light" = "#e8e4bc"; };
        "muted" = { "dark" = "#56526e"; "light" = "#8c7e5a"; };
        "subtle" = { "dark" = "#908aaf"; "light" = "#665c3c"; };
        "text" = { "dark" = "#e0daf5"; "light" = "#1a1708"; };
        "red" = { "dark" = "#ec6a88"; "light" = "#c9403c"; };
        "orange" = { "dark" = "#f5a97f"; "light" = "#c26e17"; };
        "yellow" = { "dark" = "#f4d799"; "light" = "#9c7c1f"; };
        "green" = { "dark" = "#5ebe82"; "light" = "#2d8659"; };
        "teal" = { "dark" = "#42be65"; "light" = "#1a7f4f"; };
        "blue" = { "dark" = "#82e2ff"; "light" = "#205db4"; };
        "purple" = { "dark" = "#d1afff"; "light" = "#8635c9"; };
        "magenta" = { "dark" = "#f075d5"; "light" = "#b33086"; };
      };
      "theme" = {
        "primary" = "purple";
        "secondary" = "blue";
        "accent" = "magenta";
        "error" = "red";
        "warning" = "orange";
        "success" = "green";
        "info" = "blue";
        "text" = "text";
        "textMuted" = "muted";
        "background" = "bg";
        "backgroundPanel" = "surface";
        "backgroundElement" = "overlay";
        "border" = "overlay";
        "borderActive" = "purple";
        "borderSubtle" = "overlay";
        "diffAdded" = "green";
        "diffRemoved" = "red";
        "diffContext" = "muted";
        "diffHunkHeader" = "muted";
        "diffHighlightAdded" = "green";
        "diffHighlightRemoved" = "red";
        "diffAddedBg" = "surface";
        "diffRemovedBg" = "surface";
        "diffContextBg" = "overlay";
        "diffLineNumber" = "subtle";
        "diffAddedLineNumberBg" = "surface";
        "diffRemovedLineNumberBg" = "surface";
        "markdownText" = "text";
        "markdownHeading" = "purple";
        "markdownLink" = "blue";
        "markdownLinkText" = "magenta";
        "markdownCode" = "green";
        "markdownBlockQuote" = "muted";
        "markdownEmph" = "yellow";
        "markdownStrong" = "red";
        "markdownHorizontalRule" = "overlay";
        "markdownListItem" = "purple";
        "markdownListEnumeration" = "magenta";
        "markdownImage" = "blue";
        "markdownImageText" = "magenta";
        "markdownCodeBlock" = "text";
        "syntaxComment" = "muted";
        "syntaxKeyword" = "purple";
        "syntaxFunction" = "blue";
        "syntaxVariable" = "magenta";
        "syntaxString" = "green";
        "syntaxNumber" = "yellow";
        "syntaxType" = "cyan";
        "syntaxOperator" = "subtle";
        "syntaxPunctuation" = "text";
      };
    };
  };

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
          # zed/opencode/tmux sync via the hooks above.
          community_ids = [ ];
        };
      };
    };
  };

  # A rebuild re-seeds the Nix theme block into settings.json (Nix wins the
  # merge) and `started` doesn't fire on a live session — re-sync after it.
  home.activation.themeSync = lib.hm.dag.entryAfter [ "zedSettingsActivation" ] ''
    run ${syncTheme} || true
  '';

  xdg.configFile = lib.mapAttrs' (name: value:
    lib.nameValuePair "opencode/themes/${name}" {
      source = pkgs.writeText "${name}" (builtins.toJSON value);
    }
  ) opencodeThemes;
}
