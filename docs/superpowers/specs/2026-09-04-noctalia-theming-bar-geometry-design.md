# Design: nvim colorscheme sync, bar layout, desktop geometry, idle-lock fix

Date: 2026-09-04
Status: approved, not yet implemented (except Thread 4, already applied)

Four independent threads, sharing one rebuild.

---

## Thread 1 — Noctalia picks nvim's colorscheme *plugin*, not its pixels

### Problem

`home/lazyvim.nix` drives nvim's colors from Noctalia's community `neovim`
template, which renders a matugen palette into `base16-nvim`'s 16 slots.
base16 is a **semantic** contract needing eight distinct hues; Noctalia derives
a Material-You **tonal** palette (one hue plus tints). Forcing one into the
other is structurally lossy. Measured from the generated
`~/.config/nvim/lua/matugen.lua`:

| slot | base16 meaning | value written |
|---|---|---|
| `base09` | constants — orange | `#9ece6a` (green) |
| `base0B` | strings — green | `#7aa2f7` (blue) |
| `base0C` | escapes — cyan | `#c1e996` (lime) |
| `base0D` / `base0E` / `base0F` | functions / keywords / deprecated | `#87abf8` / `#af89f6` / `#cfb8f9` |

Functions, keywords and types collapse into three near-identical blue-purples.
No palette switch fixes this; the mapping is wrong by construction.

Second defect: the template's `post_hook` is `pkill -SIGUSR1 nvim`, and its
docs require a matching `Signal`/`SIGUSR1` autocmd in the lua half.
`plugins.colorscheme` never registered one, so live reload never worked — the
palette only ever applied at nvim startup.

### Decision

Noctalia selects **which official colorscheme plugin** nvim uses. Every scheme
is then hand-tuned by its own author, with real treesitter/LSP/plugin
integration.

**Live reload is explicitly out of scope** (ghostty already requires a restart
for the same reason). This removes the SIGUSR1 handler, the cache
invalidation, and the `Signal` autocmd entirely.

### Mechanism

`[hooks]` is a real Noctalia config table (`src/config/config_types.h:1390`,
`docs/user/automation/hooks.mdx`) and is seedable from Nix. A shell command
runs on:

- `colors_changed` — after the palette resolves
- `theme_mode_changed` — light/dark flip
- `started` — once at login, so a fresh session is correct

The script reads `noctalia msg color-scheme-get` (prints `<source> <name>`) and
`noctalia msg theme-mode-get`, then writes:

```lua
-- $XDG_STATE_HOME/noctalia/nvim-theme.lua
return { colorscheme = "tokyonight-night", background = "dark" }
```

written to a temp file and `mv`'d into place so nvim never reads a partial file.

nvim `dofile`s it under `pcall`, with a fallback that survives Noctalia not
running at all (TTY, ssh, first boot):

```lua
colorscheme = function()
  local ok, t = pcall(dofile, state .. "/noctalia/nvim-theme.lua")
  if not (ok and type(t) == "table") then
    t = { colorscheme = "tokyonight-night", background = "dark" }
  end
  vim.o.background = t.background or "dark"
  if not pcall(vim.cmd.colorscheme, t.colorscheme) then
    vim.cmd.colorscheme("tokyonight-night")
  end
end
```

`vim.o.background` is set unconditionally — required by `gruvbox.nvim`, which
is a single colorscheme switching on `background`; harmless for the rest.

### Mapping table

Nine of Noctalia's ten builtins map to a real plugin. Nord, Dracula and
Eldritch have no light variant and fall back in light mode.

| Noctalia builtin | plugin | dark | light |
|---|---|---|---|
| Tokyo-Night | `folke/tokyonight.nvim` *(LazyVim default)* | `tokyonight-night` | `tokyonight-day` |
| Catppuccin | `catppuccin/nvim` *(LazyVim default)* | `catppuccin-mocha` | `catppuccin-latte` |
| Gruvbox | `ellisonleao/gruvbox.nvim` | `gruvbox` | `gruvbox` |
| Kanagawa | `rebelot/kanagawa.nvim` | `kanagawa-wave` | `kanagawa-lotus` |
| Rosé Pine | `rose-pine/neovim` | `rose-pine-main` | `rose-pine-dawn` |
| Ayu | `Shatur/neovim-ayu` | `ayu-dark` | `ayu-light` |
| Nord | `shaunsingh/nord.nvim` | `nord` | *`tokyonight-day`* |
| Dracula | `Mofiqul/dracula.nvim` | `dracula` | *`tokyonight-day`* |
| Eldritch | `eldritch-theme/eldritch.nvim` | `eldritch` | *`tokyonight-day`* |
| Noctalia, or any non-builtin source | — | `tokyonight-night` | `tokyonight-day` |

`Tokyo-Night`'s `base00` is `#1a1b26`, which is tokyonight **night** — not
LazyVim's stock `moon` (`#222436`). Using `night` makes the editor background
exactly match the bar.

Seven new plugin fetches; tokyonight and catppuccin already ship in LazyVim's
`colorscheme.lua`. All seven verified present in `nixpkgs#vimPlugins`.
`lazyvim-nix` resolves them from the lua spec automatically
(`nix/lib/plugin-resolution.nix`), the same path `base16-nvim` takes today.
All specs are `lazy = true`; lazy.nvim's colorscheme handler loads the right
one on demand, exactly as LazyVim's own tokyonight/catppuccin specs do.

### File split

Mirrors the existing arrangement so the repo's story stays symmetric:

- `home/noctalia.nix` — the script (`pkgs.writeShellApplication`) and the
  `hooks` wiring, referenced by absolute store path. Noctalia owns theming.
- `home/lazyvim.nix` — plugin specs and the reader above.

Kept in separate files rather than merging via home-manager option merging:
`programs.noctalia.settings` is typed `oneOf [ tomlFormat.type str path ]`,
whose cross-module merge behaviour is subtle. One module writes it.

### Removals

- `base16-nvim` from `plugins.colorscheme`
- `community_ids = [ "neovim" ]` → `[ ]` in `home/noctalia.nix`
  (verified: `settings.toml` has **no** `[theme.templates]` section, so the
  Nix value is authoritative and this takes effect)
- `~/.config/nvim/lua/matugen.lua` — orphaned
- `~/.config/nvim/lua/plugins/base16.lua` — **hand-written, not a store
  symlink**, so no rebuild will ever remove it. It calls `matugen.setup()`
  independently and would override everything. Must be deleted manually.
- `theme.builtin` `"Catppuccin"` → `"Tokyo-Night"`, matching the runtime value
  already in `settings.toml`.

---

## Thread 2 — bar layout

```
┌ workspaces  ⧉ active_window ┐┌ ♪ media ┐    ┌ clock ┐    ┌ cpu ram temp ┐┌ vol bat tray net bt cc ┐
```

- `media` becomes its own island, second from left.
- The sysmon gauges split from `volume`/`battery`; those join the tray group.
- `active_window` joins the workspaces island, filling the dead space between
  workspaces and the clock without adding a sixth capsule.

`media` keeps `hide_when_no_media = true`: as a standalone capsule the island
appears and disappears cleanly instead of a capsule resizing mid-flight, and
`workspaces` is leftmost so nothing shifts.

The comment in `home/noctalia.nix` claiming v5.0.1 has no active-window widget
is **wrong** and gets deleted. `[widget.active_window]` exists with
`icon_size`, `max_length`, `min_length`, and `title_scroll`
(`docs/user/bar/widgets/active-window.mdx`). `title_scroll` stays `"none"` —
`"always"` is a marquee in peripheral vision all day.

---

## Thread 3 — one gap constant, one corner radius

### Measured before

```
HDMI-A-1  1920x1080 @1.25  →  1536x864 logical
reserved  = [left 0, top 34, right 0, bottom 0]   # margin_edge 4 + thickness 30
bar layer = x=8  y=4  w=1520  h=30
```

| gap | px | source |
|---|---|---|
| screen edge ↔ window | 5 | `gaps_out` |
| screen edge ↔ outermost island | **17** | `margin_ends 8` + `padding 9` |
| screen top ↔ island top | ~7.6 | `margin_edge 4` + capsule inset |
| island bottom ↔ window top | ~8.6 | derived |
| window ↔ window | 4 | `gaps_in 2` ×2 |
| island ↔ island | 5 | `widget_spacing` |

Six gaps, five values. `padding` stacks on `margin_ends` (docs: *"main-axis
padding from bar edges to start/end widget sections"*), which is why the
horizontal case is 17px rather than the 8 it looks like.

### Decision: everything is 4px

The rule is `gaps_in = gaps_out / 2` (Hyprland's `gaps_in` is a half-gap), then
every bar margin equals `gaps_out`.

```
hypr/hyprland.conf     gaps_in = 2 (unchanged)   gaps_out = 5 → 4

home/noctalia.nix      margin_edge       4 (unchanged)
  bar.default          margin_ends       8 → 0
                       padding           9 → 4
                       widget_spacing    5 → 4
                       capsule_thickness (new) 1.0
                       thickness        30 (unchanged)
```

`margin_ends = 0` costs nothing visually — `background_opacity = 0.0` makes the
strip invisible — and lets the whole top strip stay right-clickable for Control
Center. `capsule_thickness = 1.0` (default `0.76`, `config_schema.cpp:2232`)
makes islands fill the strip so their top edge sits exactly at `margin_edge`.

Result: screen↔window, screen↔island, island↔window, island↔island and
window↔window all become **4**.

### Rounding

Hyprland windows are `rounding = 8`. Islands take `radius = 8`, so bar chrome
and window content share one corner language.

The **concentric-radius rule** — a rounded box inside another with gap `g` only
looks right when `outer = inner + g` — then fixes the nested elements:

- workspace pills sit `6` inside an island of radius `8` → `capsule_radius = 2`.
  (`capsule_radius` is not only for capsule mode: docs state it is *"also used
  by workspace pills and taskbar workspace groups"*.)
- windows are `rounding = 8` sitting `4` inside the screen → screen corners want
  `8 + 4 = 12`. `[shell.screen_corners]` is enabled at `size = 12`, replacing
  its default `32` which would have been badly wrong.

### Also

- **`capsule_padding = 5.0` is deleted — it is a no-op.** Per
  `docs/user/bar/index.mdx:211` it is the padding for *per-widget* capsules,
  which exist only when `capsule = true`. This config uses `capsule_group`
  exclusively, and groups read their own `padding` key. Replaced by explicit
  `padding = 6` on each group so the concentric math above is written down
  rather than inherited.

### Rejected

- **Bar shadow.** Windows cast `shadow range = 12`, the bar is `shadow = false`.
  `bar.cpp:727` feeds the shadow config into `reservedBarExclusiveZone`, so
  enabling it changes reserved space and shifts every window — directly
  breaking the uniform-4 system, for an effect already found hazy.
- **Island outline.** A border on a 30px island reads as clutter; the 0.85
  frosted fill already separates it from the wallpaper.

---

## Thread 4 — hypridle lock loop (APPLIED)

### Problem

`hypr/hypridle.conf` set `lock_cmd = loginctl lock-session`. hypridle
**subscribes** to logind's `Lock` D-Bus signal; `loginctl lock-session`
**emits** it. Self-triggering loop, verbatim in the journal:

```
[LOG] Executing loginctl lock-session
[LOG] Got dbus .Session
[LOG] Got Lock from dbus
[LOG] Locking with loginctl lock-session
```

Introduced by e82071e ("native lock").

### Measured

| | before | after |
|---|---|---|
| fork rate | **3110 /sec** | 5 /sec |
| processes since boot | 2.89M in 4.3h | — |
| package temp | 85 °C | **56 °C** |
| TCPU | 89 °C | 59 °C |
| fans | 5400 / 5700 rpm | **2500 / 2800 rpm** |
| mean core clock | 3780 MHz | 2165 MHz |
| load average (1m) | 7.34 | 2.27 |
| CPU user/idle | 19.6% / 58.1% | 0.4% / 89.3% |

The CPU was 92% idle throughout; cpu0 alone logged 17.3M C1E entries. The heat
came from ~1500 wakeups/sec/core preventing deep C10 residency and pinning
clocks near maximum under `platform_profile = performance` (PL1 100W / PL2
115W), not from utilisation.

`hypridle`, `dbus-broker`, `polkitd`, `thermald` and `systemd-logind` all
topped the process list before the fix and all fell to zero after — every one
was a symptom, not an independent fault.

### Fix

```
lock_cmd         = noctalia msg session lock
before_sleep_cmd = noctalia msg session lock
```

Noctalia listens for `Lock` (`src/dbus/logind/logind_service.cpp:94`) and only
ever calls `SetLockedHint` (`:142`), so it cannot re-enter. The listeners keep
`on-timeout = loginctl lock-session` — that is the correct idiom: ask logind to
broadcast `Lock`, which is what drives `lock_cmd`.

`hypr/hypridle.conf` is out-of-store symlinked (`home/default.nix:36`), so this
took effect with `systemctl --user restart hypridle`, no rebuild.

---

## Runtime state surgery

`~/.local/state/noctalia/settings.toml` holds a **full copy of `[bar.default]`**
— `start`, `end`, and all four `capsule_group` blocks — written by the Settings
GUI. settings.toml overrides config.toml per key, so **the Nix bar changes in
Threads 2 and 3 will do nothing until it is removed.** The bar would look
identical after `rb` and the edit would appear to have failed.

Delete only the `[bar.default]` section. Every scalar in it is byte-identical
to the Nix seed, so nothing is lost. The rest of the file is **not** in Nix and
must survive:

- `[lockscreen_widgets]` — hand-positioned login boxes for eDP-1 and HDMI-A-1
- `[wallpaper]` — directory plus default/last/per-monitor paths
- and on disk, `plugins/` (1.7M), `community-templates/` (768K),
  `usage_counts.json` (launcher frecency), `notification_history.json`

## Files changed

| file | change |
|---|---|
| `home/lazyvim.nix` | 7 colorscheme plugin specs; state-file reader; drop base16-nvim |
| `home/noctalia.nix` | theme-sync script + hooks; `builtin`; `community_ids = [ ]`; bar layout; geometry; radii; screen corners; drop `capsule_padding` |
| `hypr/hyprland.conf` | `gaps_out` 5 → 4 |
| `hypr/hypridle.conf` | **applied** — `lock_cmd` / `before_sleep_cmd` |
| `CLAUDE.md` | rewrite the "LazyVim **is** Noctalia-templated" paragraph |
| runtime | delete `[bar.default]` from `settings.toml`; delete two nvim lua files |

## Verification

1. `sudo nixos-rebuild switch --flake /etc/nixos#gpubox`
2. `hyprctl layers` — bar surface at `x=0 y=4`, reserved top `34`
3. `hyprctl clients` — window gaps of 4 on every edge
4. `nvim` — background `#1a1b26`; strings green, functions blue, constants
   orange (the three the old mapping got wrong)
5. Switch palette in Noctalia settings, restart nvim — colorscheme follows
6. `cat /proc/sys/kernel/ns_last_pid` twice — fork rate stays in single digits

## Open items, not in scope

- 7 zombie `sd_*` processes (speech-dispatcher module probes, ppid 48006)
- `rclone-bisync-gdrive.service` failing with a non-zero exit — likely the
  one-time `--resync` documented in `home/apps.nix` never ran
- `asusctl` / `services.asusd`: the `asus_custom_fan_curve` hwmon device is
  present and undriven. It is the real equivalent of Armoury Crate's fan
  curves. Not needed for the temperatures above, which are now normal.
