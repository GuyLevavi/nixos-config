# home/gamingbox.nix — gamingbox home-manager overrides.
# Imports gui.nix and adds machine-specific display + NVIDIA env config.
{ lib, ... }:
{
  imports = [ ./gui.nix ];

  # ── Hyprland: gamingbox monitor + NVIDIA env ───────────────────────────
  # lib.mkForce overrides gui.nix extraConfig (builtins.readFile of hyprland.conf).
  # The shared config is prepended; gamingbox-specific lines appended after.
  wayland.windowManager.hyprland.extraConfig = lib.mkForce (
    builtins.readFile ../config/hypr/hyprland.conf + "\n" + ''
      # ── gamingbox: 2K 165Hz internal display ──────────────────────────
      # 1.25x scale: 2560x1440 native → ~2048x1152 logical (crisp at laptop size)
      monitor = eDP-1,2560x1440@165,0x0,1.25

      # ── NVIDIA PRIME Sync environment ─────────────────────────────────
      # GBM_BACKEND=nvidia-drm: use NVIDIA DRM buffer management for Wayland
      # __GLX_VENDOR_LIBRARY_NAME=nvidia: force GLVND to NVIDIA
      # LIBVA_DRIVER_NAME=nvidia: NVDEC hardware video acceleration
      # WLR_NO_HARDWARE_CURSORS=1: prevents cursor artifacts common on PRIME setups
      env = LIBVA_DRIVER_NAME,nvidia
      env = __GLX_VENDOR_LIBRARY_NAME,nvidia
      env = GBM_BACKEND,nvidia-drm
      env = WLR_NO_HARDWARE_CURSORS,1
    ''
  );

  # ── btop: NVIDIA GPU monitoring ───────────────────────────────────────
  # btop needs libnvidia-ml.so to show GPU stats (press 5 in btop).
  # In NixOS, NVIDIA runtime libs live in /run/opengl-driver/lib/.
  home.sessionVariables.LD_LIBRARY_PATH = "/run/opengl-driver/lib";

  # ── Kanshi: 144Hz external monitor ────────────────────────────────────
  # nixbox (Intel UHD) was limited to 120Hz on this same external monitor.
  # gamingbox has Intel Alder Lake-P with HDMI 2.0 — should support 144Hz.
  # If display negotiation fails (black screen after hotplug), change @144 → @120.
  services.kanshi.profiles.external.outputs = lib.mkForce [
    { criteria = "HDMI-A-1"; status = "enable"; position = "0,0"; mode = "1920x1080@144"; }
    { criteria = "eDP-1";    status = "disable"; }
  ];
}
