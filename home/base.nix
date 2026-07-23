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

  # ── Multiplexer: zellij (works out of the box, no plugin zoo) ─────────
  programs.zellij = {
    enable = true;
    settings.show_startup_tips = false;
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
    openclaw                       # self-hosted AI assistant/agent
  ];
}
