-- Snacks' double-Esc for every terminal (dap console, cmake-tools runner); a timer, not
-- an <esc><esc> mapping, so a single Esc still reaches the program without timeoutlen lag.
local esc_timer = vim.uv.new_timer()
vim.keymap.set("t", "<esc>", function()
  if esc_timer:is_active() then
    esc_timer:stop()
    vim.cmd("stopinsert")
  else
    esc_timer:start(200, 0, function() end)
    return "<esc>"
  end
end, { expr = true, desc = "Double Esc to Normal Mode" })

-- No macro recording; buffer-local q (close help, trouble, etc.) still takes precedence.
vim.keymap.set({ "n", "x" }, "q", "<nop>")
