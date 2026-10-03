{
  pkgs,
  username,
  hostName,
  ...
}:
{
  boot = {
    loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 10;
      efi.canTouchEfiVariables = true;
    };
    tmp.cleanOnBoot = true; # else /tmp persists
  };

  # Compressed in-RAM swap on both boxes: gpubox has none and cpubox's is a
  # slow partition, so a memory spike under Steam would OOM-kill rather than stall.
  zramSwap.enable = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    trusted-users = [ username ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nixpkgs.config.allowUnfree = true;

  networking.hostName = hostName;
  networking.networkmanager.enable = true;
  time.timeZone = "Asia/Jerusalem";

  # bash as login shell (POSIX for scripts/sudo/systemd); fish is layered on
  # in home/shell.nix.
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    shell = pkgs.bash;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
    ];
  };

  environment.systemPackages = with pkgs; [
    # git is NOT listed here: programs.git.enable below already installs it.
    vim
    wget
    curl
    pciutils
    usbutils
  ];

  programs.git.enable = true; # `nixos-rebuild --flake` needs git to see the repo

  # openssh is off on purpose — it was open on port 22 with no authorizedKeys
  # anywhere. Only re-enable in the same commit that adds a key.
  services.openssh.enable = false;
}
