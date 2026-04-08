# hosts/gamingbox/configuration.nix
# gamingbox-specific system config (NVIDIA RTX 4060, Intel Alder Lake-P).
# Shared config is in ../common/laptop.nix.
{ config, lib, pkgs, ... }:
{
  imports = [
    ../common/laptop.nix
    ./hardware-configuration.nix
  ];

  # ── Identity ──────────────────────────────────────────────────────────
  networking.hostName = "gamingbox";

  # ── NVIDIA RTX 4060 + Intel Iris Xe — PRIME Sync ──────────────────────
  # PRIME Sync: Intel iGPU handles display output; NVIDIA renders.
  # Best for simultaneous 165Hz internal + 144Hz external + CUDA.
  # Bus IDs from `lspci`: Intel 0000:00:02.0 → PCI:0:2:0
  #                       NVIDIA 0000:01:00.0 → PCI:1:0:0
  hardware.nvidia = {
    modesetting.enable          = true;   # required for Wayland/Hyprland
    powerManagement.enable      = false;  # not needed with PRIME Sync
    powerManagement.finegrained = false;
    open                        = false;  # proprietary driver — required for CUDA
    nvidiaSettings              = true;   # includes nvidia-smi
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      sync.enable = true;
      intelBusId  = "PCI:0:2:0";   # Intel Iris Xe (Alder Lake-P)
      nvidiaBusId = "PCI:1:0:0";   # RTX 4060 Max-Q
    };
  };

  # Intel iGPU for display output path (PRIME Sync routes through Intel)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libvdpau-va-gl
    ];
  };

  # ── CUDA tools ────────────────────────────────────────────────────────
  # cudatoolkit: nvcc + headers for custom CUDA extensions / cmake CUDA projects.
  # nvtop: GPU monitoring TUI (VRAM, utilisation, temp).
  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    nvtopPackages.nvidia
  ];

  system.stateVersion = "25.05";
}
