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


      # Zed follows the palette through zedThemeSync (above); `started`
      # covers a fresh login where the palette never changes.
      hooks = {
        started = [ syncZedTheme ];
        colors_changed = [ syncZedTheme ];
        theme_mode_changed = [ syncZedTheme ];
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
  # the palette survives `rb` without a re-login. The script no-ops when the
  # noctalia IPC is down.
  home.activation.zedThemeSync = lib.hm.dag.entryAfter [ "zedSettingsActivation" ] ''
    run ${syncZedTheme} || true
  '';
}
