# CLAUDE.md

Guidance for agents working in this repo. Design rationale lives in
`README.md` — read it before structural changes.

## Commands

```fish
rb              # cd /etc/nixos && git add -A && sudo nixos-rebuild switch --flake /etc/nixos#(hostname)
update          # nix flake update && rb
hyprctl reload  # apply hypr/*.conf changes without logging out or rebuilding
```

```bash
sudo nixos-rebuild switch --flake /etc/nixos#gpubox --show-trace  # debug a failed rebuild
sudo nixos-rebuild switch --rollback
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

## Comments

- Explain **why**, never what. One line is the budget; two for a real trap.
- Keep only comments that prevent a plausible mistake: constraints, footguns,
  cross-file coupling, non-obvious external facts.
- No history, measurements, or alternatives considered. Git log is the archive.
- Design rationale belongs in `README.md`, not in code.
- Prefer deleting a comment over rewriting it.

## Layout

```
flake.nix                       # inputs, mkHost, both hosts
hosts/                          # per-machine settings; hardware-configuration.nix is generated, don't edit
modules/core.nix                # boot, nix settings, locale, user (bash login shell)
modules/desktop.nix             # hyprland+uwsm, greetd, pipewire, fonts, podman, noctalia (system)
modules/laptop.nix              # power, lid, bluetooth, touchpad, firmware — shared; both hosts are laptops
home/default.nix                # ownership rule (Noctalia vs Nix), out-of-store symlinks for live files
home/noctalia.nix               # the shell (user service) + zed/tmux/nvim palette sync
home/shell.nix                  # bash->fish exec, starship/zoxide/atuin/fzf, git/delta/lazygit/gh
home/tmux.nix                   # workmux pkg/config + opencode plugins; tmux.conf lives in tmux/
home/lsp.nix                    # shared language-server list (zed + opencode PATH)
home/zed.nix                    # Zed editor config
home/neovim.nix                 # nvim package + shared LSP wiring; config lives in nvim/
home/programs.nix               # terminal, core CLI, media tools
home/apps.nix                   # obsidian + rclone Google Drive bisync, spotify
home/scripts.nix                # rb / update / screen-record / monitor-watch
home/skills.nix                 # vendored matt-skills set, symlinked into opencode
hypr/                           # hyprland.conf + binds.conf — edited live, NOT in the nix store
nvim/                           # init.lua (live) + nvim-pack-lock.json (vim.pack-generated, tracked)
tmux/                           # tmux.conf — edited live (palette.conf stays runtime)
opencode/                       # opencode.jsonc + tui.json — edited live
skills/                         # hand-rolled agent skills, symlinked into opencode
```

## Critical Patterns

### Desktop: Hyprland + Noctalia

`programs.hyprland` (`withUWSM = true`) + `programs.noctalia` (system) in
`modules/desktop.nix`; the Noctalia **user** service is enabled in
`home/noctalia.nix` (`systemd.enable = true`) — do not flip both on.

Geometry is one constant, 8: `gaps_out = 8` / `gaps_in = 4` in
`hypr/hyprland.conf`, mirrored by `margin_edge` / `padding` / `widget_spacing`
= 8 with `margin_ends = 0` in `home/noctalia.nix`. Change both sides together.
`margin_ends` and `padding` stack, so `margin_ends` must stay 0. Radii follow
the concentric rule (`outer = inner + gap`): windows/islands 8, workspace pills
2 (8 − 6 padding), screen corners 16.

Noctalia cannot match Hyprland's window shadows: `bar.default.shadow = true`
draws nothing under the islands and only hazes the windows below. Shadows stay
off, `contact_shadow` is a no-op.

Idle is Noctalia's (`[idle.behavior.*]`) and owns lock too; hypridle is gone.
There is deliberately no enabled suspend behavior — the machine stays reachable
unattended — with logind's lid-close suspend as the off-AC backstop.

`media` sits at the head of `end` because that lane is right-anchored: titles
grow leftward without shifting the island, unlike `start`.

`hypr/hyprland.conf` and `hypr/binds.conf` are symlinked out of the store from
`/etc/nixos/hypr/` (`home/default.nix`) — edit them and `hyprctl reload`.
Never `git checkout`/`reset` them while Hyprland runs: its config watcher
regenerates a stub over the live file. Two runtime-written sourced files are
not in the repo: `~/.config/hypr/noctalia.conf` (theme colours) and
`monitor-state.conf` (monitor-watch).

The same out-of-store pattern covers `nvim/`, `tmux/tmux.conf`,
`opencode/{opencode.jsonc,tui.json}` and `skills/` (`home/default.nix`);
`~/.config/tmux/palette.conf` stays runtime-written. `programs.neovim` must
keep `sideloadInitLua = true` or home-manager writes its own `init.lua` over
the `nvim/` symlink.

### Theming: Noctalia owns it, not Nix

Palette switches write GTK/Qt/ghostty/btop/starship/Firefox files at runtime.
`gtk.enable`/`qt.enable` are `false` and Stylix is banned — home-manager must
never write those same files as read-only store symlinks. `programs.noctalia.settings`
seeds `config.toml`; the GUI's `~/.local/state/noctalia/settings.toml` overrides
per-key. btop is split: theme file runtime-owned, `btop.conf` Nix-owned with
`color_theme = "noctalia"` so the hook no-ops.

Zed/tmux/nvim have no Noctalia template. One hook script
(`noctalia-theme-sync`, `home/noctalia.nix`) rewrites the zed theme block,
`~/.config/tmux/palette.conf` and `~/.local/state/nvim/theme.lua` (a hand-tuned
colorscheme plugin per builtin theme; plugins installed by vim.pack in
`nvim/init.lua`); the theme-name map lives in one Nix table next to the script.
OpenCode uses its built-in `system` theme, which follows the terminal palette
Noctalia writes. A `home.activation` entry re-runs it after
`zedSettingsActivation`, because `rb` re-seeds the zed block from Nix and
`started` doesn't fire on a live session. workmux's config and OpenCode status
plugin are Nix-owned in `home/tmux.nix` from the pinned input.

### Shell: bash (login) + fish (interactive)

`users.users.${username}.shell = pkgs.bash` (`modules/core.nix`) keeps POSIX
semantics for scripts/systemd/`bash -c`. `home/shell.nix` execs into fish on
interactive start unless the parent is fish (you typed it) or there is no tty
(Zed captures its env with `bash -l -i -c`; an unconditional exec eats the
command and worktrees lose their PATH). starship/zoxide/atuin/fzf use
home-manager's `enableFishIntegration`.

### Editors: Zed + Neovim + OpenCode

`home/lsp.nix` is the single language-server list: zed gets it via
`extraPackages`, nvim via `programs.neovim.extraPackages` (`home/neovim.nix`),
opencode via a wrapped PATH (`home/programs.nix`). opencode's per-server config
is `opencode/opencode.jsonc` (repo-owned, symlinked live); zed's choosing
(basedpyright over pyright, nixd over nil, ruff formatter) is in its
`userSettings.languages`. Zed is the default editor (`zeditor -w`); nvim is the
terminal fallback, its config is `nvim/init.lua` (repo-owned), and it enables
the shared servers by lspconfig id. Zed's `zls` is guarded by
`executable()` because it is project-scoped (the ziglings flake supplies it),
not part of `home/lsp.nix`. Panels dock right; `ctrl-b` toggles the right dock
(there is no left dock for stock `ToggleLeftDock` to open). Extensions are
registry ids downloaded at runtime; removed ones are never uninstalled. With
`mutableUserSettings = true` activation deep-merges Nix over the live settings
(Nix wins per key; removed keys linger). Sign-in lives in gnome-keyring.

### Adding packages

| What                            | Where                                                                                              |
| ------------------------------- | -------------------------------------------------------------------------------------------------- |
| User CLI app                    | `home.packages` in `home/programs.nix`                                                             |
| User GUI app                    | `home.packages` in `home/programs.nix` or `environment.systemPackages` in `modules/desktop.nix`    |
| System daemon / hardware driver | `modules/core.nix`, `modules/desktop.nix`, `modules/laptop.nix`, or the specific `hosts/<machine>/` |
| NVIDIA-specific                 | `hosts/gpubox/nvidia.nix` only                                                                     |

## Notes

- `system.stateVersion` and `home.stateVersion` are `"25.05"` — **do not change**
- Both hosts import `modules/laptop.nix` — both are laptops
- `gpubox` uses PRIME **sync** (dGPU always on, no `nvidia-offload` wrapper)
- Podman is enabled system-wide; activate per-session with
  `systemctl --user enable --now podman.socket`
- `home/apps.nix`'s rclone sync needs a one-time manual `rclone config` (remote
  `gdrive`) and a `--resync`; the unit is skipped, not failed, until then
- `services.openssh` is off on purpose — re-enable only in the same commit that
  adds an `authorizedKeys` entry
- `zramSwap` is on both hosts (gpubox has no swap device)
- The only opened port is **UDP 5353** (avahi/mDNS for driverless printing)
