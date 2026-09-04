{
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.noctalia.nixosModules.default ];

  # Pulls in the wayland session desktop file, xdg-desktop-portal-hyprland,
  # xwayland, polkit and hardware.graphics. UWSM wraps the session in systemd
  # scopes so graphical-session.target exists (the Noctalia user service needs it).
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start hyprland-uwsm.desktop'";
      user = "greeter";
    };
  };
  systemd.tmpfiles.rules = [ "d /var/cache/tuigreet 0755 greeter greeter - -" ];

  programs.noctalia = {
    enable = true;
    recommendedServices.enable = true; # NetworkManager, bluetooth, upower, ppd (all mkDefault)
    systemd.enable = false; # the user service in home/noctalia.nix owns this
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  security.rtkit.enable = true;

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

  services.gvfs.enable = true; # Nautilus: mount drives
  services.tumbler.enable = true; # Nautilus: thumbnails

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
    firefox
    ghostty
    wl-clipboard
    brightnessctl
    playerctl
  ];

  environment.sessionVariables.NIXOS_OZONE_WL = "1"; # native Wayland for Chromium/Electron
}
