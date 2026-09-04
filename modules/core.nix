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
    git
    vim
    wget
    curl
    pciutils
    usbutils
  ];

  programs.git.enable = true; # `nixos-rebuild --flake` needs git to see the repo

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };
}
