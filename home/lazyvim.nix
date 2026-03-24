# home/lazyvim.nix — LazyVim via lazyvim-nix (replaces home/nixvim.nix)
# All plugins and tools come from nixpkgs — no Mason, no runtime downloads.
{ pkgs, ... }:

{
  programs.lazyvim = {
    enable  = true;
    appName = "nvim";   # keep the same binary name

    # ripgrep, fd, lazygit are already in home.packages — don't double-install
    installCoreDependencies = false;

    # ── Formatters / tools on PATH for conform + LSP ──────────────────────
    extraPackages = with pkgs; [
      # Lua / Nix
      stylua
      nixpkgs-fmt
      nix-doc              # hover docs for Nix builtins

      # Python
      ruff
      black
      python3Packages.debugpy

      # JS / TS / YAML / JSON / Markdown
      nodePackages.prettier

      # Shell (no lang.bash extra exists — provide tool directly)
      shfmt

      # C / C++
      clang-tools          # provides clangd + clang-format
    ];

    # ── Language extras (lazyvim-nix built-in extra system) ───────────────
    # Use unquoted dot-notation. Only extras confirmed in lazyvim-nix are listed.
    # If a build error says "attribute 'X' missing", comment it out and add
    # the relevant tool to extraPackages instead.
    extras = {
      lang.python.enable     = true;   # basedpyright + ruff
      lang.nix.enable        = true;   # nixd
      lang.markdown.enable   = true;   # marksman
      lang.docker.enable     = true;   # dockerls + docker-compose-language-service
      lang.yaml.enable       = true;   # yamlls
      lang.json.enable       = true;   # jsonls
      lang.typescript.enable = true;   # tsserver
      lang.toml.enable       = true;   # taplo
      lang.clangd.enable     = true;   # clangd (C/C++)
      lang.helm.enable       = true;   # helm-ls
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
