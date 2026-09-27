{ pkgs, ... }:
{
  home.packages = with pkgs; [
    obsidian
    rclone
    spotify
  ];

  # Obsidian vault <-> Google Drive, one-time manual setup: `rclone config` for
  # the "gdrive" remote, then a first `--resync` (OAuth can't be declared here).
  systemd.user.services.rclone-bisync-gdrive = {
    Unit = {
      Description = "Bisync ~/GoogleDrive/Obsidian with Google Drive remote";
      # Skip instead of failing until `rclone config` has run on this host.
      ConditionPathExists = "%h/.config/rclone/rclone.conf";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.rclone}/bin/rclone bisync gdrive:Obsidian %h/GoogleDrive/Obsidian --conflict-resolve=newer --conflict-suffix=conflict";
    };
  };
  systemd.user.timers.rclone-bisync-gdrive = {
    Unit.Description = "Run rclone-bisync-gdrive every 5 minutes";
    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "5m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
