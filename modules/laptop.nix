{ pkgs, ... }:
{
  # Both hosts are laptops, so this is shared.

  # power-profiles-daemon comes from Noctalia's recommendedServices and drives
  # the shell's power widget. Do NOT enable services.tlp — it conflicts and has
  # no D-Bus interface for the widget.
  services.upower.enable = true;
  services.thermald.enable = true; # Intel; harmless on AMD

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore"; # stay awake when docked
    HandlePowerKey = "suspend";
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false; # the shell's toggle owns this
  };

  services.fwupd.enable = true;

  # Hyprland reads its own input config; libinput is for the greeter.
  services.libinput = {
    enable = true;
    touchpad = {
      naturalScrolling = true;
      tapping = true;
      disableWhileTyping = true;
    };
  };

  hardware.acpilight.enable = true; # backlight without root

  environment.systemPackages = with pkgs; [
    powertop
    acpi
  ];
}
