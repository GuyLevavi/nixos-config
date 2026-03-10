return {
  -- Neutralize mason-lspconfig auto-install — Nix provides all server binaries.
  -- Mason on NixOS downloads FHS binaries that break; Nix-managed ones on PATH work correctly.
  {
    "williamboman/mason-lspconfig.nvim",
    opts = { ensure_installed = {} },
  },

  -- LazyVim Nix language extra: treesitter grammar + lspconfig setup for Nix files.
  -- nixd binary is provided via home.nix extraPackages.
  { import = "lazyvim.plugins.extras.lang.nix" },
}
