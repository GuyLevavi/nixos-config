# hosts/common/laptop.nix — shared system config for all laptops.
# Imported by each host's configuration.nix alongside hardware-configuration.nix.
{ config, lib, pkgs, ... }:
{
  # ── Boot ──────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Network ───────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;

  # ── Lid close behavior ────────────────────────────────────────────────
  services.logind.settings.Login = {
    HandleLidSwitch              = "ignore";
    HandleLidSwitchDocked        = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  # ── Locale & timezone ─────────────────────────────────────────────────
  time.timeZone = "Asia/Jerusalem";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Display manager: SDDM (Wayland) ───────────────────────────────────
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # ── Desktop: Hyprland ─────────────────────────────────────────────────
  programs.hyprland.enable = true;

  programs.uwsm = {
    enable = true;
    waylandCompositors.hyprland = {
      prettyName = "Hyprland";
      comment     = "Hyprland compositor managed by uwsm";
      binPath     = "/run/current-system/sw/bin/Hyprland";
    };
  };

  # ── Chrome: Catppuccin Mocha theme via system policy ──────────────────
  programs.chromium = {
    enable = true;
    extensions = [
      "bkkmolkhemgaeaeggcmfbghljjjoofoh;https://clients2.google.com/service/update2/crx"
    ];
  };

  # ── Audio: PipeWire ───────────────────────────────────────────────────
  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true;
    pulse.enable      = true;
  };
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  # ── Bluetooth ─────────────────────────────────────────────────────────
  hardware.bluetooth = {
    enable      = true;
    powerOnBoot = true;
  };
  services.blueman.enable = false;

  # ── Polkit ────────────────────────────────────────────────────────────
  security.polkit.enable = true;

  # ── Podman ────────────────────────────────────────────────────────────
  virtualisation.podman = {
    enable       = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
    autoPrune = { enable = true; dates = "weekly"; };
  };

  # ── User ──────────────────────────────────────────────────────────────
  users.users.gl = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" "video" "audio" "podman" ];
    shell        = pkgs.bash;
  };

  # ── Unfree packages ───────────────────────────────────────────────────
  nixpkgs.config.allowUnfree = true;

  # ── System packages ───────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git vim wget curl pciutils usbutils claude-code gh
  ];

  # ── Fonts ─────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    noto-fonts
    noto-fonts-color-emoji
  ];
  fonts.fontconfig = {
    subpixel.rgba = "rgb";
    hinting.style = "medium";
  };

  # ── nix-ld: run FHS entry-point binaries (bundled uv, node, etc.) ────
  # Replaces the stub /lib64/ld-linux-x86-64.so.2 with a real linker so
  # pre-built FHS ELF binaries (e.g. VSCode extension bundled uv) can run.
  # NOTE: nix-ld only applies to entry-point binaries. pip-installed .so
  # files loaded via dlopen() inside Python need LD_LIBRARY_PATH instead
  # (set in gui.nix home.sessionVariables).
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib  # libstdc++.so.6
      zlib              # libz.so.1
    ];
  };

  # ── Nix ───────────────────────────────────────────────────────────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store   = true;
  };
  nix.gc = {
    automatic = true;
    dates     = "weekly";
    options   = "--delete-older-than 14d";
  };

  # ── /etc/nixos write permissions ──────────────────────────────────────
  # Declarative fix: makes wheel-group members (gl) able to edit /etc/nixos
  # without sudo. Runs on every nixos-rebuild switch. Replaces the old
  # imperative chown that didn't survive new machine setup.
  system.activationScripts.nixosConfigPermissions = {
    text = ''
      chown -R root:wheel /etc/nixos
      chmod -R g+rw /etc/nixos
      find /etc/nixos -type d -exec chmod g+x {} +
    '';
    deps = [];
  };
}
