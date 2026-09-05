{ pkgs, ... }:
{
  home.packages = with pkgs; [
    obsidian
    rclone
    spotify
  ];

  # Obsidian vault <-> Google Drive via rclone bisync.
  # One-time manual setup: `rclone config` to create the "gdrive" remote (OAuth
  # can't be declared here), then a first `rclone bisync gdrive:Obsidian
  # ~/GoogleDrive/Obsidian --resync`.
  systemd.user.services.rclone-bisync-gdrive = {
    Unit = {
      Description = "Bisync ~/GoogleDrive/Obsidian with Google Drive remote";
      # Without this the timer fails every 5 minutes on a machine where the
      # one-time `rclone config` above hasn't been done yet (fresh install, or
      # the other host). A failed Condition makes systemd skip the run silently
      # instead, and the unit starts working on its own once the file appears.
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
