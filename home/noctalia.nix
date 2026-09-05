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

  # Every island shares one material, so define it once. Change the fill or the
  # opacity here and all five move together; `padding = 6` is also what
  # capsule_radius is derived from (see the concentric-radius note below), so
  # the two must be edited as a pair.
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
      # Glassy islands on an invisible strip: each lane is one shared capsule
      # at 0.85 — the same frosted material as inactive windows
      # (hypr/hyprland.conf inactive_opacity + the noctalia blur layerrule).
      # The layerrule MUST match "noctalia-bar-.*" (the real namespace),
      # not "noctalia" alone, or blur silently never applies to the bar.
      #
      # Geometry runs on two constants, and which one applies is meaningful:
      #   4 = ALIGNMENT. Things that should sit on the same grid line as window
      #       content: margin_edge, this bar's `padding`, and gaps_out in
      #       hypr/hyprland.conf (with gaps_in=2, since gaps_in is a half-gap).
      #       Measured result: the leftmost island's left edge and the window
      #       frame's left edge both land on logical x = 4.
      #   8 = SEPARATION. Things that should read as distinctly apart:
      #       widget_spacing (island-to-island), margin_opposite_edge
      #       (bar-to-window), decoration.rounding, and the island radius.
      # So 4 never separates and 8 never aligns. Do not collapse them back into
      # one number -- that is what made the bar read as a single dark slab.
      # margin_ends and padding STACK on the main axis, so the outermost island
      # sits at margin_ends + padding from the screen edge — margin_ends must
      # be 0 for that to come out at 4. Zeroing it costs nothing visually since
      # background_opacity is 0, and it leaves the whole strip right-clickable.
      bar.default = {
        background_opacity = 0.0;
        shadow = false; # a bar-wide shadow rect was the real source of "haze" in the gaps, not blur
        margin_edge = 4;
        margin_ends = 0;
        # The ONE deliberate exception to the 4px rule, and it is a perceptual
        # fix rather than a geometric one. This adds to the layer's exclusive
        # zone without moving the bar surface, so the bar-to-window gap becomes
        # margin_opposite_edge + gaps_out = 8 (the separation constant) while
        # every window-to-window gap stays 4. Two reasons for the break: (a) chrome-to-content deserves a
        # louder separator than content-to-content, and (b) at 4px the window
        # shadow (hyprland.conf range = 12, ramping ~5px) swallowed the gap
        # whole -- measured peak brightness in the band was 75% of the wallpaper
        # at 0, 89% at 2, and 97% at 4, which is the first value where actual
        # wallpaper reads as wallpaper instead of shadow murk.
        margin_opposite_edge = 4;
        concave_edge_corners = false; # needs margin_edge = 0, which we float past
        thickness = 30; # stock default is 34; compact DMS-style footprint
        padding = 4; # lane inset: keeps island outer edges on the window grid
        # One knob for BOTH island-to-island and widget-to-widget gaps -- there
        # is no separate group-spacing key, so raising this lets the whole bar
        # breathe at once. 4 had the islands nearly touching and reading as one
        # slab; 8 separates them without the loose feel 12/16 give.
        widget_spacing = 8;
        # stock 0.76 leaves the islands floating inside the strip; 1.0 puts
        # their top edge exactly at margin_edge so the 4px system holds
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

      # Concentric radius again: windows are rounding = 8 sitting 4 inside the
      # screen, so the screen's own corner is 8 + 4. Noctalia's default of 32
      # would be badly wrong here.
      shell.screen_corners = {
        enabled = true;
        size = 12;
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
          # The community "neovim" template used to live here. It rendered a
          # matugen palette into base16-nvim's sixteen semantic slots, which
          # collapses: base09 (constants/orange) came out green, base0B
          # (strings/green) came out blue, and functions/keywords/types all
          # landed on near-identical blue-purples. Replaced by the hooks above.
          community_ids = [ ];
        };
      };
    };
  };
}
