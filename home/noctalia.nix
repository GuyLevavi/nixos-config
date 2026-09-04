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
