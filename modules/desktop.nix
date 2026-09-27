{
  pkgs,
  inputs,
  ...
}:
let
  # Pinned AMO-signed archive: pkgs.fetchFirefoxAddon rewrites manifest.json,
  # which breaks signing, and release Firefox refuses unsigned add-ons. Bump
  # file id, version and hash together from the AMO API.
  vimium = pkgs.fetchurl {
    name = "vimium-2.4.2.xpi";
    url = "https://addons.mozilla.org/firefox/downloads/file/4717567/vimium_ff-2.4.2.xpi";
    hash = "sha256-Ex4qZ1gOeukSWrGXgRWeYUCfrEe0Qfwngqq3Y5bq0ZY=";
  };
in
{
  imports = [ inputs.noctalia.nixosModules.default ];

  # Pulls in the wayland session desktop file, portals, xwayland, polkit and
  # hardware.graphics; UWSM gives graphical-session.target, which the Noctalia
  # user service needs.
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  programs.noctalia = {
    enable = true;
    recommendedServices.enable = true; # NetworkManager, bluetooth, upower, ppd (all mkDefault)
    systemd.enable = false; # the user service in home/noctalia.nix owns this
  };

  # programs.firefox (not the extension module) for `policies` — the only
  # declarative add-on install without NUR. It writes /etc/firefox, so Noctalia
  # keeps the profile. Vimium's settings live in chrome.storage.sync and are
  # not seedable; set them once in its options page.
  programs.firefox = {
    enable = true;
    policies.ExtensionSettings."{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
      install_url = "file://${vimium}";
      installation_mode = "force_installed"; # arrives enabled, no approval prompt
    };
  };

  services = {
    greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start hyprland-uwsm.desktop'";
        user = "greeter";
      };
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # Driverless IPP/AirPrint over mDNS; add drivers only for an old model.
    # NOTE: openFirewall opens UDP 5353 — the only port this config opens.
    printing.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    gvfs.enable = true; # Nautilus: mount drives
    tumbler.enable = true; # Nautilus: thumbnails

    # Secret Service for Zed's sign-in; without it, a sign-in lasts only until
    # the app exits (org.freedesktop.secrets).
    gnome.gnome-keyring.enable = true;
  };

  systemd.tmpfiles.rules = [ "d /var/cache/tuigreet 0755 greeter greeter - -" ]; # tuigreet cache
  security.rtkit.enable = true; # pipewire realtime priority
  # Unlock the login keyring at greetd, so secrets never prompt.
  security.pam.services.greetd.enableGnomeKeyring = true;

  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      inter
    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [ "Inter" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ]; # file chooser
    config.common.default = "*";
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  environment.systemPackages = with pkgs; [
    nautilus
    file-roller
    ghostty
    wl-clipboard
    brightnessctl
    playerctl
  ];

  environment.sessionVariables.NIXOS_OZONE_WL = "1"; # native Wayland for Chromium/Electron
}
