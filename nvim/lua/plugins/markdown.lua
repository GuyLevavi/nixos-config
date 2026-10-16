-- Hand-rolled instead of the lang.markdown extra: that one adds marksman,
-- markdownlint and prettier, none wanted beside markdown_oxide.
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    opts = {
      render_modes = true, -- render in insert too; anti_conceal keeps the cursor line raw
      code = { sign = false, width = "block", right_pad = 1 },
      heading = { sign = false, icons = {} },
      pipe_table = { preset = "round" },
      latex = { enabled = false }, -- snacks.image renders math; both would stack
    },
    config = function(_, opts)
      require("render-markdown").setup(opts)
      Snacks.toggle({
        name = "Render Markdown",
        get = require("render-markdown").get,
        set = require("render-markdown").set,
      }):map("<leader>um")
    end,
  },
  {
    "folke/snacks.nvim",
    opts = { image = { enabled = true } },
  },
}
