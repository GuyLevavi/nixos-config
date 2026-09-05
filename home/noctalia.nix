{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  # Noctalia picks *which colorscheme plugin* nvim uses, not its colours. Run
  # from the hooks below; the reading half is home/lazyvim.nix.
  nvimThemeSync = pkgs.writeShellApplication {
    name = "noctalia-nvim-theme";
    runtimeInputs = [ config.programs.noctalia.package ];
    text = ''
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/noctalia"
      out="$state_dir/nvim-theme.lua"

      # "<source> <name>", e.g. "builtin Tokyo-Night". Empty when the IPC
      # socket isn't up yet, in which case the fallbacks below stand.
      line="$(noctalia msg color-scheme-get 2>/dev/null || true)"
      scheme_source="''${line%% *}"
      scheme_name="''${line#* }"

      mode="$(noctalia msg theme-mode-get 2>/dev/null || true)"
      [ "$mode" = "light" ] || mode="dark"

      dark="tokyonight-night"
      light="tokyonight-day"

      # Only builtins map; wallpaper/community/custom palettes have no
      # equivalent plugin and keep the tokyonight fallback. Nord, Dracula and
      # Eldritch have no light variant upstream, so they fall back in light.
      if [ "$scheme_source" = "builtin" ]; then
        case "$scheme_name" in
          "Tokyo-Night") dark="tokyonight-night"; light="tokyonight-day" ;;
          "Catppuccin")  dark="catppuccin-mocha"; light="catppuccin-latte" ;;
          "Gruvbox")     dark="gruvbox";          light="gruvbox" ;;
          "Kanagawa")    dark="kanagawa-wave";    light="kanagawa-lotus" ;;
          "Rosé Pine")   dark="rose-pine-main";   light="rose-pine-dawn" ;;
          "Ayu")         dark="ayu-dark";         light="ayu-light" ;;
          "Nord")        dark="nord";             light="tokyonight-day" ;;
          "Dracula")     dark="dracula";          light="tokyonight-day" ;;
          "Eldritch")    dark="eldritch";         light="tokyonight-day" ;;
          *) ;;
        esac
      fi

      if [ "$mode" = "light" ]; then scheme="$light"; else scheme="$dark"; fi

      mkdir -p "$state_dir"
      # write-then-rename so nvim never dofile()s a half-written file
      printf 'return { colorscheme = "%s", background = "%s" }\n' "$scheme" "$mode" >"$out.tmp"
      mv -f "$out.tmp" "$out"
    '';
  };
  syncNvimTheme = lib.getExe nvimThemeSync;

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

      # Noctalia picks the colorscheme *plugin* nvim uses. `started` covers a
      # fresh login even when the palette never changes; the other two cover
      # palette and light/dark switches. See home/lazyvim.nix for the reader.
      hooks = {
        started = [ syncNvimTheme ];
        colors_changed = [ syncNvimTheme ];
        theme_mode_changed = [ syncNvimTheme ];
      };

      theme = {
        builtin = "Tokyo-Night";
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
          # No "neovim" template: a tonal palette has one hue and base16 needs
          # eight. The hooks above pick a real colorscheme plugin instead.
          community_ids = [ ];
        };
      };
    };
  };
}
