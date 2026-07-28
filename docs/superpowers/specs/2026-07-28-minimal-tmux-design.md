# Minimal Tmux Restoration — NixOS Config Design

Date: 2026-07-28

## Summary

Replace `programs.zellij` in `home/base.nix` with a trimmed-down `programs.tmux`, restored from the pre-COSMIC config (commit `a445241^`) and reduced to the plugins actually used. Also restores the `smart-splits` tmux-side integration (currently dead — NixVim's `<C-hjkl>` binds expect a tmux counterpart that doesn't exist without tmux installed).

## Approach

Full old config had 6 plugins: `sensible`, `yank`, `resurrect`, `continuum`, `tmux-sessionx`, `tmux-floax`. Per user decision, keep core + session persistence (`sensible`, `yank`, `resurrect`, `continuum`), drop `tmux-sessionx` and `tmux-floax` as unused. Theming: the old config depended on the `catppuccin-nix` flake input for `catppuccin.tmux.enable`, which was dropped in the COSMIC-switch commit and never restored — but `pkgs.tmuxPlugins.catppuccin` exists directly in nixpkgs (confirmed via `nix eval`), so theming is restored via that plugin instead, no flake input needed.

## File Changed

`home/base.nix` — remove `programs.zellij` block (lines 41–45), add `programs.tmux` block in its place.

## Design

```nix
# ── Tmux ──────────────────────────────────────────────────────────────
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
    # Matches the binds in home/nixvim.nix's smart-splits keymaps.
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

Dropped from the original: `tmux-sessionx` (`@sessionx-bind "O"`), `tmux-floax` (`@floax-bind "p"`), and their associated settings — unused, per user.

## Constraints

- `home/base.nix` is shared by both GUI hosts and the airgap closure — `allow-passthrough` stays because airgap's LazyVim uses molten-nvim (per project memory), even though the GUI hosts' NixVim currently has no image/molten plugin.
- `smart-splits`'s tmux-side `is_vim` binds only pay off if `home/nixvim.nix`'s `<C-hjkl>` keymaps (lines 661–664) are actually in place — they are, confirmed already present.
- No catppuccin-nix flake input needed or reintroduced; `tmuxPlugins.catppuccin` is a nixpkgs-native package.
