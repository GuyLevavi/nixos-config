-- Servers come from home/lsp.nix or a project dev shell; Mason is off.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        nil_ls = { enabled = false }, -- lang.nix's pick; home/lsp.nix ships nixd
        nixd = {},
        bashls = {},
        markdown_oxide = {},
      },
    },
  },
}
