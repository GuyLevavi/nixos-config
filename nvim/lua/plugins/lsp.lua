-- Servers come from home/lsp.nix or a project dev shell; Mason is off.

-- Servers only a project dev shell ships, because they must match its toolchain
-- (hls its GHC, gopls its Go, ...). Each is enabled only when its binary is on
-- PATH when nvim starts, so launch nvim from inside the dev shell.
local devshell_servers = {
  hls = "haskell-language-server-wrapper",
  gopls = "gopls",
  ts_ls = "typescript-language-server",
  ocamllsp = "ocamllsp",
  gleam = "gleam",
  clojure_lsp = "clojure-lsp",
  kotlin_language_server = "kotlin-language-server",
  metals = "metals",
  jdtls = "jdtls",
  elmls = "elm-language-server",
  purescriptls = "purescript-language-server",
}

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.inlay_hints = { enabled = false }
      opts.servers = vim.tbl_deep_extend("force", opts.servers or {}, {
        nil_ls = { enabled = false }, -- lang.nix's pick; home/lsp.nix ships nixd
        nixd = {},
        bashls = {},
        markdown_oxide = {},
      })
      for server, bin in pairs(devshell_servers) do
        if vim.fn.executable(bin) == 1 then
          opts.servers[server] = opts.servers[server] or {}
        end
      end
    end,
  },
}
