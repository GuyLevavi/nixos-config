{ pkgs, ... }:
{
  # Both hosts are laptops, so this is shared.

  services = {
    # power-profiles-daemon comes from Noctalia's recommendedServices and drives
    # the shell's power widget. Do NOT enable services.tlp — it conflicts and has
    # no D-Bus interface for the widget.
    upower.enable = true;
    thermald.enable = true; # Intel; harmless on AMD

    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "ignore"; # stay awake when docked
      HandlePowerKey = "suspend";
    };

    fwupd.enable = true;

    # Hyprland reads its own input config; libinput is for the greeter.
    libinput = {
      enable = true;
      touchpad = {
        naturalScrolling = true;
        tapping = true;
        disableWhileTyping = true;
      };
    };
  };

  # thermald first tries adaptive mode; on some DPTC tables (this Swift) it
  # can't build zones and asks systemd to restart it non-adaptively. Upstream
  # has no restart policy, so without this it stays dead all session.
  systemd.services.thermald.unitConfig.Restart = "on-failure";

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false; # the shell's toggle owns this
  };

  hardware.acpilight.enable = true; # backlight without root

  environment.systemPackages = with pkgs; [
    powertop
    acpi
    lm_sensors # temps only — this Acer's EC fans have no hwmon interface
  ];
}
