return {
  {
    "saghen/blink.cmp",
    -- A function, not a table: sources.default is opts_extend'ed, so a table would append.
    opts = function(_, opts)
      opts.sources.default = { "lsp", "path", "snippets" }
      opts.completion.menu.auto_show = false
      opts.completion.ghost_text.enabled = false
    end,
  },
}
