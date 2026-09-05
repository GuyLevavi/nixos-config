{
  pkgs,
  username,
  hostName,
  ...
}:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.tmp.cleanOnBoot = true; # /tmp otherwise accumulates across reboots

  # gpubox has swapDevices = [ ] and cpubox's is a slow disk partition, so give
  # the kernel a compressed in-RAM pressure valve on both. Without any swap a
  # memory spike under Steam is a straight OOM kill rather than a stall.
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
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # bash is the login shell so scripts/sudo -s/systemd stay POSIX; fish is
  # layered on per-session in home/shell.nix.
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

  # openssh is deliberately OFF. It was enabled with PasswordAuthentication
  # disabled and no authorizedKeys anywhere in the repo, so port 22 was open on
  # two roaming laptops with no key that could actually log in — attack surface
  # for zero capability. Re-enable it together with
  # `users.users.${username}.openssh.authorizedKeys.keys`, never on its own.
  services.openssh.enable = false;
}
