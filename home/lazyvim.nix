# home/lazyvim.nix — LazyVim via lazyvim-nix (replaces home/nixvim.nix)
# All plugins and tools come from nixpkgs — no Mason, no runtime downloads.
{ pkgs, ... }:

{
  programs.lazyvim = {
    enable  = true;
    appName = "nvim";   # keep the same binary name

    # ripgrep, fd, lazygit are already in home.packages — don't double-install
    installCoreDependencies = false;

    # ── LSP server binaries + formatters on PATH ──────────────────────────
    # extras.lang.* configures plugin specs but does NOT install binaries.
    # Every LSP server binary must be listed here explicitly.
    extraPackages = with pkgs; [
      # ── LSP servers ───────────────────────────────────────────────────
      basedpyright                          # Python (hover, types, go-to-def)
      nixd                                  # Nix (flake-aware)
      lua-language-server                   # Lua (LazyVim core config files)
      marksman                              # Markdown (cross-file links)
      yaml-language-server                  # YAML (kubernetes schemas etc.)
      nodePackages.vscode-langservers-extracted  # JSON + HTML + CSS (jsonls)
      nodePackages.typescript-language-server   # TypeScript / JavaScript
      taplo                                 # TOML (pyproject.toml, Cargo.toml)
      helm-ls                               # Helm charts
      bash-language-server                  # Bash / Shell
      dockerfile-language-server             # Docker (dockerls)
      docker-compose-language-service       # docker-compose files
      clang-tools                           # C/C++ (clangd + clang-format)

      # ── Formatters ────────────────────────────────────────────────────
      stylua                                # Lua
      nixpkgs-fmt                           # Nix
      nix-doc                               # hover docs for Nix builtins
      ruff                                  # Python linter + formatter
      black                                 # Python formatter
      nodePackages.prettier                 # JS/TS/JSON/YAML/Markdown
      shfmt                                 # Shell

      # ── Debug adapters ────────────────────────────────────────────────
      python3Packages.debugpy               # Python DAP adapter
    ];

    # ── Language extras (configures plugin specs + Mason disable) ─────────
    extras = {
      lang.python.enable     = true;
      lang.nix.enable        = true;
      lang.markdown.enable   = true;
      lang.docker.enable     = true;
      lang.yaml.enable       = true;
      lang.json.enable       = true;
      lang.typescript.enable = true;
      lang.toml.enable       = true;
      lang.clangd.enable     = true;
      lang.helm.enable       = true;
    };

    # ── Treesitter parsers (baked in at build time) ────────────────────────
    treesitterParsers = with pkgs.vimPlugins.nvim-treesitter-parsers; [
      bash c cpp css dockerfile fish go html javascript json lua
      markdown markdown_inline nix python query rust toml tsx
      typescript vim vimdoc yaml
    ];

    # ── Catppuccin theme (not available as an extra — use plugin spec) ─────
    plugins.colorscheme = ''
      return {
        "catppuccin/nvim",
        name = "catppuccin",
        opts = { flavour = "mocha" },
      }
    '';
  };
}
