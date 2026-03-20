# home/airgap.nix — overrides for airgap / offline deployments
# Imported on top of base.nix for the homeConfigurations.airgap flake output.
# Disables anything that phones home or requires internet at runtime.
{ lib, ... }:

{
  # opencode: disable auto-update and online plugins
  programs.opencode.settings.autoupdate = lib.mkForce false;
  programs.opencode.settings.plugin     = lib.mkForce [];

  # atuin: already has auto_sync=false in base.nix; also disable update check
  programs.atuin.settings.update_check = lib.mkForce false;
}
