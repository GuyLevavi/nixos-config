return {
  {
    "mfussenegger/nvim-dap",
    opts = function()
      local dap = require("dap")
      -- lang.clangd connects to "localhost", which resolves to ::1 first; codelldb listens on IPv4 only.
      dap.adapters.codelldb.host = "127.0.0.1"
      -- run_last re-evaluates `program`, so the prompt re-asks every time; prefill the last answer.
      local last
      for _, lang in ipairs({ "c", "cpp" }) do
        for _, cfg in ipairs(dap.configurations[lang] or {}) do
          if cfg.request == "launch" then
            cfg.program = function()
              last = vim.fn.input("Path to executable: ", last or vim.fn.getcwd() .. "/", "file")
              return last
            end
          end
        end
      end
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    init = function()
      -- dap-ui only autoscrolls a focused console; unfocused, its view stays past the
      -- end of the resized pty, so the program's prompt is invisible until you enter it.
      vim.api.nvim_create_autocmd("TermOpen", {
        callback = function(ev)
          if vim.bo[ev.buf].filetype ~= "dapui_console" then
            return
          end
          vim.api.nvim_buf_attach(ev.buf, false, {
            on_lines = function()
              vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(ev.buf) then
                  return
                end
                -- The pty can be taller than the window, so the end of the buffer is blank rows.
                local last = vim.api.nvim_buf_line_count(ev.buf)
                while last > 1 and vim.api.nvim_buf_get_lines(ev.buf, last - 1, last, false)[1] == "" do
                  last = last - 1
                end
                for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
                  if win ~= vim.api.nvim_get_current_win() then
                    vim.api.nvim_win_set_cursor(win, { last, 0 })
                    vim.api.nvim_win_call(win, function()
                      vim.cmd("normal! zb")
                    end)
                  end
                end
              end)
            end,
          })
        end,
      })
    end,
    opts = {
      layouts = {
        { position = "right", size = 40, elements = { { id = "scopes", size = 0.7 }, { id = "stacks", size = 0.3 } } },
        { position = "bottom", size = 10, elements = { "console" } },
      },
    },
  },
}
