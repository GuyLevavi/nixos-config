# nixos

Two laptops, one repo: Hyprland + Noctalia on NixOS unstable, at `/etc/nixos`.

| host     | graphics                                     |
| -------- | -------------------------------------------- |
| `cpubox` | integrated only                              |
| `gpubox` | iGPU + NVIDIA, PRIME sync (Steam lives here) |

## Bootstrap

```sh
cd /etc/nixos && git add -A    # untracked files are invisible to a flake build
sudo nixos-rebuild switch --flake .#cpubox    # or .#gpubox
```

Afterwards `rb` rebuilds and `update` bumps inputs first.

## Who owns what

- **Nix**: packages, services, drivers, users, and every config file you don't
  edit at runtime.
- **Noctalia**: the theme. A palette switch (`SUPER+T`) rewrites GTK/Qt,
  ghostty, btop, starship and Firefox colours at runtime, so Stylix is banned
  and `gtk.enable`/`qt.enable` stay `false`. A hook in `home/noctalia.nix`
  syncs Zed, Neovim, tmux and OpenCode, which have no Noctalia template.
- **You**: `hypr/`, `nvim/`, `tmux/`, `opencode/`, `skills/` — symlinked out of
  the store, so edits need no rebuild (`hyprctl reload`, tmux `prefix R`).
  Neovim plugins are the exception: all come from nixpkgs, so a new one is a
  Nix change.

Zed's `settings.json` is co-owned: every `rb` deep-merges Nix over it.

## Things that will bite you

- **Never `git checkout`/`reset`/`clean` `hypr/hyprland.conf` while Hyprland
  runs** — its watcher writes a stub over the file. Restore it, then
  `hyprctl reload`.
- **Do not enable TLP.** It conflicts with power-profiles-daemon, which
  Noctalia's power widget drives.
- **Firefox theming** needs `toolkit.legacyUserProfileCustomizations.stylesheets
  = true` in `about:config`, or it fails silently.
- **Noctalia follows nixpkgs.** A bump can rename config keys (build fails) or
  IPC verbs in `hypr/binds.conf` (fails only at runtime).
- **`open = true`** in `hosts/gpubox/nvidia.nix` needs Turing or newer (the
  RTX 4060 is Ada).

Dropping Noctalia touches only `home/noctalia.nix`, `programs.noctalia` in
`modules/desktop.nix`, and the `noctalia msg` lines in `hypr/binds.conf`.
