{
  config,
  username,
  ...
}:
{
  imports = [
    ./noctalia.nix
    ./programs.nix
    ./shell.nix
    ./tmux.nix
    ./skills.nix
    ./zed.nix
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
    # hypr/*.conf are symlinked to the working tree: edit + `hyprctl reload`,
    # no rebuild. The only files in the repo that work this way.
    configFile."hypr/hyprland.conf".source =
      config.lib.file.mkOutOfStoreSymlink "/etc/nixos/hypr/hyprland.conf";
    configFile."hypr/binds.conf".source =
      config.lib.file.mkOutOfStoreSymlink "/etc/nixos/hypr/binds.conf";

    userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = true; # keep pre-25.05 behaviour (export XDG_*_DIR)
    };
  };
}
