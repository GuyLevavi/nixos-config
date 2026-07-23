# hosts/gamingbox — RTX 4060 + Intel Iris Xe laptop. Gaming + CUDA dev.
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];
  networking.hostName = "gamingbox";

  # ── NVIDIA PRIME Sync — Intel drives displays, NVIDIA renders ─────────
  # Bus IDs from `lspci`: Intel 0000:00:02.0, NVIDIA 0000:01:00.0.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true; # required for Wayland
    open = true; # open kernel modules — recommended for RTX 20-series+ (Turing+); CUDA works
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      sync.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver libvdpau-va-gl ];
  };

  # ── Gaming ─────────────────────────────────────────────────────────────
  programs.steam.enable = true; # Proton included
  programs.gamemode.enable = true;

  # ── CUDA / pip+torch dev ───────────────────────────────────────────────
  # User-level env (LD_LIBRARY_PATH) and Hyprland NVIDIA hints live in
  # home/gamingbox.nix. nix-ld (hosts/common.nix) handles FHS entry-point binaries.
  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    nvtopPackages.nvidia
  ];
}
