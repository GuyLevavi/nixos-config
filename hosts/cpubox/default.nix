{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core.nix
    ../../modules/desktop.nix
    ../../modules/laptop.nix
  ];

  # Integrated graphics only — just the userspace video acceleration stack.
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    vpl-gpu-rt
  ];
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  system.stateVersion = "25.05"; # install-time pin, never bump
}
