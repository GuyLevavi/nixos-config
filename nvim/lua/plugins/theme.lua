-- noctalia-theme-sync (home/noctalia.nix) writes the scheme to load.
local theme = vim.fn.stdpath("state") .. "/theme.lua"

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        if vim.uv.fs_stat(theme) then
          dofile(theme)
        else
          vim.cmd.colorscheme("tokyonight")
        end
      end,
    },
  },
}
