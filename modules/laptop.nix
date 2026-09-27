{ pkgs, ... }:
{
  # Both hosts are laptops, so this is shared.

  services = {
    # power-profiles-daemon comes from Noctalia's recommendedServices; TLP
    # conflicts and has no D-Bus interface for the shell's power widget.
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

  # thermald on this box falls back to non-adaptive mode via a systemd restart;
  # upstream sets no restart policy, so without this it stays dead all session.
  systemd.services.thermald.unitConfig.Restart = "on-failure";

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false; # the shell's toggle owns this
  };

  hardware.acpilight.enable = true; # backlight without root

  environment.systemPackages = with pkgs; [
    powertop
    acpi
    lm_sensors # temps only; EC fans have no hwmon
  ];
}
