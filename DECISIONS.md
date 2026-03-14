# NixOS Config — Decisions & Architecture Notes

> Written by OpenCode (claude-sonnet-4.6) during configuration sessions on 2026-03-07, 2026-03-09, 2026-03-10, and 2026-03-14.
> Paste this file at the start of a new OpenCode session to restore context.

---

## Machine & Stack

| Property | Value |
|---|---|
| Hostname | `nixbox` |
| Hardware | Intel desktop, x86_64, iGPU (iHD VA-API) |
| NixOS channel | `nixos-unstable` |
| State version | `25.05` (do not change) |
| User | `gl` (`/home/gl`) |
| Shell | bash (login/PAM) → nushell (interactive) |
| Desktop | Hyprland + Waybar + Rofi + Swaync + Kitty |
| Theme | Catppuccin Mocha (everywhere) |

---

## Repository Layout

```
/etc/nixos/
├── flake.nix                        # entry point, pins all inputs
├── flake.lock                       # locked dependency versions
├── home.nix                         # home-manager user config (shared)
├── DECISIONS.md                     # this file
├── hosts/
│   └── nixbox/
│       ├── configuration.nix        # system-level config
│       └── hardware-configuration.nix
└── config/                          # dotfiles, symlinked via home.nix
    ├── hypr/hyprland.conf
    ├── mako/config
    ├── wofi/{config,style.css}
    └── nvim/                        # LazyVim starter config
```

---

## Flake Inputs

| Input | URL | Purpose |
|---|---|---|
| `nixpkgs` | `nixpkgs/nixos-unstable` | All packages |
| `home-manager` | `github:nix-community/home-manager` | User environment |
| `catppuccin` | `github:catppuccin/nix` | Unified theming module |

`home-manager` and `catppuccin` both `follow` nixpkgs to avoid duplicate evaluations.
`plasma-manager` was removed in the 2026-03-14 KDE → Hyprland migration (see Decision 21).

---

## Key Architectural Decisions

### 1. Catppuccin via `catppuccin/nix` flake (not manual hex values)

**Decision:** Add `catppuccin/nix` as a flake input. Use `catppuccin.homeModules.catppuccin` in home-manager. Set `catppuccin.flavor = "mocha"` once. Enable per-app modules.

**Why:** The config previously had ~50 lines of manually copied Catppuccin Mocha hex values spread across kitty, fzf, waybar, mako, and wofi. Duplicated hex values are fragile (easy to get out of sync, hard to switch flavors). The catppuccin-nix module manages all of this from a single declaration and injects colors at build time.

**Apps covered by catppuccin-nix:**
`kitty`, `fzf`, `mako`, `waybar`, `hyprland`, `hyprlock`, `lazygit`, `bat`, `btop`, `nushell`, `nvim`, `opencode`

**Consequence for dotfiles:** The color variable block was removed from `hyprland.conf` (catppuccin-nix sources a generated file). Color declarations were stripped from `waybar/style.css`, `mako/config`, and `wofi/style.css`.

**Note on waybar:** `config/waybar/config.jsonc` and `config/waybar/style.css` have been deleted. Waybar is now fully configured via `programs.waybar` in `home.nix`. catppuccin-nix prepends `@import "mocha.css"` making `@base`, `@mauve`, `@text`, etc. available in the inline `style` string.

**Note on hyprland:** catppuccin-nix injects a `source` line at build time that defines `$mauve`, `$blue`, `$overlay0`, etc. The `col.active_border` and `col.inactive_border` lines in `hyprland.conf` still reference these variables — they continue to work because catppuccin provides them.

---

### 2. Nix manages LSP binaries; Mason is neutralized

**Decision:** Keep Mason installed (as a UI/registry tool) but override `mason-lspconfig.nvim` with `ensure_installed = {}` so it never downloads binaries. All LSP servers, formatters, and linters are provided via `programs.neovim.extraPackages` in `home.nix`.

**Why:** Mason on NixOS downloads FHS-dependent binaries (expecting `/lib/ld-linux.so.2`, standard glibc paths, etc.) that do not exist on NixOS. These binaries silently fail or error on launch. Nix-provided binaries are built for NixOS and work correctly.

**File:** `config/nvim/lua/plugins/lsp.lua` — overrides `mason-lspconfig`, adds `lazyvim.plugins.extras.lang.nix`.

**LSP servers provided via Nix (`home.nix` extraPackages):**

| Binary | Purpose |
|---|---|
| `lua-language-server` | Lua / Neovim config |
| `nixd` | Nix LSP (flake-aware, replaces `nil`) |
| `nix-doc` | Hover docs for Nix builtins (used by nixd) |
| `typescript-language-server` | TypeScript / JavaScript |
| `pyright` | Python |
| `stylua` | Lua formatter |
| `nixpkgs-fmt` | Nix formatter |
| `black` | Python formatter |
| `ripgrep`, `fd` | Telescope dependencies |
| `tree-sitter`, `gcc` | Treesitter parser compilation |

**`nil` vs `nixd`:** Switched from `nil` to `nixd`. `nixd` is flake-aware (understands your actual flake inputs, gives real NixOS option completions), actively maintained. `nil` is largely in maintenance mode as of 2025/2026.

**Mason consequence:** `:Mason` UI still works for discovery. It will show Nix-managed servers as "not installed" (because Mason didn't install them) — this is cosmetically misleading but functionally harmless. Do not use `:MasonInstall` for servers — use `home.nix` instead.

---

### 3. Shell: bash login → nushell interactive, with nix-shell guard

**Decision:** Bash is the PAM/systemd login shell. `~/.bashrc` `exec nu` to enter nushell for interactive use. Added `$IN_NIX_SHELL` guard to skip the exec inside `nix-shell` environments.

**Why the guard:** `nix-shell` (and `nix develop`) sets `IN_NIX_SHELL=impure` (or `pure`). Without the guard, entering a nix-shell drops you into bash, which immediately `exec nu`, which inherits the nix-shell's modified PATH — but nushell's init scripts (zoxide integration, aliases, etc.) were designed for the normal environment. The result is broken `cd`, undefined `z`, and confusing behavior. The guard keeps you in bash inside nix-shell, which is correct behavior.

**Alias in wrong file (fixed):** Previously aliases were in `envFile.text` (env.nu). Aliases are invalid in env.nu and must be in config.nu. All aliases moved to `configFile.text`.

---

### 4. Zoxide with `--cmd cd`

**Decision:** `programs.zoxide.options = [ "--cmd cd" ]`

**Why:** Without this, zoxide provides `z` and `zi` as custom commands. The old config had `alias cd = z` in env.nu (wrong file, wrong approach). With `--cmd cd`, zoxide's nushell integration directly overrides the built-in `cd` command with a zoxide-powered version. This means:
- `cd foo` uses frecency-based directory jumping
- No manual alias needed
- `cd` is always defined (comes from zoxide init, not a fragile alias)
- `zi` is still available for interactive fuzzy selection

---

### 5. Podman rootless socket for lazydocker

**Decision:** Define a `systemd.user.sockets.podman` unit in home.nix. Set `DOCKER_HOST` in nushell `envFile.text` to `unix://$XDG_RUNTIME_DIR/podman/podman.sock`.

**Why:** `lazydocker` (and `docker` CLI via podman's dockerCompat) communicates over a Unix socket. Podman supports both rootful (system socket, requires root) and rootless (user socket, safer). The user socket lives at `/run/user/1000/podman/podman.sock`. `DOCKER_HOST` tells the Docker-protocol clients where to find it.

**Activation:** After `nixos-rebuild switch`, run:
```
systemctl --user enable --now podman.socket
```
Or just log out and back in — the socket unit is wired to `sockets.target`.

---

### 6. Screen lock: hyprlock + hypridle

**Decision:** `programs.hyprlock.enable = true` + `services.hypridle` in home.nix.

**Timeouts:**
- 5 minutes idle → `hyprlock` (lock screen)
- 10 minutes idle → `hyprctl dispatch dpms off` (display off)
- On resume → `hyprctl dispatch dpms on`
- Before sleep → `hyprlock`

**Keybind:** `Super+Shift+L` → `hyprlock` (Super+L is taken by `movefocus right` in vim-hjkl nav).

**Theme:** `catppuccin.hyprlock.enable = true` applies Mocha theme to the lock screen.

---

### 7. Display manager: SDDM + uwsm

**Decision:** Keep `services.displayManager.sddm` (already configured, Wayland-enabled). Add `programs.uwsm.enable = true` to wrap Hyprland in a proper systemd user session.

**Why SDDM (not greetd):** SDDM was already in place and works reliably. No reason to swap it for a minimal TUI greeter when the goal is just to add uwsm on top.

**Why uwsm:** Properly wraps Hyprland in a systemd user session. Eliminates the "not designed to be launched by DM" journal warning. Handles XDG session activation, D-Bus scoping, and clean session teardown on logout.

**Side effect:** `programs.uwsm.enable = true` silently sets `services.dbus.implementation = "broker"`. First activation requires `nixos-rebuild boot` (not `switch`) because the running D-Bus daemon cannot be hot-swapped.

**Required:** `wayland.windowManager.hyprland.systemd.enable = false` — uwsm manages the systemd session; enabling both causes double session management.

---

### 8. NetworkManager applet

**Decision:** Add `networkmanagerapplet` to packages, `exec-once = nm-applet --indicator` in `hyprland.conf`.

**Effect:** `nm-applet` runs in the background and places an icon in the Waybar tray. Click to manage WiFi networks, VPN connections. `on-click` on the network Waybar module opens `nm-connection-editor` for full configuration.

---

### 9. Function / media keys + OSD (swayosd)

**Decision:** Use `swayosd-client` for all volume/brightness binds in `hyprland.conf`. Run `swayosd-server` as an `exec-once` autostart. Both installed via `home.packages`.

**Why swayosd:** Raw `wpctl`/`brightnessctl` calls work but give no visual feedback. `swayosd` shows a popup OSD overlay on key press — similar to what KDE/GNOME show.

**`hyprland.conf` binds:**

| Key | Action |
|---|---|
| `XF86AudioRaiseVolume` | `swayosd-client --output-volume raise` |
| `XF86AudioLowerVolume` | `swayosd-client --output-volume lower` |
| `XF86AudioMute` | `swayosd-client --output-volume mute-toggle` |
| `XF86MonBrightnessUp` | `swayosd-client --brightness raise` |
| `XF86MonBrightnessDown` | `swayosd-client --brightness lower` |
| `XF86AudioPlay` | `playerctl play-pause` |
| `XF86AudioNext` | `playerctl next` |
| `XF86AudioPrev` | `playerctl previous` |

`brightnessctl`, `playerctl`, and `swayosd` are in `home.packages`. User `gl` is in the `video` group (required for brightness).

---

### 10. Credential management

**Decision:** KeePassXC + `git-credential-keepassxc`.

**KeePassXC:** Offline password manager. `.kdbx` vault file. Browser extension works with Firefox and Chrome.

**git-credential-keepassxc:** Bridges git credential requests directly to the KeePassXC daemon over a socket. Set via `programs.git.extraConfig.credential.helper = "keepassxc"`. First HTTPS push prompts KeePassXC to unlock/approve; subsequent operations retrieve credentials silently. No plaintext `~/.git-credentials`.

**First-time setup:**
1. Open KeePassXC, unlock vault
2. Enable Browser Integration in KeePassXC settings
3. Do a `git push` to a HTTPS GitHub remote — KeePassXC prompts to allow access once
4. Credentials stored in KeePassXC vault; git never asks again

---

### 11. Automatic garbage collection

**Decision:** `nix.gc` in `configuration.nix`.

```nix
nix.gc = {
  automatic = true;
  dates     = "weekly";
  options   = "--delete-older-than 14d";
};
```

Mirrors the manual `gcold` alias. Runs weekly via systemd timer. Keeps last 14 days of generations.

---

### 12. OpenCode

**Decision:** `programs.opencode.enable = true` (not `home.packages`) so `catppuccin.opencode.enable = true` can write the theme config.

**Why the module matters:** `catppuccin.opencode` checks `config.programs.opencode.enable`. If opencode is installed via `home.packages` instead, the catppuccin module is a no-op and no theme is written.

**Settings:** `autoshare = false`, `autoupdate = true`.

**Session persistence:** OpenCode sessions are stored in `~/.local/share/opencode/`. Sessions survive terminal closes, rebuilds, and reboots.

**Context resumption:** To give a new OpenCode session full context of this configuration, paste the contents of this file (`DECISIONS.md`) at the start of the conversation.

---

### 13. Google Chrome (replaces Chromium)

**Decision:** `programs.google-chrome.enable = true` with Wayland + dark mode `commandLineArgs`.

**Why Chrome over Chromium:** Better codec support — Widevine DRM (Netflix, Spotify), hardware-accelerated H.264. Same Blink engine; no color or rendering differences. Unfree; allowed via `nixpkgs.config.allowUnfree`.

**Flags set:**
- `--enable-features=WebUIDarkMode` — dark browser chrome
- `--force-dark-mode` — auto-dark-mode CSS on all sites
- `--ozone-platform=wayland` — native Wayland rendering
- `--enable-wayland-ime` — input method support on Wayland

**Catppuccin theme:** Must be installed manually from the Chrome Web Store. Browser extensions cannot be declaratively managed for Chrome.

---

### 14. GTK theming + cursor

**Decision:** `gtk.enable = true` with `gtk-application-prefer-dark-theme = 1`. `catppuccin.gtk.icon.enable = true` for Papirus folders. `home.pointerCursor` with `catppuccin-cursors.mochaDark`.

**Note:** `catppuccin.gtk` window decoration theming was archived upstream (see https://github.com/catppuccin/gtk/issues/262) and removed from catppuccin-nix. Only icon theming (`catppuccin.gtk.icon`) remains in the module.

---

### 15. Bluetooth

**Decision:** `hardware.bluetooth.enable = true` + `hardware.bluetooth.powerOnBoot = true` + `services.blueman.enable = true` in `configuration.nix`. `blueman-applet` launched as `exec-once` in `hyprland.conf`.

**Note:** `services.blueman` is a NixOS system-level option, not a home-manager option.

---

### 16. Font rendering

**Decision:** `fonts.fontconfig.subpixel.rgba = "rgb"` and `fonts.fontconfig.hinting.style = "medium"` in `configuration.nix`.

**Why:** Defaults (`rgba = "none"`, `hinting = "slight"`) produce noticeably blurry text on standard LCD/LED panels. `rgb` subpixel rendering and `medium` hinting produce sharper results on non-HiDPI displays.

---

### 17. Volume mixer: pwvucontrol

**Decision:** `pwvucontrol` in `home.packages` instead of `pavucontrol`.

**Why:** Native PipeWire GUI mixer. `pavucontrol` works via the PipeWire PulseAudio compatibility layer but is architecturally mismatched — it cannot show PipeWire-specific routing. `pwvucontrol` shows full PipeWire node graph, stream routing, and per-application volume.

---

### 18. XWayland keyboard noise suppression

**Decision:** `kb_model = pc105` in the `input {}` block of `hyprland.conf`.

**Why:** Without it, xkbcomp emits harmless but noisy journal warnings on XWayland startup:
- `Unsupported maximum keycode 708`
- `Virtual modifier Hyper/ScrollLock multiply defined`

Setting an explicit keyboard model suppresses these. No functional change.

---

### 19. Waybar right-side redesign (2026-03-10)

**Decision:** Replace bare `cpu`/`memory` percentage readouts with a richer right section modeled on the mechabar/rubyowo patterns popular on r/unixporn.

**New right module order:** `mpris | idle_inhibitor | backlight | battery | pulseaudio | network | tray | custom/power`

**Removed:** `cpu`, `memory` — bare `{usage}%` / `{used}G` is universally considered ugly on styled bars. If system stats are needed, `btop` is a hotkey away.

**Added modules:**

| Module | Purpose | Accent color |
|---|---|---|
| `mpris` | Current track from any MPRIS player (Spotify, Chrome, Firefox, VLC). Hidden when nothing playing. | `@mauve` |
| `idle_inhibitor` | Toggle sleep/lock prevention. Active=`󰒳` inactive=`󰒲`. | `@peach` (red when active) |
| `backlight` | Screen brightness with icon steps. Reads `intel_backlight`. | `@yellow` |
| `custom/power` | `󰐥` icon, `on-click = "wlogout"`. Gains red filled bg on hover with right-cap border-radius. | `@red` |

**Updated:**
- `pulseaudio` `on-click` changed from `wpctl set-mute` toggle to `pwvucontrol` (open mixer). Mute is already on the hardware `XF86AudioMute` key via swayosd.
- Each right module gets its own catppuccin accent color instead of a shared `@subtext1`.

**CSS pattern:** Individual accent per module (mechabar style). `#custom-power:hover` fills red and gets `border-radius: 0 12px 12px 0` — capping the right end of the modules-right pill on hover.

**wlogout:** Added to `home.packages`. Keybind: `Super+Shift+E` in `hyprland.conf`.

**Reference:** mechabar (748 stars), rubyowo dotfiles (official catppuccin/waybar preview).

---

### 20. Waybar further refinements (2026-03-10)

**Volume icons:** Replaced generic Unicode codepoints with explicit nf-md icons `󰕿`/`󰖀`/`󰕾` (volume low/medium/high). Previous codepoints were unreliable across Nerd Font versions.

**WiFi format:** Changed `format-wifi` from `" {essid}"` to `""` (icon only). ESSID is redundant — nm-applet tray already shows it on hover, and the network name clutters the bar.

**Bluetooth (updated):** Removed `blueman-applet` from hyprland autostart. It was spawning `blueman-tray` which put a redundant BT icon in the tray (duplicate of `custom/bluetooth` module) and rendered as a broken icon under the Papirus icon theme. `blueman-manager` is still available via click on the `custom/bluetooth` waybar module. `nm-applet` is kept — it provides the working small-popup WiFi switcher in the tray.

---

### 21. KDE Plasma 6 → Hyprland migration (2026-03-14)

**Decision:** Migrate from KDE Plasma 6 + plasma-manager to Hyprland + the following stack:

| Component | Choice | Replaces |
|---|---|---|
| Compositor | Hyprland (master layout) | KDE Plasma 6 + KWin |
| Bar | Waybar (Hyprlust-inspired) | KDE top panel |
| Launcher | rofi-wayland | wofi / KRunner |
| Notifications | swaync | mako |
| Wallpaper | hyprpaper | swww |
| Screen lock | hyprlock + hypridle | DPMS only |
| Tiling | Hyprland master layout | Polonium (KWin script) |

**Why:** KDE Plasma 6 + Polonium provided auto-tiling but with significant overhead (plasmashell, baloo, akonadi, kded, etc.). Hyprland is purpose-built for tiling on Wayland with a fraction of the resource usage. plasma-manager, while functional, required maintaining a large `programs.plasma {}` block for things that Hyprland handles natively or via simpler dotfiles.

**What was removed:**
- `plasma-manager` flake input (`flake.nix`)
- `plasma-manager.homeModules.plasma-manager` from nixbox home-manager imports
- `services.desktopManager.plasma6.enable = true` (`configuration.nix`)
- `programs.kdeconnect.enable = true` (`configuration.nix`)
- `polonium` from `environment.systemPackages` (`configuration.nix`)
- Entire `programs.plasma { ... }` block in `home/gui.nix` (~130 lines)
- `catppuccin-kde` and `kdePackages.qtstyleplugin-kvantum` packages
- `home.file.".config/Kvantum/..."` manual theme file
- `config/mako/config` dotfile (replaced by swaync)
- `config/wofi/` directory (replaced by rofi)

**Waybar design:** Inspired by Hyprlust (github.com/NischalDawadi/Hyprlust). Uses the `[TOP] wallust_new` config layout with `[Catppuccin] Mocha.css` style as reference. Ported from wallust dynamic colors to static Catppuccin Mocha via `catppuccin.waybar.enable = true` (`@import mocha.css` prepended automatically). Layout: floating pill, 1200px wide, 5px top margin, 50px side margins. Left: menu icon + window title. Center: 4 persistent workspaces with app icons. Right: idle_inhibitor + hub group (clock, network, bluetooth, pulseaudio, tray) + power button.

**Rofi config:** `programs.rofi` with `package = pkgs.rofi-wayland`. `catppuccin.rofi.enable = true` handles theming. `extraConfig` sets modi, display labels, hover-select behavior.

**Build note:** First activation after this change MUST use `nixos-rebuild boot` (not `switch`) due to `programs.uwsm.enable = true` switching D-Bus implementation to `broker`.

---

## Known Issues / Future Work

- **Wallpaper:** `hyprpaper` is enabled but no wallpaper is set. Uncomment and fill in the `preload` and `wallpaper` lines in `programs.hyprpaper.settings` in `home/gui.nix`.
- **`winbox` host (NVIDIA):** Stubbed in `flake.nix` and commented out. Needs `hosts/winbox/` directory with `configuration.nix` and `hardware-configuration.nix`. NVIDIA will require `hardware.nvidia.*` config and a different GPU VA-API setup.
- **`sops-nix`:** Not yet configured. For encrypting secrets within the Nix config repo (WiFi passwords, API keys, etc.), `sops-nix` is the standard approach. Add as a flake input when needed.
- **`nix-doc` + `nixd` integration:** `nixd` can be pointed at your flake for full option completions. Add a `.neoconf.json` or `nixd` config in your nvim config pointing to `/etc/nixos/flake.nix`.
- **Mason cosmetic issue:** `:Mason` shows Nix-provided LSP servers as "not installed." This is expected and harmless — do not use `:MasonInstall` for them.

---

## Common Commands

```nushell
rb       # sudo nixos-rebuild switch --flake /etc/nixos#nixbox
update   # sudo nix flake update /etc/nixos  (updates flake.lock)
gcold    # sudo nix-collect-garbage --delete-older-than 14d
nsh      # nix-shell -p <package>   (temporary shell with a package)
```

```bash
# Emergency / recovery (inside nix-shell, stays in bash):
nix-shell -p <pkg>   # IN_NIX_SHELL is set, bash does not exec nu
```

```nushell
# Rollback to previous generation
sudo nixos-rebuild switch --rollback
# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

---

## Session — 2026-03-14 (Hyprland rice refinement)

### Upstream API fixes caught by `nix flake check`
- `programs.hyprpaper` does not exist in home-manager; corrected to `services.hyprpaper`.
- `pkgs.rofi-wayland` was removed from nixpkgs (merged into `pkgs.rofi`); `package` updated to `pkgs.rofi`, redundant `home.packages` entry removed.

### Decision 22 — Default layout: dwindle (binary tree)
**Chosen:** `general { layout = dwindle }` with `dwindle { pseudotile = true; preserve_split = true }`.

Rationale: user explicitly wanted "binary tree" splits. Dwindle is Hyprland's name for recursive binary tree tiling. Master layout is kept available in the config (can be activated at runtime with `hyprctl keyword general:layout master`) but is no longer the default.

New keybinds added for dwindle:
- `$mod, T` → `togglefloating`
- `$mod, P` → `pseudo` (toggle pseudotile)
- `$mod, J` → `layoutmsg, togglesplit` (toggle split direction)
- `$mod, Tab` / `$mod SHIFT, Tab` → workspace cycle (wraps via `binds { allow_workspace_cycles = true }`)

### Decision 23 — Waybar full rewrite
**Previous state:** Broken — `group/hub` drawer had no CSS, `exec = "echo ..."` tooltip hack was fragile, hardcoded `width = 1200` + `margin-left/right = 50` caused overflow, hardcoded hex colors in calendar bypassed Catppuccin variables.

**New design:**
- Full-width bar (no `width`, no `margin-left/right`), `height = 36`, `margin-top = 6`
- Module layout: `[menu | window] [workspaces] [clock | network | pulseaudio | tray | power]`
- Dropped: `group/hub`, `idle_inhibitor`, `bluetooth`, `custom/separator#blank`
- Three borderless floating pills (`.modules-left/center/right`): `background: alpha(@base, 0.92)`, `border-radius: 10px` — no border
- Color-per-module from Hyprlust Catppuccin Mocha: `@mauve` (window), `@yellow` (clock), `@teal` (network), `@sapphire` (pulseaudio), `@rosewater` (menu), `@red` (power)
- Workspace icons: `󰎤 󰎧 󰎪 󰎭` (Nerd Fonts boxed numerals) — persistent, no active-only
- Power button: `󰐥` icon, red fill + right-cap border-radius on hover (from Hyprlust)
- Removed all hardcoded hex colors; calendar format uses `@text`, `@yellow`, `@red` Catppuccin vars

### Decision 24 — hyprland.conf overhaul
Additions vs previous version:
- Full `env = ...` block (was entirely missing): `XCURSOR_SIZE`, `QT_QPA_PLATFORM`, `GDK_BACKEND`, `MOZ_ENABLE_WAYLAND`, `XDG_*`, `SDL_VIDEODRIVER`, `_JAVA_AWT_WM_NONREPARENTING`, `OZONE_PLATFORM`
- Animations upgraded to MD3 bezier curves (`md3_decel`, `md3_accel`, `menu_decel`, `menu_accel`) from ML4W/end-4; added `layersIn/Out` and `fadeLayersIn/Out` so rofi/swaync slide in correctly
- `decoration`: `rounding 10`, `blur { xray = true; passes = 4 }`, `dim_inactive = true`, `shadow range = 20`
- `binds { allow_workspace_cycles = true }`
- `misc { focus_on_activate = true }`
- Window rules section added: float common dialogs, float `blueman-manager`/`pwvucontrol`/`nm-connection-editor`/`keepassxc`, `noblur` for kitty, `immediate` for fullscreen
- Removed dangerous `$mod SHIFT, M, exit` bind (wlogout on `$mod SHIFT, E` is the safe exit path)

### Decision 25 — windowrule migration, calendar Pango colors, rofi blur, wallpaper selector

**windowrule migration:** Hyprland 0.54 deprecated `windowrulev2` — all 15 rules triggered config error popups on startup. Renamed all to `windowrule` (same field syntax, keyword change only).

**Calendar Pango colors:** Waybar calendar `format` strings use Pango markup. Pango does not resolve GTK CSS variables (`@text` etc.) at render time — they were being passed as literal strings and silently ignored. Replaced with hardcoded Catppuccin Mocha hex values: `@text` → `#cdd6f4`, `@yellow` → `#f9e2af`, `@red` → `#f38ba8`.

**rofi blur:** Added `layerrule = blur, rofi` and `layerrule = ignorezero, rofi` to `hyprland.conf` so the compositor blur effect applies behind rofi's `transparency="real"` layer surface.

**Wallpaper selector:**
- Stayed with hyprpaper (not swww) — already configured, static wallpapers are sufficient.
- `wallpaper-select`: rofi dmenu with `-format 'i'` returns selection index; resolves to path from `images[]` bash array built from `~/Pictures/wallpapers/`; applies via `hyprctl hyprpaper preload` + `hyprctl hyprpaper wallpaper`; persists path to `~/.config/hypr/.wallpaper_last`.
- `wallpaper-init`: reads `~/.config/hypr/.wallpaper_last`, sleeps 0.5 s for hyprpaper to start, re-applies on login via `exec-once`.
- Both scripts exposed as `pkgs.writeShellScriptBin` in `home.packages` (gui.nix) so they are on `$PATH`.
- Keybind: `$mod W` → `wallpaper-select`.
- rofi theme: `config/rofi/wallpaper.rasi` — 4-column thumbnail grid, `transparency="real"`, near-transparent background, mauve border, `8em` icon size for image previews.
- `~/Pictures/wallpapers/` does not exist by default — user must create and populate it before the selector is functional.

### Decision 26 — windowrule syntax correction, layerrule syntax fix, Hebrew keyboard, dwindle split direction (2026-03-14)

**windowrule syntax (corrected from Decision 25):** Decision 25 was wrong. In Hyprland 0.54:
- `windowrule = float, class:^regex$` → **hard config error** — the parser treats `float` as a field name expecting `= value`, so `class:` is rejected as a malformed value.
- `windowrulev2 = float, class:^regex$` → shows a deprecation warning popup on startup but **works correctly** (rule is applied).

Reverted all 15 rules back to `windowrulev2`. Deprecation warnings are acceptable; hard errors are not.

**layerrule syntax fix:** In 0.54 the `layerrule` comma separator between rule and target was removed.
- Wrong: `layerrule = blur, rofi`
- Correct: `layerrule = blur rofi`

Both `blur` and `ignorezero` rules for rofi updated to the no-comma form.

**Hebrew keyboard layout:** Added `kb_layout = us,il`, `kb_variant = ,` (empty variant = standard Hebrew), and `kb_options = grp:alt_shift_toggle` to the `input {}` block. Alt+Shift switches between US and Hebrew. No extra keybind needed — handled entirely by xkb at the compositor level.

**Dwindle force_split:** Added `force_split = 2` to the `dwindle {}` block. With the default (`0`), new windows open on the side of the current window that the mouse cursor is on. `force_split = 2` always opens new windows to the right (horizontal split) or below (vertical split), regardless of cursor position — predictable behavior for keyboard-driven workflows.
