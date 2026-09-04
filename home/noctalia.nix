{ inputs, ... }:
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true; # user service, bound to graphical-session.target

    # Empty on purpose: Noctalia's settings GUI writes its own config, and a
    # populated `settings` here would make that a read-only store symlink.
    settings = { };
  };
}
