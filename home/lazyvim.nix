# Declarative LazyVim via pfassina/lazyvim-nix — zero-config by design, so
# this stays tiny. Telescope, blink-cmp, gitsigns, which-key, session restore
# etc. are LazyVim defaults; don't re-add them here.
{ pkgs, ... }:
{
  programs.lazyvim = {
    enable = true;

    extras = {
      lang.nix.enable = true;
      lang.python = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = true;
      };
    };

    # lang.nix ships no auto-installed deps (unlike python/go) — nixd is
    # manual, and so are the formatter/linter its extras/lang/nix.lua expects
    # on PATH (nixfmt, statix) — LazyVim's default nil_ls LSP is swapped for
    # nixd here, but the formatter/linter aren't swappable, just missing deps.
    extraPackages = [
      pkgs.nixd
      pkgs.nixfmt
      pkgs.statix
    ];

    # Dynamic theming: Noctalia's "neovim" template (home/noctalia.nix) writes
    # ~/.config/nvim/lua/matugen.lua per palette + SIGUSR1s running instances;
    # base16-nvim is the engine that file drives. Falls back until it exists.
    plugins.colorscheme = ''
      return {
        { "RRethy/base16-nvim", lazy = false, priority = 1000 },
        {
          "LazyVim/LazyVim",
          opts = {
            colorscheme = function()
              -- matugen.lua only exists once Noctalia has applied a palette
              local ok, matugen = pcall(require, "matugen")
              if ok then matugen.setup() else vim.cmd.colorscheme("habamax") end
            end,
          },
        },
      }
    '';

    # Debounced write-on-idle; :ASToggle to pause it for a buffer session.
    plugins.autosave = ''
      return {
        "okuuva/auto-save.nvim",
        cmd = "ASToggle",
        event = { "InsertLeave", "TextChanged" },
        opts = {},
      }
    '';
  };

  home.sessionVariables.EDITOR = "nvim";
}
