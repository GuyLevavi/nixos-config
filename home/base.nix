# home/base.nix — headless home-manager config
# All tools that work without a display server.
# Imported by home/gui.nix for nixbox; used standalone for WSL/Docker/server.
{ config, pkgs, lib, ... }:

{
  home.username    = "gl";
  home.homeDirectory = "/home/gl";
  home.stateVersion  = "25.05"; # DO NOT change after install

  programs.home-manager.enable = true;

  # ── Catppuccin — terminal tools only ──────────────────────────────────
  # GUI modules (waybar, hyprland, hyprlock, mako, kitty) are in gui.nix.
  catppuccin.flavor = "mocha";
  catppuccin.accent = "mauve";

  catppuccin.starship.enable = true;
  catppuccin.fzf.enable      = true;
  catppuccin.lazygit.enable  = true;
  catppuccin.bat.enable      = true;
  catppuccin.btop.enable     = true;
  catppuccin.nushell.enable  = true;
  catppuccin.nvim.enable     = true;
  catppuccin.opencode.enable = true;
  catppuccin.delta.enable    = true; # git diff pager

  # ── Shell: Bash (login) → exec Nushell ────────────────────────────────
  programs.bash = {
    enable   = true;
    initExtra = ''
      if [[ $- == *i* && -z "$BASH_EXECUTION_STRING" && -z "$IN_NIX_SHELL" ]]; then
        exec nu
      fi
    '';
  };

  programs.nushell = {
    enable = true;
    envFile.text = ''
      $env.EDITOR = "nvim"
      $env.VISUAL = "nvim"
      $env.DOCKER_HOST = $"unix://($env.XDG_RUNTIME_DIR)/podman/podman.sock"
    '';
    configFile.text = ''
      $env.config = {
        show_banner: false
        edit_mode: vi
        cursor_shape: {
          vi_insert: line
          vi_normal: block
        }
        completions: {
          case_sensitive: false
          quick: true
          algorithm: fuzzy
        }
        history: {
          max_size: 100_000
          sync_on_enter: true
          file_format: sqlite
        }
      }

      # Aliases
      alias rb     = sudo nixos-rebuild switch --flake /etc/nixos#nixbox
      alias update = sudo nix flake update /etc/nixos
      alias nsh    = nix-shell -p
      alias gcold  = sudo nix-collect-garbage --delete-older-than 14d
      alias vim    = nvim
      alias vi     = nvim
      alias ll     = eza -la --icons --git
      alias lt     = eza --tree --icons
      alias cat    = bat
      # 'cd' is overridden by zoxide via --cmd cd (see programs.zoxide below)
    '';
  };

  # ── Neovim + LazyVim ──────────────────────────────────────────────────
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    viAlias       = true;
    vimAlias      = true;
    extraPackages = with pkgs; [
      # LSP servers
      lua-language-server
      nixd             # Nix LSP (flake-aware)
      nix-doc          # hover docs for Nix builtins
      nodePackages.typescript-language-server
      basedpyright     # actively maintained pyright fork with better defaults
      # Formatters / linters
      stylua
      nixpkgs-fmt
      ruff             # Python linter + formatter (replaces black for most uses)
      black            # kept for projects that require black specifically
      ripgrep          # telescope live_grep
      fd               # telescope find_files
      tree-sitter
      gcc
    ];
  };

  home.file.".config/nvim".source = ../config/nvim;

  # ── Git ───────────────────────────────────────────────────────────────
  # delta.enable adds delta as the pager; catppuccin.delta themes it.
  # credential.helper is intentionally omitted here:
  #   - gui.nix sets it to "keepassxc" (GUI app, always running on nixbox)
  #   - headless: use SSH keys or let git prompt
  programs.git = {
    enable   = true;
    settings = {
      user.name  = "guy";
      user.email = "guylevavi@gmail.com";
      init.defaultBranch = "main";
      pull.rebase        = true;
      core.editor        = "nvim";
    };
  };

  programs.delta = {
    enable               = true;
    enableGitIntegration = true;
  };

  programs.lazygit.enable = true;

  # ── Zoxide, fzf, starship ─────────────────────────────────────────────
  programs.zoxide = {
    enable                   = true;
    enableNushellIntegration = true;
    options                  = [ "--cmd cd" ];
  };

  programs.fzf.enable = true;

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      format = lib.concatStrings [
        "[$username@$hostname](bold mauve) "
        "$directory"
        "$git_branch"
        "$git_status"
        "$python$rust$nodejs$nix_shell"
        "$character"
      ];
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol   = "[❯](bold red)";
      };
      directory = {
        truncation_length = 3;
        style             = "bold blue";
      };
      git_branch.style = "bold mauve";
      git_status.style = "bold peach";
      nix_shell = {
        symbol = "❄ ";
        style  = "bold teal";
      };
    };
  };

  # ── OpenCode — CLI AI assistant ────────────────────────────────────────
  programs.opencode = {
    enable = true;
    settings = {
      autoshare  = false;
      autoupdate = true;
    };
  };

  # ── Packages ──────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    # Core CLI tools
    ripgrep
    fd
    bat
    eza
    htop
    btop
    dust       # du replacement
    sd         # sed replacement
    procs      # ps replacement

    # Containers
    podman-compose
    lazydocker

    # Python tooling
    uv         # fast Python package/venv manager (replaces pip + pyenv + venv)

    # Terminal utilities
    yazi       # terminal file manager
    tmux       # terminal multiplexer (persistent sessions over SSH/WSL)
    glow       # markdown viewer
    lnav       # log file viewer
    fastfetch  # system info

    # Kubernetes
    k9s        # Kubernetes TUI
    helm       # Kubernetes package manager

    # Dev TUIs
    posting    # HTTP client TUI (wraps httpx)
    # harlequin  # SQL TUI — broken in nixpkgs unstable (tomlkit<0.14 constraint)
  ];

  # ── Podman rootless socket ─────────────────────────────────────────────
  systemd.user.sockets.podman = {
    Unit.Description = "Podman API socket";
    Socket = {
      ListenStream = "%t/podman/podman.sock";
      SocketMode    = "0660";
    };
    Install.WantedBy = [ "sockets.target" ];
  };
}
