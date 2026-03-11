# Desktop Environment: Hyprland → KDE Plasma 6

> Written 2026-03-11. Personal decision journal — where my thinking landed on switching DEs.

---

## Current Situation

Hyprland is genuinely excellent: native tiling, total keyboard control, best-in-class animations. The problem isn't Hyprland itself — it's the surface area around it. Every component (Waybar, Wofi, Mako, swaylock, cliphist, xdg-desktop-portal-hyprland) is a separate project, separately configured, separately broken. Screen sharing required manual portal wiring. Hardware quirks (sleep/wake, multi-monitor) require manual intervention. The setup works, but it's fragile — one upstream change away from a debugging session.

I want to keep: elegant aesthetics, keyboard-driven workflow, smooth animations, minimal visual noise.
I want to lose: spending a Saturday debugging why screensharing stopped working.

---

## Candidate Comparison

| Dimension | Hyprland | KDE Plasma 6 | GNOME |
|---|---|---|---|
| Tiling | native, excellent | built into KWin (Plasma 6) | Pop Shell extension (fragile) |
| Keyboard shortcuts | total control | very deep, GUI-configurable | good defaults, hits walls fast |
| "Just works" hardware | often not | yes | best of three |
| Aesthetics OOB | none (DIY) | configurable | opinionated/minimal |
| Catppuccin support | ✓ via module | ✓ via Kvantum | ✓ via module |
| NixOS packaging | excellent | excellent (`programs.plasma`) | excellent |
| Wayland maturity | native | good, improving | best |
| Screensharing/portals | manual setup | OOB | OOB |
| Animation smoothness | best-in-class | good | good |

---

## Recommendation: KDE Plasma 6

KDE is the closest thing to Hyprland in philosophy: configure what you want, leave the rest alone. The key differences are that the defaults are *usable*, and the plumbing (portals, hardware, display management) works without me touching it.

**Why not GNOME:** GNOME is the right answer if the priority is pure zero-config hardware compatibility. It's the wrong answer for me — the moment you want non-default behavior, it fights back. Extensions (Pop Shell, custom shortcuts past a certain depth) become a maintenance burden across major version upgrades. GNOME assumes you want the GNOME workflow; I don't.

**Why KDE wins:**

- Plasma 6 has native tiling built into KWin — no Bismuth/Polonium scripts, no third-party patcher. It's a first-class KWin feature.
- KWin shortcuts are as deep as Hyprland's. Super+hjkl focus, Super+Shift+hjkl move, custom window rules — all configurable without scripting.
- On NixOS, `programs.plasma` (plasma-manager) gives declarative control over shortcuts, theme, panel layout, and behavior. The "NixOS problem" of KDE being hard to configure declaratively is solved.
- Catppuccin works system-wide via Kvantum + catppuccin-kde. Not as turnkey as the catppuccin/nix module approach, but functional and consistent.
- All the CLI tooling (nushell, neovim, kitty, zoxide, etc.) is unchanged — that layer lives in `home.nix` and transfers completely.

The tradeoff is losing Hyprland's animation smoothness (KWin is good, not best-in-class) and the pixel-perfect tiling control. That's a tradeoff I'm willing to make.

---

## Migration Path on NixOS

This is informational — not committed to yet.

```nix
# hosts/nixbox/configuration.nix
services.displayManager.sddm.enable = true;
services.displayManager.sddm.wayland.enable = true;
services.desktopManager.plasma6.enable = true;
```

```nix
# home.nix — add plasma-manager input to flake.nix first
programs.plasma = {
  enable = true;
  # declarative shortcuts, theme, panel config go here
};
```

- `greetd` can be swapped for SDDM — SDDM is the standard KDE display manager and integrates cleanly with Plasma session startup.
- `catppuccin.kde` is not currently in the catppuccin/nix flake; use Kvantum + catppuccin-kde manually for now.
- `wayland.windowManager.hyprland` block in `home.nix` gets removed; uwsm setup goes away.
- Everything in `base.nix` (if split out) or the non-Hyprland portions of `home.nix` carries over unchanged.
- Keep an eye on `xdg.portal` — Plasma sets this up automatically, but verify no conflicts with the old `hyprland` portal entry.
