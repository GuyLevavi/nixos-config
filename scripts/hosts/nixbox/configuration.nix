# hosts/nixbox/configuration.nix
# nixbox-specific system config. Shared config is in ../common/laptop.nix.
{ config, lib, pkgs, ... }:
{
  imports = [
    ../common/laptop.nix
    ./hardware-configuration.nix
  ];

  # ── Identity ──────────────────────────────────────────────────────────
  networking.hostName = "nixbox";

  # ── Intel iGPU — hardware acceleration ────────────────────────────────
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libvdpau-va-gl
    ];
  };
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  system.stateVersion = "25.05";
}
