{
  config,
  pkgs,
  ...
}:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true; # mandatory for Wayland
    powerManagement.enable = true; # save/restore VRAM across suspend
    open = true; # fine for Turing+ (this is Ada, RTX 4060)
    nvidiaSettings = false; # X11-era, useless under Wayland
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # PRIME sync, not offload: dGPU always on, no nvidia-offload wrapper, better
    # sustained gaming perf, at the cost of idle battery. Bus IDs from
    # `lspci | grep -E 'VGA|3D'` (decimal): Intel 00:02.0, NVIDIA 01:00.0.
    prime = {
      sync.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    vpl-gpu-rt
    nvidia-vaapi-driver
  ];

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia"; # sync mode: video accel targets the dGPU too
    NVD_BACKEND = "direct";
  };

  # No WLR_NO_HARDWARE_CURSORS / __GL_GSYNC_ALLOWED etc — explicit sync (555+
  # driver + modern Hyprland) made that folklore useless-to-harmful.

  environment.systemPackages = with pkgs; [ nvtopPackages.nvidia ];
}
