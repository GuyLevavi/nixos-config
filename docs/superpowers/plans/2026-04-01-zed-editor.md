# Zed Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Zed editor to `home/gui.nix` with Catppuccin Mocha theming, basedpyright/ruff/nixd LSP support, no vim mode, and all AI/telemetry disabled.

**Architecture:** Single file change — `home/gui.nix`. Two additions: catppuccin enables in the theming section, and a `programs.zed-editor` block in the programs section. The home-manager module PATH-wraps the `zeditor` binary with LSP tools via `extraPackages`; the catppuccin-nix module injects the theme automatically when `programs.zed-editor.enable = true`.

**Tech Stack:** NixOS home-manager, `programs.zed-editor` module, `catppuccin/nix` flake module for Zed.

---

## File Map

| File | Change |
|------|--------|
| `home/gui.nix` | Add `catppuccin.zed.*` enables + `programs.zed-editor` block |

---

### Task 1: Add catppuccin.zed enables

**Files:**
- Modify: `home/gui.nix:14-19` (catppuccin module section)

- [ ] **Step 1: Add two lines to the catppuccin block**

  In `home/gui.nix`, the catppuccin section currently ends with `catppuccin.rofi.enable = true;` (line 19). Add immediately after:

  ```nix
  catppuccin.zed.enable = true;
  catppuccin.zed.icons.enable = true;
  ```

  Result should look like:
  ```nix
  catppuccin.kitty.enable = true;
  catppuccin.hyprland.enable = true;
  catppuccin.waybar.enable = true;
  catppuccin.hyprlock.enable = true;
  catppuccin.swaync.enable = true;
  catppuccin.rofi.enable = true;
  catppuccin.zed.enable = true;
  catppuccin.zed.icons.enable = true;
  ```

  Note: `catppuccin.zed` only fires when `programs.zed-editor.enable = true` — that's added in Task 2. These lines are inert until then.

- [ ] **Step 2: Verify file is still valid Nix syntax**

  ```bash
  nix-instantiate --parse /etc/nixos/home/gui.nix
  ```

  Expected: no output (parse success). Any error means a syntax mistake.

---

### Task 2: Add programs.zed-editor block

**Files:**
- Modify: `home/gui.nix` — add after the Kitty block (~line 418)

- [ ] **Step 1: Add the zed-editor block after the Kitty block**

  Locate the Kitty block which ends with `};` around line 418. Add the following immediately after it:

  ```nix
  # ── Zed Editor ────────────────────────────────────────────────────────
  # catppuccin.zed injects Mocha theme + catppuccin-icons extension.
  # extraPackages PATH-wraps the zeditor binary so LSP servers are found.
  # mutableUserSettings = true: Nix wins on rebuild, Zed can write between.
  programs.zed-editor = {
    enable = true;
    mutableUserSettings = true;

    extraPackages = with pkgs; [
      basedpyright             # Python LSP (matches nixvim)
      ruff                     # Python linter/formatter
      nixd                     # Nix LSP (flake-aware)
      nixpkgs-fmt              # Nix formatter
      bash-language-server
      yaml-language-server
      taplo                    # TOML LSP + formatter
      nodePackages.prettier    # YAML/JSON/Markdown formatter
    ];

    extensions = [
      "nix"
      "toml"
      "dockerfile"
      "env"
      "basedpyright"           # required: registers adapter name for language_servers
    ];
    # catppuccin module auto-adds "catppuccin" and "catppuccin-icons" — don't list here

    userSettings = {
      vim_mode = false;

      ui_font_family     = "JetBrainsMono Nerd Font";
      buffer_font_family = "JetBrainsMono Nerd Font";
      buffer_font_size   = 14;

      terminal.shell = { program = "nu"; };

      telemetry = {
        metrics     = false;
        diagnostics = false;
      };

      features.edit_prediction_provider = "none";

      format_on_save = "on";
      autosave = { after_delay.milliseconds = 1000; };

      languages = {
        Python = {
          # basedpyright first = it handles hover; "!pyright" disables the default
          language_servers = [ "basedpyright" "!pyright" "ruff" ];
          formatter = { language_server.name = "ruff"; };
        };
      };
    };
  };
  ```

- [ ] **Step 2: Verify Nix syntax**

  ```bash
  nix-instantiate --parse /etc/nixos/home/gui.nix
  ```

  Expected: no output.

---

### Task 3: Dry-build and rebuild

- [ ] **Step 1: Dry-build to check full evaluation**

  ```bash
  sudo nixos-rebuild dry-build --flake /etc/nixos#nixbox 2>&1 | tail -20
  ```

  Expected: ends with something like `these derivations will be built:` or `nix: build finished successfully`. No `error:` lines.

  If evaluation fails, run with `--show-trace` for details:
  ```bash
  sudo nixos-rebuild dry-build --flake /etc/nixos#nixbox --show-trace 2>&1 | tail -40
  ```

- [ ] **Step 2: Apply the config**

  ```bash
  rb
  ```

  (`rb` = `sudo nixos-rebuild switch --flake /etc/nixos#nixbox` per CLAUDE.md)

  Expected: completes without error. Home-manager activation runs the zed settings merge script.

- [ ] **Step 3: Verify zeditor binary exists and has tools on PATH**

  ```bash
  which zeditor
  zeditor --version
  ```

  Then verify the PATH wrapping worked:
  ```bash
  # zeditor is a symlinkJoin wrapper — check its wrapped PATH
  cat $(which zeditor) | grep -o 'PATH.*' | head -1
  ```

  Expected: the wrapper script's PATH should include store paths for basedpyright, ruff, nixd, etc.

- [ ] **Step 4: Verify settings were written**

  ```bash
  cat ~/.config/zed/settings.json
  ```

  Expected: a JSON file containing at minimum:
  ```json
  {
    "vim_mode": false,
    "telemetry": { "metrics": false, "diagnostics": false },
    "theme": { "dark": "Catppuccin Mocha", "light": "Catppuccin Mocha" }
  }
  ```

  The `theme` keys come from the catppuccin module merge; the rest from `userSettings`.

- [ ] **Step 5: Verify catppuccin theme file was written**

  ```bash
  ls ~/.config/zed/themes/
  ```

  Expected: `catppuccin.json` present (written by `catppuccin.zed` module).

- [ ] **Step 6: Commit**

  ```bash
  git -C /etc/nixos add home/gui.nix
  git -C /etc/nixos commit -m "feat: add Zed editor with Catppuccin Mocha theme and LSP support"
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
