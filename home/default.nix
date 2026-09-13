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
    ./zed.nix
    ./apps.nix
    ./scripts.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.05";
  };

  # Ownership rule: Noctalia rewrites GTK/Qt/terminal/Firefox colours at runtime
  # on theme switch, so home-manager must not own those files. Hence no Stylix,
  # and gtk/qt stay disabled. The pointer cursor is ours (home/programs.nix) —
  # Noctalia has no cursor feature.
  gtk.enable = false;
  qt.enable = false;

  xdg = {
    # hypr/*.conf are symlinked to the working tree, not the store: edit and
    # `hyprctl reload`, no rebuild. The only files in the repo that work this way.
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
