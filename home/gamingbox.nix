# home/gamingbox.nix — gamingbox home-manager overrides.
# Imports gui.nix and adds machine-specific display + NVIDIA env config.
{ lib, pkgs, ... }:
{
  imports = [ ./gui.nix ];

  # ── Hyprland: gamingbox monitor + NVIDIA env ───────────────────────────
  wayland.windowManager.hyprland.settings = {
    # 2K 165Hz internal display; 1.25x scale: 2560x1440 native → ~2048x1152 logical.
    monitor = lib.mkForce "eDP-1,2560x1440@165,0x0,1.25";

    # NVIDIA PRIME Sync environment hints.
    env = [
      "LIBVA_DRIVER_NAME,nvidia"
      "GBM_BACKEND,nvidia-drm"
      "__GLX_VENDOR_LIBRARY_NAME,nvidia"
      "WLR_NO_HARDWARE_CURSORS,1"
    ];
  };

  # ── LD_LIBRARY_PATH: append NVIDIA libs for CUDA + NVML ────────────────
  # Overrides the base libs set in gui.nix on gamingbox only.
  home.sessionVariables.LD_LIBRARY_PATH = lib.mkForce
    "${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib:/run/opengl-driver/lib";

  # ── Kanshi: 144Hz external monitor ────────────────────────────────────
  # nixbox (Intel UHD) was limited to 120Hz on this same external monitor.
  # gamingbox has Intel Alder Lake-P with HDMI 2.0 — should support 144Hz.
  # If display negotiation fails (black screen after hotplug), change @144 → @120.
  services.kanshi.settings = lib.mkForce [
    {
      profile = {
        name = "external";
        outputs = [
          { criteria = "HDMI-A-1"; status = "enable"; position = "0,0"; mode = "1920x1080@144"; }
          { criteria = "eDP-1"; status = "disable"; }
        ];
        exec = [ "systemctl --user restart waybar hyprpaper" ];
      };
    }
    {
      profile = {
        name = "internal";
        outputs = [
          { criteria = "eDP-1"; status = "enable"; position = "0,0"; }
        ];
        exec = [ "systemctl --user restart waybar hyprpaper" ];
      };
    }
  ];
}
