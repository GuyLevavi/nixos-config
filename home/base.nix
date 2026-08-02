# home/base.nix — headless config: shell, git, terminal tools.
# Used everywhere: both GUI hosts and the airgap work closure.
{ pkgs, ... }:
{
  home.username = "gl";
  home.homeDirectory = "/home/gl";
  home.stateVersion = "25.05"; # do not change after install
  programs.home-manager.enable = true;

  # ── Shell: fish ────────────────────────────────────────────────────────
  # Autosuggestions, highlighting, and completions are built in — no config.
  # zoxide/fzf/atuin/starship/direnv hook themselves in automatically.
  programs.fish = {
    enable = true;
    shellAbbrs = {
      rb = "sudo nixos-rebuild switch --flake /etc/nixos";
      update = "nix flake update --flake /etc/nixos && rb";
      gcold = "sudo nix-collect-garbage --delete-older-than 14d";
      nsh = "nix-shell -p"; # nsh ripgrep fd → temp shell
      # Snapshot GUI-managed COSMIC settings into the repo (plain-text RON).
      # Restore on a fresh machine: cp -r /etc/nixos/cosmic-snapshot ~/.config/cosmic
      cosmic-save = "cp -r ~/.config/cosmic /etc/nixos/cosmic-snapshot && git -C /etc/nixos add cosmic-snapshot";
      lg = "lazygit";
    };
    shellAliases = {
      cat = "bat";
      ls = "eza --icons";
      ll = "eza -la --icons";
    };
  };
  programs.starship.enable = true;
  programs.zoxide.enable = true;   # cd replacement: z <fuzzy-dir>
  programs.fzf.enable = true;      # Ctrl-R history, Ctrl-T files
  programs.atuin = {
    enable = true;
    settings = { auto_sync = false; update_check = false; };
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;      # per-project dev shells via .envrc
  };

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

  # ── Git ────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings = {
      user.name = "guy";
      user.email = "guylevavi@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      safe.directory = [ "/etc/nixos" ];
    };
  };
  programs.delta = { enable = true; enableGitIntegration = true; };
  programs.lazygit.enable = true;
  programs.gh.enable = true;

  # ── Packages ───────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    ripgrep fd bat eza dust btop   # modern core CLI
    claude-code
    nushell                        # `nu` for structured-data pipelines
    yazi                           # terminal file manager
    podman-compose lazydocker      # containers
    python3 uv                     # uv handles venvs + interpreter versions
    nodejs                         # npm/npx
    k9s kubernetes-helm            # kubernetes
  ];
}
