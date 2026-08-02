# Minimal Tmux Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `programs.zellij` in `home/base.nix` with a trimmed `programs.tmux` (restored from the pre-COSMIC config, reduced to `sensible`/`yank`/`resurrect`/`continuum`/`catppuccin`), and restore the `smart-splits` tmux-side `is_vim` integration so NixVim's `<C-hjkl>` binds cross into tmux panes.

**Architecture:** Single file change — `home/base.nix`, shared by both GUI hosts and the airgap/WSL headless closures. Remove the `programs.zellij` block; add a `programs.tmux` block in its place with the same key location.

**Tech Stack:** NixOS home-manager, `programs.tmux` module, `pkgs.tmuxPlugins.*` (nixpkgs-native, no external flake input needed).

## Global Constraints

- `home/base.nix` is shared by `nixbox`, `gamingbox`, and the `wsl`/`airgap` `homeConfigurations` — verify all four build.
- Dropped from the original 6-plugin config: `tmux-sessionx`, `tmux-floax` (per spec — unused).
- `allow-passthrough` must stay: airgap's LazyVim uses molten-nvim, which needs Kitty graphics passthrough through tmux.
- No catppuccin-nix flake input — `pkgs.tmuxPlugins.catppuccin` is a plain nixpkgs package.

---

## File Map

| File | Change |
|------|--------|
| `home/base.nix` | Remove `programs.zellij` block (lines 41-45), add `programs.tmux` block |

---

### Task 1: Replace zellij with tmux in home/base.nix

**Files:**
- Modify: `home/base.nix:41-45`

- [ ] **Step 1: Remove the zellij block**

  Delete these lines (currently 41-45):
  ```nix
    # ── Multiplexer: zellij (works out of the box, no plugin zoo) ─────────
    programs.zellij = {
      enable = true;
      settings.show_startup_tips = false;
    };
  ```

- [ ] **Step 2: Add the tmux block in its place**

  ```nix
    # ── Multiplexer: tmux ────────────────────────────────────────────────
    # Declarative config — replaces ~/.tmux.conf.
    programs.tmux = {
      enable = true;
      prefix = "C-a";
      baseIndex = 1;
      escapeTime = 0;
      terminal = "tmux-256color";
      mouse = true;
      keyMode = "vi";
      extraConfig = ''
        set -as terminal-features ",*:RGB"

        # Kitty extended-keys protocol — without this, nushell/fish's
        # use_kitty_protocol leaks raw escape sequences through tmux,
        # breaking hjkl in copy-mode and C-hjkl pane nav.
        set -g extended-keys on

        # Kitty graphics protocol passthrough — required by molten-nvim
        # (LazyVim/airgap) for inline plot rendering.
        set -g allow-passthrough on

        set -g renumber-windows on

        set -g mode-keys vi
        bind -T copy-mode-vi v   send -X begin-selection
        bind -T copy-mode-vi V   send -X select-line
        bind -T copy-mode-vi y   send -X copy-selection-and-cancel
        bind -T copy-mode-vi Escape send -X cancel

        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"
        unbind '"'
        unbind %

        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        set -g status-position top
        set -g @catppuccin_flavor "mocha"

        set -g @continuum-restore "on"
        set -g @continuum-save-interval "15"
        set -g @resurrect-capture-pane-contents "on"

        # Smart-splits — cross Neovim <-> tmux pane navigation (unprefixed C-hjkl).
        # Matches the <C-hjkl> keymaps in home/nixvim.nix's smart-splits section.
        is_vim="ps -o state= -o comm= -t '#{pane_tty}' | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
        bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h' 'select-pane -L'
        bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j' 'select-pane -D'
        bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k' 'select-pane -U'
        bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l' 'select-pane -R'
        bind-key -T copy-mode-vi 'C-h' select-pane -L
        bind-key -T copy-mode-vi 'C-j' select-pane -D
        bind-key -T copy-mode-vi 'C-k' select-pane -U
        bind-key -T copy-mode-vi 'C-l' select-pane -R
      '';
      plugins = with pkgs.tmuxPlugins; [
        sensible
        yank
        resurrect
        continuum
        catppuccin
      ];
    };
  ```

- [ ] **Step 3: Verify Nix syntax**

  ```bash
  nix-instantiate --parse /etc/nixos/home/base.nix
  ```

  Expected: no output (parse success).

---

### Task 2: Dry-build all four flake outputs that use base.nix

**Files:** none (verification only)

- [ ] **Step 1: Dry-build nixbox and gamingbox**

  ```bash
  sudo nixos-rebuild dry-build --flake /etc/nixos#nixbox --show-trace 2>&1 | tail -30
  sudo nixos-rebuild dry-build --flake /etc/nixos#gamingbox --show-trace 2>&1 | tail -30
  ```

  Expected: both end cleanly, no `error:` lines.

- [ ] **Step 2: Build the headless homeConfigurations**

  ```bash
  nix build /etc/nixos#homeConfigurations.wsl.activationPackage --show-trace 2>&1 | tail -30
  nix build /etc/nixos#homeConfigurations.airgap.activationPackage --show-trace 2>&1 | tail -30
  ```

  Expected: both build successfully, no `error:` lines. (These use `pkgs.tmuxPlugins.catppuccin` too — confirms it resolves without network access issues under `nixpkgs.legacyPackages`.)

---

### Task 3: Apply, verify functionality, commit

- [ ] **Step 1: Apply the config on this machine**

  ```bash
  rb
  ```

  Expected: completes without error. `zellij` binary should no longer be on PATH; `tmux` should be.

- [ ] **Step 2: Verify zellij is gone and tmux is present**

  ```bash
  which zellij; echo "exit: $?"   # expect exit 1 (not found)
  which tmux
  ```

- [ ] **Step 3: Start tmux and verify core behavior**

  ```bash
  tmux new -s test
  ```

  Inside the session, verify manually:
  - Prefix is `Ctrl-a` (not the tmux default `Ctrl-b`) — try `Ctrl-a c` to create a new window.
  - `Ctrl-a |` splits a pane vertically (side-by-side); `Ctrl-a -` splits horizontally.
  - Status bar is at the top of the terminal, Catppuccin-themed.
  - `Ctrl-a [` enters copy mode; `v`/`y` select/copy with vi keys.

- [ ] **Step 4: Verify smart-splits cross-navigation**

  Inside the tmux session:
  ```bash
  nvim
  ```
  Open a horizontal split in Neovim (`:vsplit`), then press `Ctrl-h`/`Ctrl-l` — focus should move between Neovim splits. Exit Neovim, split the tmux pane itself (`Ctrl-a |`), and press `Ctrl-h`/`Ctrl-l` again — focus should now move between tmux panes instead.

- [ ] **Step 5: Verify plugins loaded**

  ```bash
  tmux show-options -g | grep catppuccin
  tmux show-options -g | grep continuum
  ```

  Expected: `@catppuccin_flavor mocha` and the continuum options are present (confirms `tpm`-equivalent plugin loading via home-manager worked).

- [ ] **Step 6: Clean up test session**

  ```bash
  tmux kill-session -t test
  ```

- [ ] **Step 7: Commit**

  ```bash
  git -C /etc/nixos add home/base.nix
  git -C /etc/nixos commit -m "feat: restore minimal tmux (replaces zellij), restore smart-splits tmux integration"
  ```

---

## Rollback

If the rebuild fails:

```bash
sudo nixos-rebuild switch --rollback
```

Or revert the file:
```bash
git -C /etc/nixos checkout home/base.nix
rb
```
