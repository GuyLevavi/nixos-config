-- colorscheme.lua — set catppuccin as LazyVim's startup colorscheme
--
-- catppuccin-nix (catppuccin.nvim.enable = true in home.nix) installs the
-- catppuccin-nvim plugin and calls `colorscheme catppuccin` via Vimscript
-- in neovim's plugin loader. However LazyVim has its own colorscheme option
-- that defaults to "tokyonight" and runs after plugins load — it wins unless
-- we explicitly override it here.
--
-- The flavor (mocha) and compile_path are already set by catppuccin-nix's
-- setup() call; we only need to point LazyVim at the right colorscheme name.
return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
