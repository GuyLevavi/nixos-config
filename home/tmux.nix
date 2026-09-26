{
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  home.packages = [ inputs.workmux.packages.${system}.default ];

  # Functional plugins are deliberately absent — the old sensible/yank/
  # resurrect/continuum/catppuccin set is inlined or dropped. Colours come from
  # palette.conf, written at runtime by noctalia-tmux-theme (home/noctalia.nix)
  # so tmux follows the Noctalia palette; the ANSI block below is the fallback
  # until the first sync runs. workmux restores `resurrect`'s useful half.
  programs.tmux = {
    enable = true;
    prefix = "C-a";
    baseIndex = 1;
    escapeTime = 0;
    terminal = "tmux-256color";
    mouse = true;
    keyMode = "vi";
    historyLimit = 50000;
    aggressiveResize = true;
    clock24 = true;
    extraConfig = ''
      set -as terminal-features ",*:RGB"
      set -g extended-keys on          # kitty protocol — without it Ctrl-hjkl leaks
      set -g allow-passthrough on      # yazi/editor inline images
      set -g focus-events on
      set -g renumber-windows on
      set -g set-clipboard on          # the old yank plugin, inlined
      set -g display-time 4000
      set -g status-interval 5
      bind C-p previous-window
      bind C-n next-window
      bind R source-file ~/.config/tmux/tmux.conf \; display "reloaded"

      # copy-mode vi (yank plugin, inlined)
      set -g mode-keys vi
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi V send -X select-line
      bind -T copy-mode-vi y send -X copy-selection-and-cancel
      bind -T copy-mode-vi Escape send -X cancel

      # splits + pane nav (old config; smart-splits dropped — no nvim now)
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # structure — colours live in palette.conf
      set -g status-position top
      set -g status-justify left
      setw -g window-status-separator ""
      setw -g window-status-format ' #I:#W#{?@workmux_status, #{@workmux_status},}#{?window_flags,#{window_flags}, } '
      setw -g window-status-current-format ' #I:#W#{?@workmux_status, #{@workmux_status},}#{?window_flags,#{window_flags}, } '
      set -g pane-border-lines heavy
      set -g pane-border-indicators colour

      # ANSI fallback until the first Noctalia sync
      set -g status-style "bg=colour0,fg=colour7"
      set -g status-left "#[bg=colour4,fg=colour0,bold] #S #[bg=colour0,fg=colour4,nobold]"
      set -g status-right "#[fg=colour8]#h #[fg=colour4]%H:%M "
      setw -g window-status-style "fg=colour8,bg=colour0"
      setw -g window-status-current-style "fg=colour0,bg=colour4,bold"
      set -g message-style "bg=colour8,fg=colour7"
      set -g mode-style "bg=colour4,fg=colour0"
      setw -g clock-mode-colour colour5
      set -g pane-border-style "fg=colour8"
      set -g pane-active-border-style "fg=colour4"
      set -g popup-style "bg=colour0,fg=colour7"
      set -g popup-border-style "fg=colour8"

      source-file -q ~/.config/tmux/palette.conf

      # workmux — status_format is off in config.yaml so this format owns the
      # bar; @workmux_status is the agent icon workmux sets per window.
      bind C-s display-popup -E -h 80% -w 90% "workmux dashboard"
      bind Tab run-shell "workmux last-agent"
      bind w run-shell "workmux last-done"
    '';
  };

  xdg.configFile = {
    "workmux/config.yaml".text = ''
      nerdfont: true
      merge_strategy: rebase
      agent: opencode
      status_format: false
    '';
    # workmux's OpenCode lifecycle plugin (status hooks). Taken from the same
    # pinned revision as the package so the two never skew.
    "opencode/plugins/workmux-status.ts".source =
      "${inputs.workmux}/resources/opencode/plugins/workmux-status.ts";
  };
}
