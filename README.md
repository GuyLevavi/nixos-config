# nixos

Two laptops, one repo. Hyprland + Noctalia, no dotfile framework. Lives at
`/etc/nixos`.

| host | graphics |
|---|---|
| `cpubox` | integrated only |
| `gpubox` | hybrid iGPU + NVIDIA, PRIME sync (Steam lives here) |

The only difference between them is one extra import.

## Layout

```
flake.nix              inputs, mkHost helper, both hosts
hosts/
  cpubox/              host id, integrated video accel, stateVersion
  gpubox/              same + nvidia.nix
modules/
  core.nix             boot, nix settings, locale, user
  desktop.nix          hyprland+uwsm, greetd, pipewire, fonts, podman, noctalia (system)
  laptop.nix           power, lid, bluetooth, touchpad, firmware
home/
  default.nix          the ownership rule, out-of-store symlinks
  noctalia.nix         the shell
  shell.nix            bash->fish, starship/zoxide/atuin/fzf, tmux, delta/lazygit/gh
  programs.nix         terminal, core CLI, media tools
  zed.nix              Zed editor
  lazyvim.nix          declarative LazyVim (pfassina/lazyvim-nix)
  apps.nix             obsidian + gdrive sync, spotify
  scripts.nix          rb / update / screen-record / monitor-watch
hypr/
  hyprland.conf        edited live, NOT in the nix store
  binds.conf
  hypridle.conf
```

Roughly 1000 lines including hardware configs, a third of it hyprland config
and comments.

## Bootstrap

```sh
cd /etc/nixos

# 1. hardware-configuration.nix already matches each real machine.
#    Only regenerate if hardware changes:
#    sudo nixos-generate-config --show-hardware-config > hosts/$(hostname)/hardware-configuration.nix

# 2. Build.
git add -A          # untracked files are invisible to a flake build
sudo nixos-rebuild switch --flake .#cpubox    # or .#gpubox
```

After the first build, `rb` does that for you on either machine; `update`
bumps flake inputs first.

## Who owns what

Three categories, and the whole design follows from keeping them apart.

**Nix owns** packages, services, kernel, drivers, users, and every config file
that you do not edit at runtime. Rebuilds are idempotent; there is no migration
machinery because there is no accumulated state to repair.

**Noctalia owns** the theme. When you switch palette in its bar/settings
(`SUPER+T` opens that window) it writes `~/.config/gtk-3.0/`, `gtk-4.0/`,
`qt6ct/`, the ghostty colours, btop, starship, the Firefox chrome, and
`~/.config/nvim/lua/matugen.lua` — so LazyVim follows palette switches live
(the `base16-nvim` half lives in `home/lazyvim.nix`). Those files are mutable
state outside Nix, on purpose, because a build-time theming system cannot
switch at runtime. Zed sits outside this system — its Catppuccin Mocha theme
is static in `home/zed.nix` and doesn't move when you switch.

Consequences, enforced in `home/default.nix`:

- **Do not add Stylix.** It generates the same files as read-only store
  symlinks. One of them will lose and the failure is confusing.
- `gtk.enable` and `qt.enable` stay `false` for the same reason.
- `programs.noctalia.settings` (in `home/noctalia.nix`) seeds `config.toml`
  with the theme + template ids only. The GUI writes its own
  `~/.local/state/noctalia/settings.toml`, which overrides per-key — both
  layers coexist, so the settings GUI keeps working.

**You own** `hypr/`. Those three files are symlinked out of the store into
`/etc/nixos/hypr/`, so editing a keybind and running `hyprctl reload` is
instant. No rebuild in the loop for the thing you change most often.
(`~/.config/hypr/noctalia.conf` and `monitor-state.conf` are runtime-written —
by Noctalia and monitor-watch respectively — and deliberately not in the repo.)

## Things that will bite you

- **Untracked files are invisible.** Add a new `.nix` file, forget `git add`,
  and the flake reports it does not exist. `rb` runs `git add -A` first.
- **`open = true`** in `hosts/gpubox/nvidia.nix` is correct for Turing (RTX 20xx
  / GTX 16xx) and newer only — this machine is Ada Lovelace (RTX 4060), well
  within range.
- **Do not enable TLP.** power-profiles-daemon is already on via Noctalia's
  `recommendedServices`, the two conflict, and only ppd exposes the D-Bus
  interface the shell's power widget drives.
- **Firefox theming** needs
  `toolkit.legacyUserProfileCustomizations.stylesheets = true` in `about:config`
  before the userChrome colours apply. It fails silently otherwise.
- **Noctalia and LazyVim are both pinned to tags** in `flake.nix` (not the
  default branch), on purpose — an update can rename an IPC verb and break a
  `hypr/binds.conf` line, or ship a LazyVim plugin regression. Bump each
  input deliberately (`nix flake lock --update-input noctalia` /
  `...--update-input lazyvim`) so breakage arrives only when you ask for it.
  Fixing a broken bind is editing `hypr/binds.conf`, not rebuilding your
  setup — which is the entire point of keeping the shell rented and the
  owned surface thin.
- **gpubox uses PRIME sync, not offload.** The dGPU is always rendering (no
  `nvidia-offload` wrapper needed, better sustained gaming perf) instead of
  sleeping when idle — you trade battery for that. CUDA and the airgap/work
  tooling from the pre-rehaul config are still not carried over.

## Swapping the shell out

If Noctalia does not work out, the blast radius is `home/noctalia.nix`, the
`programs.noctalia` block in `modules/desktop.nix`, and the `noctalia msg` lines
in `hypr/binds.conf`. Nothing else in the repo knows the shell exists.
