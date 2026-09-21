{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  # Zed has no Noctalia template, so the palette reaches it here: the hooks
  # below rewrite the theme block of ~/.config/zed/settings.json (mutable,
  # live-reloaded by zed). Theme-name granularity — the zed-side seed and the
  # extensions those names come from are in home/zed.nix.
  zedThemeSync = pkgs.writeShellApplication {
    name = "noctalia-zed-theme";
    runtimeInputs = [
      pkgs.jq
      config.programs.noctalia.package
    ];
    text = ''
      # "<source> <name>", e.g. "builtin Catppuccin". Empty when the IPC
      # socket isn't up (tty, ssh, early boot) — then leave the file alone.
      line="$(noctalia msg color-scheme-get 2>/dev/null || true)"
      [ -n "$line" ] || exit 0
      scheme_source="''${line%% *}"
      scheme_name="''${line#* }"

      mode="$(noctalia msg theme-mode-get 2>/dev/null || true)"
      [ "$mode" = "light" ] || mode="dark"

      # Fallback matches theme.builtin below. Only builtins map — wallpaper/
      # community/custom palettes keep the fallback.
      dark="Catppuccin Mocha"
      light="Catppuccin Latte"
      if [ "$scheme_source" = "builtin" ]; then
        case "$scheme_name" in
          "Tokyo-Night") dark="Tokyo Night";      light="Tokyo Night Light" ;;
          "Catppuccin")  dark="Catppuccin Mocha"; light="Catppuccin Latte" ;;
          "Gruvbox")     dark="Gruvbox Dark";     light="Gruvbox Light" ;;
          "Kanagawa")    dark="Kanagawa Wave";    light="Kanagawa Lotus" ;;
          "Rosé Pine")   dark="Rosé Pine";        light="Rosé Pine Dawn" ;;
          "Ayu")         dark="Ayu Dark";         light="Ayu Light" ;;
          "Nord")        dark="Nord Dark";        light="Nord Light" ;;
          "Dracula")     dark="Dracula";          light="Dracula Light (Alucard)" ;;
          "Eldritch")    dark="Eldritch";         light="Eldritch Dusk" ;;
          *) ;;
        esac
      fi

      cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/zed/settings.json"
      mkdir -p "$(dirname "$cfg")"
      [ -f "$cfg" ] || printf '{}\n' >"$cfg"

      # No-op when already in sync — every write triggers a zed settings reload.
      if jq -e --arg d "$dark" --arg l "$light" --arg m "$mode" \
        '.theme.mode == $m and .theme.dark == $d and .theme.light == $l' "$cfg" >/dev/null 2>&1; then
        exit 0
      fi

      # write-then-rename so zed never reads a half-written file
      jq --arg d "$dark" --arg l "$light" --arg m "$mode" \
        '.theme = {mode: $m, dark: $d, light: $l}' "$cfg" >"$cfg.tmp"
      mv -f "$cfg.tmp" "$cfg"
    '';
  };
  syncZedTheme = lib.getExe zedThemeSync;

  # OpenCode TUI theme sync. OpenCode reads theme from tui.json and has
  # built-in themes for catppuccin, tokyonight, gruvbox, kanagawa, nord, ayu.
  # For Rosé Pine, Dracula, Eldritch we create custom theme files.
  opencodeThemeSync = pkgs.writeShellApplication {
    name = "noctalia-opencode-theme";
    runtimeInputs = [
      pkgs.jq
      config.programs.noctalia.package
    ];
    text = ''
      line="$(noctalia msg color-scheme-get 2>/dev/null || true)"
      [ -n "$line" ] || exit 0
      scheme_source="''${line%% *}"
      scheme_name="''${line#* }"

      mode="$(noctalia msg theme-mode-get 2>/dev/null || true)"
      [ "$mode" = "light" ] || mode="dark"

      # Map Noctalia builtins to OpenCode theme names
      theme="catppuccin"  # fallback
      if [ "$scheme_source" = "builtin" ]; then
        case "$scheme_name" in
          "Tokyo-Night") theme="tokyonight" ;;
          "Catppuccin")  theme="catppuccin" ;;
          "Gruvbox")     theme="gruvbox" ;;
          "Kanagawa")    theme="kanagawa" ;;
          "Ayu")         theme="ayu" ;;
          "Nord")        theme="nord" ;;
          # Rosé Pine, Dracula, Eldritch use custom themes synced here
          "Rosé Pine")   theme="noctalia-rose-pine" ;;
          "Dracula")     theme="noctalia-dracula" ;;
          "Eldritch")    theme="noctalia-eldritch" ;;
          *) ;;
        esac
      fi

      cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/opencode/tui.json"
      mkdir -p "$(dirname "$cfg")"
      [ -f "$cfg" ] || printf '{}\n' >"$cfg"

      # No-op when already in sync
      if jq -e --arg t "$theme" '.theme == $t' "$cfg" >/dev/null 2>&1; then
        exit 0
      fi

      # write-then-rename so opencode never reads a half-written file
      jq --arg t "$theme" '.theme = $t' "$cfg" >"$cfg.tmp"
      mv -f "$cfg.tmp" "$cfg"
    '';
  };
  syncOpencodeTheme = lib.getExe opencodeThemeSync;

  # Custom OpenCode theme files for palettes without built-in support.
  # These live in ~/.config/opencode/themes/ and override by name.
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

  # One material for all five islands. `padding` here feeds capsule_radius
  # (concentric rule: 8 - 6 = 2), so edit the two together.
  mkGroup = id: members: {
    inherit id members;
    fill = "surface";
    opacity = 0.85;
    padding = 6;
    radius = 8; # matches hypr/hyprland.conf decoration.rounding
  };
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true; # user service, bound to graphical-session.target

    # Seeds ~/.config/noctalia/config.toml (loaded first). The Settings GUI
    # writes ~/.local/state/noctalia/settings.toml, which overrides per-key —
    # so the GUI keeps working; these are just the declarative defaults.
    #
    # GOTCHA: touching bar settings in the GUI copies the WHOLE [bar.default]
    # table into settings.toml, which then shadows everything below and makes
    # edits here look like they did nothing. Strip that section from
    # settings.toml after changing bar geometry.
    settings = {
      # One constant, 8, shared with gaps_out in hypr/hyprland.conf: islands
      # sit 8 from the screen edges (margin_edge / padding), 8 apart
      # (widget_spacing), and 8 above the windows. That last one is free —
      # the exclusive zone ends at the bar, so gaps_out supplies the gap.
      # margin_ends and padding STACK on the main axis, so margin_ends stays 0.
      bar.default = {
        background_opacity = 0.0;
        shadow = false; # a bar-wide shadow rect was the real source of "haze" in the gaps, not blur
        margin_edge = 8;
        margin_ends = 0;
        concave_edge_corners = false; # needs margin_edge = 0, which we float past
        thickness = 30; # stock default is 34; compact DMS-style footprint
        padding = 8; # lane inset: keeps island outer edges on the window grid
        # One knob for both island-to-island and widget-to-widget gaps; there
        # is no separate group-spacing key.
        widget_spacing = 8;
        # stock 0.76 leaves the islands floating inside the strip; 1.0 puts
        # their top edge exactly at margin_edge, on the grid
        capsule_thickness = 1.0;
        # Not just for capsule mode — Noctalia also uses this for the workspace
        # pills nested inside the left island. Concentric radius: the island is
        # 8 with 6 of inner padding, so the pills want 8 - 6 = 2.
        capsule_radius = 2;
        # Lane anchoring decides which islands jitter. `start` is left-anchored
        # and grows rightward, so anything placed after "left" is shoved around
        # every time the active window title changes length. `end` is
        # right-anchored: stats and sys are fixed-width, so the media island's
        # right edge is pinned at a constant x and it grows leftward under its
        # own title only. That is why media sits at the head of `end` -- just
        # right of the centre clock -- and not second-from-left.
        start = [ "group:left" ];
        center = [ "group:mid" ];
        end = [
          "group:media"
          "group:stats"
          "group:sys"
        ];
        capsule_group = [
          (mkGroup "left" [
            "workspaces"
            "active_window"
          ])
          (mkGroup "media" [ "media" ])
          (mkGroup "mid" [ "clock" ])
          (mkGroup "stats" [
            "cpu"
            "ram"
            "cputemp"
          ])
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

      # DMS-style resource indicators (sysmon gauges) + media player display,
      # referenced by the capsule groups above.
      widget = {
        # Fills the dead space between workspaces and the clock. Scrolling
        # titles are a marquee in peripheral vision all day; leave it off.
        active_window = {
          max_length = 260;
          title_scroll = "none";
        };
        media = {
          hide_when_no_media = true;
          max_length = 180;
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
        # Icon only — the SSID/interface name is redundant with the network
        # widget's own hover/expanded view.
        network.show_label = false;
      };

      # Concentric radius: windows are rounding = 8 sitting 8 inside the
      # screen, so the screen's own corner is 8 + 8.
      shell.screen_corners = {
        enabled = true;
        size = 16;
      };

      # Idle policy — Noctalia's own daemon, which replaced hypridle. Every
      # action hypridle took was already a Noctalia one (`noctalia msg session
      # lock`, dpms), so it was a timer wrapped around this; running the timer
      # in-process also removes the logind `Lock` round trip that used to let
      # lock_cmd re-enter itself. Lock-before-suspend needs no key here:
      # Noctalia takes a logind sleep-delay inhibit on PrepareForSleep and
      # locks first, which covers lid close and `systemctl suspend` too.
      #
      # GOTCHA, same as [bar.default] above: opening Settings → Idle in the GUI
      # copies this whole table into ~/.local/state/noctalia/settings.toml,
      # which then shadows everything below.
      idle = {
        # Fades a fullscreen overlay in over this many seconds before the
        # action, cancelling on any input. This is what replaces hypridle's
        # 150s `brightnessctl -s set 10` dim-as-warning listener — and the
        # reason that listener could not just be ported as a custom behavior:
        # the fade is global, so the dim would have drawn an overlay over
        # itself.
        pre_action_fade_seconds = 3.0;

        behavior = {
          # Long timeouts on purpose: this box is left running unattended
          # overnight and through the workday so a phone can reach the
          # sessions on it. Locking is free — it hides the screen without
          # touching anything underneath. Suspending is not, which is why
          # there is no enabled suspend behavior below.
          lock = {
            enabled = true;
            action = "lock";
            timeout = 1800; # 30 min
          };

          # `locked_timeout` is a second, shorter timeout that applies only
          # once the session is already locked — so an unattended machine
          # blanks 2 min after locking rather than sitting lit for another 40.
          "screen-off" = {
            enabled = true;
            action = "screen_off";
            timeout = 2400; # 40 min while unlocked
            locked_timeout = 120; # 2 min once locked
          };

          # Declared and off. Flipping `enabled` is the single edit that stops
          # this machine answering the phone, so it stays visible here rather
          # than being an absent stanza nobody remembers deciding against. The
          # battery backstop is logind's HandleLidSwitch = "suspend"
          # (modules/laptop.nix), which still fires on lid close off AC — on
          # AC it is "ignore", so the lid can stay shut overnight.
          suspend = {
            enabled = false;
            action = "lock_and_suspend";
            timeout = 7200; # 2 h, if ever turned back on
          };
        };
      };


      # Zed and OpenCode follow the palette through their sync hooks (above);
      # `started` covers a fresh login where the palette never changes.
      hooks = {
        started = [ syncZedTheme syncOpencodeTheme ];
        colors_changed = [ syncZedTheme syncOpencodeTheme ];
        theme_mode_changed = [ syncZedTheme syncOpencodeTheme ];
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
          # zed is synced by the hooks above instead of a template.
          community_ids = [ ];
        };
      };
    };
  };

  # A rebuild re-seeds settings.json from home/zed.nix (Nix wins the merge)
  # and `started` doesn't fire on an already-running session — re-sync here so
  # the palette survives `rb` without a re-login. The scripts no-op when the
  # noctalia IPC is down.
  home.activation.zedThemeSync = lib.hm.dag.entryAfter [ "zedSettingsActivation" ] ''
    run ${syncZedTheme} || true
  '';

  home.activation.opencodeThemeSync = lib.hm.dag.entryAfter [ "zedSettingsActivation" ] ''
    run ${syncOpencodeTheme} || true
  '';

  # Custom OpenCode themes for palettes without built-in support.
  xdg.configFile = lib.mapAttrs' (name: value:
    lib.nameValuePair "opencode/themes/${name}" {
      source = pkgs.writeText "${name}" (builtins.toJSON value);
    }
  ) opencodeThemes;
}
