# hosts/common.nix — system config shared by nixbox and gamingbox.
{ pkgs, ... }:
{
  # ── Boot / network ─────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.networkmanager.enable = true;

  # Docked-lid behavior: never sleep on lid close.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  time.timeZone = "Asia/Jerusalem";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Desktop: COSMIC ────────────────────────────────────────────────────
  # Full DE from nixpkgs: compositor, panel, launcher, lock, notifications,
  # settings GUI, files, terminal. Settings are managed in the COSMIC
  # Settings app; snapshot them to this repo with `cosmic-save` (base.nix).
  services.desktopManager.cosmic = {
    enable = true;
    xwayland.enable = true;
  };
  services.displayManager.cosmic-greeter.enable = true;

  # System76's scheduler — desktop responsiveness boost (any hardware).
  services.system76-scheduler.enable = true;

  # Flatpak backs the COSMIC Store. One-time: flatpak remote-add --user \
  #   flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  services.flatpak.enable = true;

  # Clipboard *history* (copy/paste itself needs none of this):
  # the applet must come from nixpkgs (Store/Flatpak version can't reach the
  # data-control protocol), and the protocol must be opted into. Tradeoff:
  # with this var set, ALL apps can read the clipboard, not just the focused
  # one. Then: Settings → Desktop → Panel → Configure applets → add it.
  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = "1";

  # ── Audio / bluetooth ──────────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;
  hardware.bluetooth = { enable = true; powerOnBoot = true; };

  # ── Containers ─────────────────────────────────────────────────────────
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
    autoPrune = { enable = true; dates = "weekly"; };
  };

  # ── User ───────────────────────────────────────────────────────────────
  programs.fish.enable = true; # registers fish as a valid login shell
  users.users.gl = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "podman" ];
  };

  # ── nix-ld: lets pre-built FHS binaries run (downloaded tools, uv, etc.)
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [ stdenv.cc.cc.lib zlib ];
  };

  # ── Nix / nixpkgs ──────────────────────────────────────────────────────
  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 14d"; };

  environment.systemPackages = with pkgs; [ git vim wget curl pciutils usbutils ];
  # Clipboard history applet is built into cosmic-applets; COSMIC_DATA_CONTROL_ENABLED enables it.

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];

  system.stateVersion = "25.05"; # do not change after install
}
