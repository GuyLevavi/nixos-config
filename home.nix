# home.nix — user environment (applies to all machines)
# Managed by home-manager via flake. Run `rb` to apply changes.
{ config, pkgs, ... }:

{
  home.username    = "gl";
  home.homeDirectory = "/home/gl";
  home.stateVersion  = "25.05"; # DO NOT change after install

  programs.home-manager.enable = true;

  # ── Shell: Nushell (launched from bash, not as login shell) ───────────
  # Bash stays as the PAM/systemd login shell (safer for emergency mode).
  # Nu is exec'd for interactive sessions.
  programs.bash = {
    enable   = true;
    initExtra = ''
      # Launch nushell for interactive sessions
      if [[ $- == *i* && -z "$BASH_EXECUTION_STRING" ]]; then
        exec nu
      fi
    '';
  };

  programs.nushell = {
    enable = true;
    # config.nu — behaviour settings
    configFile.text = ''
      $env.config = {
        show_banner: false
        edit_mode: vi            # vi keybindings (fits your neovim workflow)
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
    '';
    # env.nu — environment setup
    envFile.text = ''
      $env.EDITOR = "nvim"
      $env.VISUAL = "nvim"
      $env.LIBVA_DRIVER_NAME = "iHD"

      # Aliases
      alias rb     = sudo nixos-rebuild switch --flake /etc/nixos#nixbox
      alias update = sudo nix flake update /etc/nixos
      alias nsh    = nix-shell -p   # quick: nsh ripgrep fd
      alias gcold  = sudo nix-collect-garbage --delete-older-than 14d
      alias vim    = nvim
      alias vi     = nvim
      alias ls     = eza --icons
      alias ll     = eza -la --icons --git
      alias lt     = eza --tree --icons
      alias cat    = bat
      alias cd     = z             # zoxide
    '';
  };

  # ── Neovim + LazyVim ──────────────────────────────────────────────────
  # LazyVim manages its own plugins via lazy.nvim.
  # We declare neovim here but let LazyVim handle plugin config.
  # Your existing dotfiles nvim config gets symlinked in below.
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    viAlias       = true;
    vimAlias      = true;
    # Runtime deps that LazyVim plugins expect to find on PATH:
    extraPackages = with pkgs; [
      # LSP servers
      lua-language-server
      nil              # Nix LSP
      nodePackages.typescript-language-server
      pyright
      # Formatters / linters
      stylua
      nixpkgs-fmt
      black
      ripgrep          # telescope live_grep
      fd               # telescope find_files
      tree-sitter      # nvim-treesitter compilation
    ];
  };
  
  home.file.".config/nvim".source = ./config/nvim;

  # ── Catppuccin ────────────────────────────────────────────────────────
  # Mocha (darkest) variant applied across terminal and tools.
  # LazyVim: add catppuccin/nvim as your colorscheme in your nvim config.
  # Kitty and other tools get it here:
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 13;
    };
    settings = {
      # Catppuccin Mocha
      foreground            = "#CDD6F4";
      background            = "#1E1E2E";
      selection_foreground  = "#1E1E2E";
      selection_background  = "#F5E0DC";
      cursor                = "#F5E0DC";
      cursor_text_color     = "#1E1E2E";
      url_color             = "#F5E0DC";

      # Catppuccin Mocha window borders
      active_border_color   = "#B4BEFE";
      inactive_border_color = "#6C7086";
      bell_border_color     = "#F9E2AF";

      # Tab bar
      active_tab_foreground   = "#11111B";
      active_tab_background   = "#CBA6F7";
      inactive_tab_foreground = "#CDD6F4";
      inactive_tab_background = "#181825";

      # Normal colors
      color0  = "#45475A"; # Surface1
      color1  = "#F38BA8"; # Red
      color2  = "#A6E3A1"; # Green
      color3  = "#F9E2AF"; # Yellow
      color4  = "#89B4FA"; # Blue
      color5  = "#F5C2E7"; # Pink
      color6  = "#94E2D5"; # Teal
      color7  = "#BAC2DE"; # Subtext1

      # Bright colors
      color8  = "#585B70"; # Surface2
      color9  = "#F38BA8"; # Red
      color10 = "#A6E3A1"; # Green
      color11 = "#F9E2AF"; # Yellow
      color12 = "#89B4FA"; # Blue
      color13 = "#F5C2E7"; # Pink
      color14 = "#94E2D5"; # Teal
      color15 = "#A6ADC8"; # Subtext0

      shell                   = "nu";
      confirm_os_window_close = 0;
      enable_audio_bell       = false;
    };
  };

  # ── Git ───────────────────────────────────────────────────────────────
  programs.git = {
    enable    = true;
    userName  = "guy";
    userEmail = "your@email.com"; # fill in
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase        = true;
      core.editor        = "nvim";
    };
  };

  programs.lazygit.enable = true;

  # ── Zoxide (smart cd — aliased to 'cd' in nushell) ────────────────────
  programs.zoxide = {
    enable            = true;
    enableNushellIntegration = true;
  };

  # ── fzf ───────────────────────────────────────────────────────────────
  programs.fzf = {
    enable = true;
    # Catppuccin Mocha fzf colors
    colors = {
      "bg+"    = "#313244";
      "bg"     = "#1e1e2e";
      "spinner" = "#f5e0dc";
      "hl"     = "#f38ba8";
      "fg"     = "#cdd6f4";
      "header" = "#f38ba8";
      "info"   = "#cba6f7";
      "pointer" = "#f5e0dc";
      "marker" = "#b4befe";
      "fg+"    = "#cdd6f4";
      "prompt" = "#cba6f7";
      "hl+"    = "#f38ba8";
    };
  };

  # ── Browser ───────────────────────────────────────────────────────────
  programs.firefox.enable = true;

  # ── Wayland / Hyprland ecosystem ──────────────────────────────────────
  home.packages = with pkgs; [
    # Wayland essentials
    waybar          # status bar
    wofi            # launcher
    grim            # screenshot
    slurp           # region select
    wl-clipboard    # wl-copy / wl-paste
    mako            # notification daemon
    swww            # wallpaper daemon (wayland-native)

    # CLI tools
    ripgrep
    fd
    bat             # cat replacement (Catppuccin theme available)
    eza             # ls replacement
    htop
    btop            # htop but nicer
    dust            # du replacement
    sd              # sed replacement
    procs           # ps replacement

    # Dev
    podman-compose
    lazydocker
  ];

  # ── Hyprland config (symlink from dotfiles once you have it) ──────────
  home.file.".config/hypr/hyprland.conf".source = ./config/hypr/hyprland.conf;
  home.file.".config/waybar".source             = ./config/waybar;
  home.file.".config/mako/config".source        = ./config/mako/config;
  home.file.".config/wofi".source               = ./config/wofi;
}
