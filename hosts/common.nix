# hosts/common.nix — system config shared by nixbox and gamingbox.
{ pkgs, ... }:
{
  # ── Boot / network ─────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.networkmanager.enable = true;

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  time.timeZone = "Asia/Jerusalem";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Desktop: Hyprland ──────────────────────────────────────────────────
  # Compositor only (nixpkgs module — keeps flake at 2 inputs). The shell
  # around it (bar, clipboard, screenshots, notifications, lock) lives in
  # home/gui.nix. To track Hyprland's bleeding edge instead, add the
  # hyprland flake input and set programs.hyprland.package — but the
  # nixpkgs build is what avoids config-breaking surprises.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # DankMaterialShell: bar (incl. MPRIS media widget), launcher, clipboard
  # history UI, notifications, lock, OSDs, wallpaper — one module.
  # Auto-starts via its systemd user service: do NOT exec-once it.
  programs.dms-shell.enable = true;

  # Login manager: greetd + tuigreet (tiny, reliable, no dbus quirks).
  # initial_session auto-logs in as gl straight into Hyprland; falls back to
  # the tuigreet prompt (default_session) after that session ends.
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
      initial_session = {
        command = "Hyprland";
        user = "gl";
      };
    };
  };

  # Portals for screenshots + file pickers under Hyprland.
  # Without xdg.portal.config, xdg-desktop-portal (1.17+) has no routing table
  # and interfaces the hyprland backend doesn't implement (e.g. Settings, used
  # by libadwaita apps like Nautilus to read the dark-mode preference) just
  # fail instead of falling back to gtk.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "hyprland" "gtk" ];
  };

  # ── Audio / bluetooth ──────────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;
  hardware.bluetooth = { enable = true; powerOnBoot = true; };
  services.upower.enable = true;

  # ── Containers ─────────────────────────────────────────────────────────
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
    autoPrune = { enable = true; dates = "weekly"; };
  };

  # ── User ───────────────────────────────────────────────────────────────
  programs.fish.enable = true;
  users.users.gl = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "podman" ];
  };

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

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];

  system.stateVersion = "25.05";
}
