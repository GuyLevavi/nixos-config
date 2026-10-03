{
  config,
  username,
  ...
}:
let
  # Live files: symlinked to the working tree, so edits need no rebuild. Targets
  # must be absolute strings — a path literal would copy into the store instead.
  live = path: config.lib.file.mkOutOfStoreSymlink "/etc/nixos/${path}";
in
{
  imports = [
    ./noctalia.nix
    ./programs.nix
    ./shell.nix
    ./tmux.nix
    ./skills.nix
    ./zed.nix
    ./neovim.nix
    ./apps.nix
    ./scripts.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.05";
  };

  # Noctalia rewrites GTK/Qt/terminal/Firefox colours at runtime, so no Stylix
  # and gtk/qt stay disabled (README "Who owns what"); the cursor is ours.
  gtk.enable = false;
  qt.enable = false;

  xdg = {
    configFile = {
      "hypr/hyprland.conf".source = live "hypr/hyprland.conf";
      "hypr/binds.conf".source = live "hypr/binds.conf";
      "nvim".source = live "nvim";
      "tmux/tmux.conf".source = live "tmux/tmux.conf";
      "opencode/opencode.jsonc".source = live "opencode/opencode.jsonc";
      "opencode/tui.json".source = live "opencode/tui.json";
    } // builtins.listToAttrs (map (name: {
      name = "opencode/skills/${name}";
      value.source = live "skills/${name}";
    }) [
      "coordinator"
      "merge"
      "open-pr"
      "rebase"
      "workmux"
      "worktree"
    ]);

    userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = true; # keep pre-25.05 behaviour (export XDG_*_DIR)
    };
  };
}
