{ pkgs, ... }:

{
  # Enable the ratbagd D-Bus daemon for configuring gaming mice
  services.ratbagd.enable = true;

  # Add Piper (GUI) and ratbagctl (CLI) to system packages
  environment.systemPackages = with pkgs; [
    piper
    libratbag # provides ratbagctl and ratbagd
  ];
}

