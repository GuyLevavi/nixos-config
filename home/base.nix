# home/base.nix — headless home-manager config
# All tools that work without a display server.
# Imported by home/gui.nix for nixbox; used standalone for WSL/Docker/server.
{ config, pkgs, lib, ... }:

{
  imports = [ ./nixvim.nix ];
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
  catppuccin.nvim.enable     = false;  # NixVim uses its own catppuccin module
  catppuccin.opencode.enable = true;
  catppuccin.delta.enable    = true;   # git diff pager
  catppuccin.atuin.enable    = true;   # shell history search

  # ── Shell: Bash (login) → exec Nushell ────────────────────────────────
  programs.bash = {
    enable   = true;
    shellAliases = {
      vim = "nvim";
      vi  = "nvim";
    };
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

      # Vi mode indicators — starship does NOT support vi mode for nushell
      # (starship#4897). Use nushell's native closures instead.
      # Green ❯ (insert, success) / red ❯ (insert, error) / purple ❮ (normal)
      $env.PROMPT_INDICATOR_VI_INSERT = {||
        if ($env.LAST_EXIT_CODE? | default 0) == 0 {
          $"(ansi green_bold)❯(ansi reset) "
        } else {
          $"(ansi red_bold)❯(ansi reset) "
        }
      }
      $env.PROMPT_INDICATOR_VI_NORMAL = {|| $"(ansi purple_bold)❮(ansi reset) " }
    '';
    configFile.text = ''
      $env.config = {
        show_banner: false
        edit_mode: vi
        use_kitty_protocol: true             # better key detection in vi mode
        highlight_resolved_externals: true    # colors valid commands green as you type
        cursor_shape: {
          vi_insert: line
          vi_normal: block
        }
        completions: {
          case_sensitive: false
          quick: true
          algorithm: fuzzy
          external: {
            enable: true      # allow external completers (carapace)
            max_results: 100
          }
        }
        history: {
          max_size: 100_000
          sync_on_enter: true
          file_format: sqlite
        }
        keybindings: (
        [
          # ── HISTORY SEARCH ─────────────────────────────────────────────
          { name: atuin   modifier: control keycode: char_r  mode: [vi_insert vi_normal]
            event: { send: ExecuteHostCommand cmd: "commandline edit --insert (atuin search --interactive 2>/dev/null)" } }

          # ── HISTORY HINT ───────────────────────────────────────────────
          { name: hist_ht modifier: shift   keycode: right   mode: vi_insert
            event: { send: HistoryHintComplete } }

          # ── COMPLETION MENU ────────────────────────────────────────────
          { name: tab     modifier: none    keycode: tab     mode: [vi_insert vi_normal]
            event: { until: [{ send: Menu name: completion_menu } { send: MenuNext }] } }
          { name: s_tab   modifier: shift   keycode: backtab mode: [vi_insert vi_normal]
            event: { send: MenuPrevious } }
          { name: ctrl_j  modifier: control keycode: char_j  mode: vi_insert
            event: { until: [{ send: MenuDown } { send: Enter }] } }

          # ── HISTORY / MENU NAV ─────────────────────────────────────────
          { name: ctrl_p  modifier: control keycode: char_p  mode: [vi_insert vi_normal]
            event: { until: [{ send: MenuUp } { send: Up }] } }
          { name: ctrl_n  modifier: control keycode: char_n  mode: [vi_insert vi_normal]
            event: { until: [{ send: MenuDown } { send: Down }] } }

          # ── CLEAR / EDIT / UNDO ────────────────────────────────────────
          { name: ctrl_l  modifier: control keycode: char_l  mode: [vi_insert vi_normal]
            event: { send: ClearScreen } }
          { name: ctrl_o  modifier: control keycode: char_o  mode: [vi_insert vi_normal]
            event: { send: OpenEditor } }
          { name: alt_u   modifier: alt     keycode: char_u  mode: vi_insert
            event: { edit: Undo } }
        ])
      }

      # Aliases
      alias rb     = sudo nixos-rebuild switch --flake /etc/nixos#nixbox
      alias update = sudo nix flake update /etc/nixos
      alias nsh    = nix-shell -p
      alias gcold  = sudo nix-collect-garbage --delete-older-than 14d
      alias ll     = eza -la --icons --git
      alias lt     = eza --tree --icons
      alias cat    = bat
    '';
    # Expose z/zi after the zoxide source (which is injected into extraConfig
    # by enableNushellIntegration). lib.mkAfter guarantees this lands last.
    # Must use def --env --wrapped (not alias): __zoxide_z is def --env, and
    # plain aliases do not propagate $env.PWD — the directory change is lost.
    # We do NOT override 'cd': __zoxide_z calls the built-in cd internally,
    # so any cd→__zoxide_z wrapper causes infinite recursion.
    extraConfig = lib.mkAfter ''
      def --env --wrapped z  [...rest: string] { __zoxide_z ...$rest }
      def --env --wrapped zi [...rest: string] { __zoxide_zi ...$rest }
    '';
  };

  # ── Neovim — configured via NixVim in home/nixvim.nix ────────────────
  # All plugins, LSP servers, formatters, and treesitter grammars are
  # pre-fetched by Nix at build time. No lazy.nvim, no Mason, no runtime
  # downloads. See home/nixvim.nix for the full config.

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

  # ── Carapace — universal external completer ──────────────────────────
  # Provides subcommand completions for 1000+ CLI tools (git, docker,
  # kubectl, nix, etc.). Without this, nushell falls back to file/dir
  # completion for external commands. Injects via extraConfig with
  # upsert — non-destructive to existing completions config.
  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
  };

  # ── Atuin — shell history search ───────────────────────────────────────
  # SQLite-backed fuzzy history search across sessions. Replaces basic
  # Ctrl+R with filterable, searchable, cross-session history.
  # Does NOT conflict with fzf (fzf has no nushell integration enabled).
  programs.atuin = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      auto_sync    = false;  # local only — no cloud sync
      update_check = false;
      style        = "compact";
      inline_height = 20;
    };
  };

  # ── Zoxide, fzf, starship ─────────────────────────────────────────────
  programs.zoxide = {
    enable                   = true;
    enableNushellIntegration = true;
    # --no-cmd: emit __zoxide_z/__zoxide_zi internals + alias z/zi.
    # Do NOT override 'cd': __zoxide_z internally calls the built-in cd,
    # so any cd→__zoxide_z wrapper causes infinite recursion.
    # Use 'z <query>' for frecency jumps; 'cd <path>' for plain navigation.
    options = [ "--no-cmd" ];
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
        "$container"   # shows 📦 image-name when inside podman/docker
        "\n"           # newline before prompt character
      ];
      # character module disabled — starship has no vi mode support for nushell
      # (starship#4897). Vi mode indicator is handled by nushell's native
      # PROMPT_INDICATOR_VI_INSERT / PROMPT_INDICATOR_VI_NORMAL in envFile.
      character.disabled = true;
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
      # Container module — shows when running inside podman/docker.
      # Detection: reads /.dockerenv (docker) or /run/.containerenv (podman).
      # The nushell env CONTAINER / PODMAN_CONTAINER are NOT checked by starship;
      # detection is purely file-based, so it works regardless of shell.
      container = {
        symbol = "📦 ";
        style  = "bold yellow";
        format = "[$symbol$name]($style) ";
      };
    };
  };

  # ── OpenCode — CLI AI assistant ────────────────────────────────────────
  programs.opencode = {
    enable = true;
    settings = {
      autoshare  = false;
      autoupdate = true;
      plugin     = [ "oh-my-opencode" "opencode-gemini-auth@latest" ];
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
