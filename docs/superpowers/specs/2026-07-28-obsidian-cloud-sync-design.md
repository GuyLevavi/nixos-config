# Obsidian + OneDrive/Google Drive Sync — NixOS Config Design

Date: 2026-07-28

## Summary

Add Obsidian to both hosts and give the user a Windows-like local-folder sync for OneDrive and Google Drive, so the Obsidian vault (currently in OneDrive, possibly migrating to Google Drive later) is always available as plain local files. Sync is bidirectional via `rclone bisync` on a systemd user timer.

## Approach

Option A (chosen): `rclone bisync` mirroring each cloud remote into a local folder (`~/OneDrive`, `~/GoogleDrive`), run automatically every 5 minutes via `systemd.user.timers`. Closest match to the Windows OneDrive/Google Drive desktop client experience — files are real local files, sync happens in the background, works offline between syncs.

Rejected: `rclone mount` (on-demand FUSE mount) — would require network on every file access and risks write conflicts/latency for an actively-edited Obsidian vault. Rejected: paid clients (Insync) — unnecessary cost for functionality rclone provides free.

## Files Changed

`home/gui.nix` — Obsidian package, rclone package, systemd user services/timers, fish abbreviations.

## Design

### Obsidian

```nix
home.packages = with pkgs; [ ... obsidian ... ];
```

### rclone remotes (manual, one-time, per machine)

Nix cannot declare OAuth tokens (they're runtime secrets requiring a browser login, and refresh-rewrite the config file). After `rb`, on each machine:

```fish
rclone config   # create remote "onedrive" (Microsoft OneDrive) and "gdrive" (Google Drive)
```

This writes `~/.config/rclone/rclone.conf`, left unmanaged by home-manager (mutable, contains secrets).

### Local sync folders + first-run bootstrap (manual, one-time, per remote per machine)

```fish
mkdir -p ~/OneDrive ~/GoogleDrive
rclone bisync onedrive: ~/OneDrive --resync
rclone bisync gdrive:   ~/GoogleDrive --resync
```

`--resync` establishes bisync's baseline snapshot; required once before the automated timer-driven runs can diff future changes safely.

### Automated sync (systemd user services + timers)

```nix
systemd.user.services.rclone-bisync-onedrive = {
  Unit.Description = "Bisync ~/OneDrive with OneDrive remote";
  Service = {
    Type = "oneshot";
    ExecStart = "${pkgs.rclone}/bin/rclone bisync onedrive: %h/OneDrive --conflict-resolve=newer --conflict-suffix=conflict";
  };
};
systemd.user.timers.rclone-bisync-onedrive = {
  Unit.Description = "Run rclone-bisync-onedrive every 5 minutes";
  Timer = { OnBootSec = "2m"; OnUnitActiveSec = "5m"; };
  Install.WantedBy = [ "timers.target" ];
};
```

Mirrored for `gdrive` → `~/GoogleDrive`. `--conflict-resolve=newer` auto-picks the more-recently-modified file on conflict; the loser is kept alongside with a `.conflict` suffix (nothing is deleted silently).

### Manual control (fish abbreviations)

```fish
programs.fish.shellAbbrs.syncdrives = "systemctl --user start rclone-bisync-onedrive rclone-bisync-gdrive";
```

Lets the user force an immediate sync instead of waiting for the timer.

## Constraints / Risks

- First-run `--resync` and `rclone config` are manual, undeclarable steps — documented above, not automated.
- `rclone bisync` will abort a run (rather than guess) if it sees an anomalously large change (e.g. mass deletion) — a safety feature; the user may occasionally need to inspect and re-run manually.
- True same-file concurrent edits across machines are still a real conflict, same as Windows OneDrive/Google Drive clients — not something sync software fully prevents.
- Applies to both `nixbox` and `gamingbox` via the shared `home/gui.nix`.
