-- home/lsp.nix ships basedpyright, not pyright.
vim.g.lazyvim_python_lsp = "basedpyright"

-- Only yanks reach the system clipboard (autocmds.lua); d/c/x stay in nvim's registers.
vim.opt.clipboard = ""
