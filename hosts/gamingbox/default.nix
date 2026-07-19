# hosts/gamingbox — RTX 4060 + Intel Iris Xe laptop. Gaming + CUDA dev.
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];
  networking.hostName = "gamingbox";

  # ── NVIDIA PRIME Sync — Intel drives displays, NVIDIA renders ─────────
  # Bus IDs from `lspci`: Intel 0000:00:02.0, NVIDIA 0000:01:00.0.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;    # required for Wayland
    open = true;                  # open kernel modules — recommended for RTX 20-series+ (Turing+); CUDA works
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
  programs.steam.enable = true;       # Proton included
  programs.gamemode.enable = true;

  # ── CUDA / pip+torch dev ───────────────────────────────────────────────
  # nix-ld (common.nix) handles FHS entry-point binaries. pip-installed .so
  # files loaded from *inside* Python additionally need LD_LIBRARY_PATH.
  # If a new pip package fails with "libXXX.so.N not found":
  #   ldd .venv/lib/python3.*/site-packages/<pkg>/*.so | grep "not found"
  # then add the owning nixpkgs lib to programs.nix-ld.libraries + here.
  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    nvtopPackages.nvidia
  ];
  home-manager.users.gl.home.sessionVariables.LD_LIBRARY_PATH =
    "${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib:/run/opengl-driver/lib";

  # Hyprland on NVIDIA: cursor + backend hints. If you ever see an invisible
  # cursor, uncomment the software-cursors line in Hyprland (wiki: NVIDIA).
  home-manager.users.gl.wayland.windowManager.hyprland.settings.env = [
    "LIBVA_DRIVER_NAME,nvidia"
    "GBM_BACKEND,nvidia-drm"
    "__GLX_VENDOR_LIBRARY_NAME,nvidia"
  ];
}
