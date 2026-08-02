# Obsidian + Cloud Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Obsidian to both GUI hosts, plus a Windows-like local-folder sync for OneDrive and Google Drive via `rclone bisync` on a systemd user timer, so the Obsidian vault (currently in OneDrive) is always available as plain local files regardless of which cloud provider it lives in.

**Architecture:** Single file change — `home/gui.nix` (shared by `nixbox` and `gamingbox`). Adds the `obsidian` and `rclone` packages, two `systemd.user.services`/`systemd.user.timers` pairs (one per remote) that run `rclone bisync` every 5 minutes, and a fish abbreviation for forcing an immediate sync. `rclone`'s remote auth (OAuth) and the first bisync `--resync` are manual one-time steps per machine — they can't be declared in Nix since they involve a browser login and a mutable, secret-bearing config file.

**Tech Stack:** NixOS home-manager, `rclone` (bisync), `systemd.user` services/timers.

## Global Constraints

- Applies to both `nixbox` and `gamingbox` via `home/gui.nix` (per spec).
- `rclone.conf` is never managed by home-manager — it's runtime-mutable and holds OAuth secrets.
- Conflict resolution: `--conflict-resolve=newer`, loser kept with `.conflict` suffix (per spec — nothing silently deleted).

---

## File Map

| File | Change |
|------|--------|
| `home/gui.nix` | Add `obsidian` + `rclone` packages, systemd services/timers, fish abbreviation |

---

### Task 1: Add Obsidian and rclone packages

**Files:**
- Modify: `home/gui.nix:317-335` (`home.packages` list)

- [ ] **Step 1: Add the two packages**

  In `home/gui.nix`, the `home.packages` list currently ends with:
  ```nix
    opencode
    opencode-desktop # AI coding agent (TUI + desktop client)
  ];
  ```

  Change to:
  ```nix
    opencode
    opencode-desktop # AI coding agent (TUI + desktop client)
    obsidian
    rclone # cloud sync — see rclone-bisync-* systemd services below
  ];
  ```

- [ ] **Step 2: Verify Nix syntax**

  ```bash
  nix-instantiate --parse /etc/nixos/home/gui.nix
  ```

  Expected: no output (parse success).

---

### Task 2: Add rclone bisync systemd services and timers

**Files:**
- Modify: `home/gui.nix` — add new block after the `xdg.configFile."opencode/opencode.json"` block (end of file, before the final closing `}`)

**Interfaces:**
- Produces: systemd user units `rclone-bisync-onedrive` and `rclone-bisync-gdrive`, invoked by name in Task 3's fish abbreviation.

- [ ] **Step 1: Add the systemd services + timers block**

  Insert this block right before the file's final closing `}` (after the `xdg.configFile."opencode/opencode.json"` block):

  ```nix
  # ── Cloud sync: OneDrive + Google Drive (rclone bisync) ────────────────
  # Local folders ~/OneDrive and ~/GoogleDrive mirror the cloud remotes,
  # both directions, like the Windows desktop clients. Remotes ("onedrive",
  # "gdrive") are configured once, manually, via `rclone config` — OAuth
  # can't be declared in Nix. First sync per remote must be a manual
  # `rclone bisync <remote>: ~/<Folder> --resync` (bisync's own safety
  # requirement) before these timers can run.
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

  systemd.user.services.rclone-bisync-gdrive = {
    Unit.Description = "Bisync ~/GoogleDrive with Google Drive remote";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.rclone}/bin/rclone bisync gdrive: %h/GoogleDrive --conflict-resolve=newer --conflict-suffix=conflict";
    };
  };
  systemd.user.timers.rclone-bisync-gdrive = {
    Unit.Description = "Run rclone-bisync-gdrive every 5 minutes";
    Timer = { OnBootSec = "2m"; OnUnitActiveSec = "5m"; };
    Install.WantedBy = [ "timers.target" ];
  };
  ```

- [ ] **Step 2: Verify Nix syntax**

  ```bash
  nix-instantiate --parse /etc/nixos/home/gui.nix
  ```

  Expected: no output.

---

### Task 3: Add fish abbreviation for manual sync

**Files:**
- Modify: `home/gui.nix` — add near the systemd block from Task 2

**Interfaces:**
- Consumes: unit names `rclone-bisync-onedrive`, `rclone-bisync-gdrive` from Task 2.

- [ ] **Step 1: Add the abbreviation**

  Immediately after the two `systemd.user.timers` blocks added in Task 2, add:

  ```nix
  programs.fish.shellAbbrs.syncdrives = "systemctl --user start rclone-bisync-onedrive rclone-bisync-gdrive";
  ```

  (This is a separate `programs.fish.shellAbbrs` attrset from the one in `home/base.nix` — home-manager merges attrsets from multiple modules by key, so this doesn't conflict with the existing `rb`/`update`/etc. abbreviations.)

- [ ] **Step 2: Verify Nix syntax**

  ```bash
  nix-instantiate --parse /etc/nixos/home/gui.nix
  ```

  Expected: no output.

---

### Task 4: Build, manual one-time setup, verify, commit

- [ ] **Step 1: Dry-build both hosts**

  ```bash
  sudo nixos-rebuild dry-build --flake /etc/nixos#nixbox --show-trace 2>&1 | tail -30
  sudo nixos-rebuild dry-build --flake /etc/nixos#gamingbox --show-trace 2>&1 | tail -30
  ```

  Expected: both end cleanly, no `error:` lines.

- [ ] **Step 2: Apply the config on this machine**

  ```bash
  rb
  ```

  Expected: completes without error.

- [ ] **Step 3: Verify the packages and units landed**

  ```bash
  which obsidian rclone
  systemctl --user list-timers | grep rclone-bisync
  ```

  Expected: both binaries resolve; both timers listed (they'll fail to fire meaningfully until Step 4/5 below are done, but the units should exist and be enabled).

- [ ] **Step 4: One-time manual remote auth (per machine)**

  ```bash
  rclone config
  ```

  Create remote `onedrive` (type: Microsoft OneDrive) and remote `gdrive` (type: Google Drive), following rclone's interactive OAuth prompts (opens a browser). This writes `~/.config/rclone/rclone.conf`, which is intentionally NOT managed by home-manager.

- [ ] **Step 5: One-time manual bootstrap sync (per remote, per machine)**

  ```bash
  mkdir -p ~/OneDrive ~/GoogleDrive
  rclone bisync onedrive: ~/OneDrive --resync
  rclone bisync gdrive:   ~/GoogleDrive --resync
  ```

  Expected: both complete without error, populating `~/OneDrive` and `~/GoogleDrive` with the current cloud contents. This establishes bisync's baseline; skip this and the timer's later diff-based runs will refuse to proceed.

- [ ] **Step 6: Verify the automated timer works**

  ```bash
  syncdrives
  systemctl --user status rclone-bisync-onedrive rclone-bisync-gdrive --no-pager
  ```

  Expected: both show `Active: inactive (dead)` with a recent "Deactivated successfully" — i.e. the oneshot ran and exited 0. Check `journalctl --user -u rclone-bisync-onedrive -n 20` if it errored.

- [ ] **Step 7: Point Obsidian at the vault**

  Open Obsidian, "Open folder as vault", select `~/OneDrive/<your-vault-folder>` (wherever the existing vault lives inside the synced OneDrive folder).

- [ ] **Step 8: Commit**

  ```bash
  git -C /etc/nixos add home/gui.nix
  git -C /etc/nixos commit -m "feat: add Obsidian + rclone bisync for OneDrive/Google Drive"
  ```

---

## Rollback

If the rebuild fails:

```bash
sudo nixos-rebuild switch --rollback
```

Or revert the file:
```bash
git -C /etc/nixos checkout home/gui.nix
rb
```

`~/.config/rclone/rclone.conf` and the local `~/OneDrive`/`~/GoogleDrive` folders are untouched by either rollback path — they're outside home-manager's management.
