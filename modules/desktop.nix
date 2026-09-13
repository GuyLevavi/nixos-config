{
  pkgs,
  inputs,
  ...
}:
let
  # Vimium, fetched at build time and pinned by hash, so the add-on lands in
  # the store like any other dependency instead of being pulled from AMO on
  # first launch. This is the unmodified, AMO-signed archive on purpose:
  # pkgs.fetchFirefoxAddon rewrites manifest.json to inject a gecko id, which
  # invalidates Mozilla's signature, and release Firefox refuses unsigned
  # add-ons. Bump the file id, version and hash together from
  # https://addons.mozilla.org/api/v5/addons/addon/vimium-ff/
  vimium = pkgs.fetchurl {
    name = "vimium-2.4.2.xpi";
    url = "https://addons.mozilla.org/firefox/downloads/file/4717567/vimium_ff-2.4.2.xpi";
    hash = "sha256-Ex4qZ1gOeukSWrGXgRWeYUCfrEe0Qfwngqq3Y5bq0ZY=";
  };
in
{
  imports = [ inputs.noctalia.nixosModules.default ];

  # Pulls in the wayland session desktop file, xdg-desktop-portal-hyprland,
  # xwayland, polkit and hardware.graphics. UWSM wraps the session in systemd
  # scopes so graphical-session.target exists (the Noctalia user service needs it).
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  programs.noctalia = {
    enable = true;
    recommendedServices.enable = true; # NetworkManager, bluetooth, upower, ppd (all mkDefault)
    systemd.enable = false; # the user service in home/noctalia.nix owns this
  };

  # Firefox is a `programs.*` block rather than a systemPackages entry only so
  # that `policies` exists — enabling this already puts the wrapped package in
  # systemPackages. Policies are the one declarative way to install an add-on
  # without adding NUR as a flake input for a single extension, and they write
  # /etc/firefox/policies/policies.json, never the user profile, so Noctalia
  # keeps sole ownership of userChrome.css (see README "Who owns what").
  # Any policy at all makes Firefox report itself as "managed by your
  # organisation"; that is cosmetic.
  #
  # Vimium's own settings — keybindings, excluded URLs, search engines — are
  # NOT seedable here. It reads them only from chrome.storage.sync, which
  # Firefox keeps in storage-sync-v2.sqlite; home-manager's extension
  # `settings` option writes browser-extension-data/*/storage.js, which backs
  # storage.local and Vimium never reads. Set them once in Vimium's options
  # page; nothing in this repo will overwrite them.
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

    # No driver packages pinned: modern printers are driverless IPP/AirPrint and
    # CUPS finds them over mDNS. Add to services.printing.drivers only if some
    # older model actually needs a PPD. NOTE: openFirewall here opens UDP 5353
    # for mDNS discovery — that is the only port this config opens.
    printing.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    gvfs.enable = true; # Nautilus: mount drives
    tumbler.enable = true; # Nautilus: thumbnails

    # Secret Service provider. Zed stores sign-in/provider credentials via
    # org.freedesktop.secrets — with no keyring daemon running, sign-in works
    # but is gone on the next app start. Not a settings.json thing.
    gnome.gnome-keyring.enable = true;
  };

  # tuigreet's cache dir (greetd above) and pipewire's realtime priority.
  systemd.tmpfiles.rules = [ "d /var/cache/tuigreet 0755 greeter greeter - -" ];
  security.rtkit.enable = true;
  # Unlock the login keyring with the login password at greetd entry, so apps
  # hitting org.freedesktop.secrets never prompt.
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
