# nixos

Two laptops, one repo. Hyprland + Noctalia on NixOS unstable, lives at
`/etc/nixos`.

| host     | graphics                                            |
| -------- | --------------------------------------------------- |
| `cpubox` | integrated only                                     |
| `gpubox` | hybrid iGPU + NVIDIA, PRIME sync (Steam lives here) |

The only difference between them is one extra import.

## Layout

```
flake.nix              inputs, mkHost helper, both hosts
hosts/<machine>/       host settings + generated hardware-configuration.nix
modules/               core (boot/user), desktop (hyprland/greetd/pipewire),
                       laptop (power/lid/bluetooth/touchpad)
home/                  home-manager modules: noctalia, shell, tmux, zed, lsp,
                       neovim, programs, apps, scripts, skills
hypr/                  hyprland.conf + binds.conf, edited live, NOT in the store
nvim/                  init.lua, edited live, NOT in the store
tmux/                  tmux.conf, edited live (palette.conf stays runtime)
opencode/              opencode.jsonc + tui.json, edited live
skills/                hand-rolled agent skills, symlinked into opencode
```

## Bootstrap

```sh
cd /etc/nixos
git add -A                                      # untracked files are invisible to a flake build
sudo nixos-rebuild switch --flake .#cpubox      # or .#gpubox
```

After the first build, `rb` does that on either machine; `update` bumps flake
inputs first.

## Who owns what

**Nix owns** packages, services, kernel, drivers, users, and every config file
you do not edit at runtime. Rebuilds are idempotent.

**Noctalia owns** the theme. Switching the palette in its bar/settings
(`SUPER+T` opens that window) writes the GTK/Qt colours, the ghostty theme, the
btop theme file, starship and the Firefox chrome at runtime. btop is split:
Noctalia owns `~/.config/btop/themes/noctalia.theme`, while `btop.conf` is
Nix-owned with `color_theme = "noctalia"` preset so that hook stays a no-op.
Zed, tmux and Neovim have no Noctalia template; hooks in `home/noctalia.nix`
sync their theme files from the palette. Zed and Neovim switch between real
hand-tuned themes matching the builtin palette (Neovim via
`~/.local/state/nvim/theme.lua`), tmux gets `palette.conf`. OpenCode uses its
built-in `system` theme, which follows the terminal palette.

Consequences:

- **Do not add Stylix.** `gtk.enable` and `qt.enable` stay `false` for the same
  reason: home-manager must never write those files as read-only store symlinks.
- `programs.noctalia.settings` seeds `config.toml`; the GUI's
  `~/.local/state/noctalia/settings.toml` overrides per-key at runtime.
- Zed's `settings.json` is co-owned: Nix deep-merges over the live file on every
  `rb` (Nix wins per key, GUI edits to those keys revert). Sign-in lives in
  gnome-keyring, not that file, so Nix ownership never signs you out.

**You own** `hypr/`, `nvim/`, `tmux/`, `opencode/` and `skills/`. They are
symlinked out of the store from `/etc/nixos/`, so edits need no rebuild:
`hyprctl reload` for Hyprland, `:source $MYVIMRC` for Neovim, `prefix R` for
tmux; opencode reads its config at start. Runtime-written siblings stay out of
the repo: `~/.config/hypr/noctalia.conf`, `monitor-state.conf`, and
`~/.config/tmux/palette.conf`. Neovim also carries a `nvim-pack-lock.json`:
`vim.pack` rewrites it on updates, and it is tracked on purpose.

## Things that will bite you

- **Untracked files are invisible.** Add a new `.nix` file, forget `git add`,
  and the flake reports it does not exist. `rb` runs `git add -A` first.
- **Never `git checkout`/`reset`/`clean` over `hypr/hyprland.conf` while
  Hyprland is running.** Its config watcher sees the file vanish and regenerates
  a stub over the top of it; the session then reloads with wrong binds. Restore
  the file, then `hyprctl reload`. Disowning the file from git would also fix
  this, but it is tracked on purpose.
- **`open = true`** in `hosts/gpubox/nvidia.nix` is correct for Turing (RTX 20xx
  / GTX 16xx) and newer only — this machine is Ada (RTX 4060), well within range.
- **Do not enable TLP.** power-profiles-daemon comes from Noctalia's
  `recommendedServices`, the two conflict, and only ppd exposes the D-Bus
  interface the shell's power widget drives.
- **Firefox theming** needs
  `toolkit.legacyUserProfileCustomizations.stylesheets = true` in `about:config`
  before the userChrome colours apply. It fails silently otherwise.
- **Noctalia is pinned to a tag** in `flake.nix` on purpose — an update can
  rename an IPC verb and break a `hypr/binds.conf` line. Bump it deliberately
  (`nix flake lock --update-input noctalia`).
- **gpubox uses PRIME sync, not offload.** The dGPU is always rendering — you
  trade battery for sustained gaming performance.

If Noctalia does not work out, the blast radius is `home/noctalia.nix`, the
`programs.noctalia` block in `modules/desktop.nix`, and the `noctalia msg` lines
in `hypr/binds.conf`. Nothing else in the repo knows the shell exists.
