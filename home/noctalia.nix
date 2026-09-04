{ inputs, ... }:
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true; # user service, bound to graphical-session.target

    # Seeds ~/.config/noctalia/config.toml (loaded first). The Settings GUI
    # writes ~/.local/state/noctalia/settings.toml, which overrides per-key —
    # so the GUI keeps working; these are just the declarative defaults.
    settings = {
      # Glassy islands on an invisible strip: each lane is one shared capsule
      # at 0.85 — the same frosted material as inactive windows
      # (hypr/hyprland.conf inactive_opacity + the noctalia blur layerrule).
      # The layerrule MUST match "noctalia-bar-.*" (the real namespace),
      # not "noctalia" alone, or blur silently never applies to the bar.
      # v5.0.1 has no active-window/window-title widget; add it to "left" when
      # the noctalia input gets bumped past this tag.
      bar.default = {
        background_opacity = 0.0;
        shadow = false; # a bar-wide shadow rect was the real source of "haze" in the gaps, not blur
        margin_edge = 4;
        margin_ends = 8;
        concave_edge_corners = false; # needs margin_edge = 0, which we float past
        thickness = 30; # stock default is 34; compact DMS-style footprint
        padding = 9;
        widget_spacing = 5;
        capsule_padding = 5.0;
        start = [ "group:left" ];
        center = [ "group:mid" ];
        end = [
          "group:stats"
          "group:sys"
        ];
        capsule_group = [
          {
            id = "left";
            members = [
              "workspaces"
              "media"
            ];
            fill = "surface";
            opacity = 0.85;
          }
          {
            id = "mid";
            members = [ "clock" ];
            fill = "surface";
            opacity = 0.85;
          }
          {
            id = "stats";
            members = [
              "cpu"
              "ram"
              "cputemp"
              "volume"
              "battery"
            ];
            fill = "surface";
            opacity = 0.85;
          }
          {
            id = "sys";
            members = [
              "tray"
              "network"
              "bluetooth"
              "control-center"
            ];
            fill = "surface";
            opacity = 0.85;
          }
        ];
      };

      # DMS-style resource indicators (sysmon gauges) + media player display,
      # referenced by the capsule groups above.
      widget = {
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
          # Community template: writes ~/.config/nvim/lua/matugen.lua on every
          # palette change and SIGUSR1s running nvims — the other half lives in
          # home/lazyvim.nix (base16-nvim colorscheme that reads that file).
          community_ids = [ "neovim" ];
        };
      };
    };
  };
}
