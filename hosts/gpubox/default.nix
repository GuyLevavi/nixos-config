{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
    ../../modules/core.nix
    ../../modules/desktop.nix
    ../../modules/laptop.nix
  ];

  # Graphics all lives in ./nvidia.nix — the diff vs cpubox is ~one import.

  programs.steam.enable = true;
  programs.gamemode.enable = true;

  system.stateVersion = "25.05"; # install-time pin, never bump
}
