# home/gamingbox.nix — gamingbox home-manager overrides.
# Imports gui.nix and adds machine-specific display + NVIDIA env config.
{ lib, pkgs, ... }:
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
      env = WLR_NO_HARDWARE_CURSORS,1
      # GBM_BACKEND=nvidia-drm intentionally omitted: modern NVIDIA drivers (520+)
      # handle GBM correctly without it, and it breaks Chrome/Electron apps.
    ''
  );

  # ── LD_LIBRARY_PATH: libstdc++ (from gui.nix) + NVIDIA runtime libs ──
  # gui.nix sets LD_LIBRARY_PATH to stdenv.cc.cc.lib for libstdc++.so.6.
  # gamingbox additionally needs /run/opengl-driver/lib for:
  #   - libnvidia-ml.so  (btop GPU stats, press 5)
  #   - libcuda.so       (torch.cuda.is_available())
  home.sessionVariables.LD_LIBRARY_PATH = lib.mkForce
    "${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib:/run/opengl-driver/lib";

  # ── Kanshi: 144Hz external monitor ────────────────────────────────────
  # nixbox (Intel UHD) was limited to 120Hz on this same external monitor.
  # gamingbox has Intel Alder Lake-P with HDMI 2.0 — should support 144Hz.
  # If display negotiation fails (black screen after hotplug), change @144 → @120.
  # lib.mkForce replaces the entire settings list from gui.nix.
  services.kanshi.settings = lib.mkForce [
    {
      profile.name = "external";
      profile.outputs = [
        { criteria = "HDMI-A-1"; status = "enable"; position = "0,0"; mode = "1920x1080@144"; }
        { criteria = "eDP-1"; status = "disable"; }
      ];
      profile.exec = [ "systemctl --user restart waybar hyprpaper" ];
    }
    {
      profile.name = "internal";
      profile.outputs = [
        { criteria = "eDP-1"; status = "enable"; position = "0,0"; }
      ];
      profile.exec = [ "systemctl --user restart waybar hyprpaper" ];
    }
  ];
}
