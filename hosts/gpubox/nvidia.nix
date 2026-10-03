{
  pkgs,
  ...
}:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true; # mandatory for Wayland
    powerManagement.enable = true; # save/restore VRAM across suspend
    open = true; # Turing+ only (this is Ada, RTX 4060)
    nvidiaSettings = false; # X11-era, useless under Wayland

    # PRIME sync, not offload: dGPU always on, better sustained perf, worse
    # battery. Bus IDs from `lspci` (decimal): Intel 00:02.0, NVIDIA 01:00.0.
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

  environment.systemPackages = with pkgs; [ nvtopPackages.nvidia ];

  # btop dlopens libnvidia-ml.so.1; cudaSupport adds the /run/opengl-driver
  # runpath that lets it resolve. No CUDA toolkit is pulled in.
  nixpkgs.overlays = [
    (final: prev: { btop = prev.btop.override { cudaSupport = true; }; })
  ];
}
