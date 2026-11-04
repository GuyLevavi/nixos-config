vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("yank_to_clipboard", { clear = true }),
  callback = function()
    if vim.v.event.operator == "y" and vim.v.event.regname == "" then
      vim.fn.setreg("+", vim.v.event.regcontents, vim.v.event.regtype)
    end
  end,
})

-- botright splits (dap-ui, trouble) bypass winfixwidth, so the right-docked explorer
-- shrinks when one opens and absorbs its width when it closes.
vim.api.nvim_create_autocmd("WinResized", {
  group = vim.api.nvim_create_augroup("explorer_width", { clear = true }),
  callback = function()
    for _, picker in ipairs(Snacks.picker.get({ source = "explorer" })) do
      local root = picker.layout.root
      if root:valid() and vim.api.nvim_win_get_width(root.win) ~= 40 then
        vim.api.nvim_win_set_width(root.win, 40)
      end
    end
  end,
})
