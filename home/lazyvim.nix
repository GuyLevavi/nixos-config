# home/lazyvim.nix — LazyVim via lazyvim-nix (replaces home/nixvim.nix)
# All plugins and tools come from nixpkgs — no Mason, no runtime downloads.
{ pkgs, ... }:

{
  programs.lazyvim = {
    enable  = true;
    appName = "nvim";   # keep the same binary name

    # ripgrep, fd, lazygit are already in home.packages — don't double-install
    installCoreDependencies = false;

    # ── LSP server binaries + formatters on PATH ──────────────────────────
    # extras.lang.* configures plugin specs but does NOT install binaries.
    # Every LSP server binary must be listed here explicitly.
    extraPackages = with pkgs; [
      # ── LSP servers ───────────────────────────────────────────────────
      pyright                               # Python (pyright-langserver — lang.python extra)
      nil                                   # Nix (nil binary — lang.nix extra uses nil_ls)
      lua-language-server                   # Lua (LazyVim core config files)
      marksman                              # Markdown (cross-file links)
      yaml-language-server                  # YAML (kubernetes schemas etc.)
      nodePackages.vscode-langservers-extracted  # JSON + HTML + CSS (jsonls)
      vtsls                                 # TypeScript / JavaScript (lang.typescript extra)
      taplo                                 # TOML (pyproject.toml, Cargo.toml)
      helm-ls                               # Helm charts
      bash-language-server                  # Bash / Shell
      dockerfile-language-server             # Docker (dockerls)
      docker-compose-language-service       # docker-compose files
      clang-tools                           # C/C++ (clangd + clang-format)

      # ── Formatters ────────────────────────────────────────────────────
      stylua                                # Lua
      nixpkgs-fmt                           # Nix
      nix-doc                               # hover docs for Nix builtins
      ruff                                  # Python linter + formatter
      black                                 # Python formatter
      nodePackages.prettier                 # JS/TS/JSON/YAML/Markdown
      shfmt                                 # Shell

      # ── Debug adapters ────────────────────────────────────────────────
      python3Packages.debugpy               # Python DAP adapter (dap.core extra)

      # ── Jupyter / molten-nvim Python runtime ──────────────────────────
      # molten-nvim communicates with Jupyter kernels via these packages.
      # pynvim: Python provider for Neovim RPC.
      # jupyter-client + ipykernel: kernel protocol + Python kernel.
      # cairosvg + pillow: SVG/image rendering for inline plot output.
      # nbformat: notebook file format (needed for .ipynb open/save).
      python3Packages.pynvim
      python3Packages.jupyter-client
      python3Packages.ipykernel
      python3Packages.cairosvg
      python3Packages.pillow
      python3Packages.nbformat

      # ── Image rendering (image.nvim backend) ──────────────────────────
      imagemagick                           # image.nvim uses magick for conversion
    ];

    # ── Language extras (configures plugin specs + Mason disable) ─────────
    extras = {
      lang.python.enable     = true;
      lang.nix.enable        = true;
      lang.markdown.enable   = true;
      lang.docker.enable     = true;
      lang.yaml.enable       = true;
      lang.json.enable       = true;
      lang.typescript.enable = true;
      lang.toml.enable       = true;
      lang.clangd.enable     = true;
      lang.helm.enable       = true;

      # ── DAP + test: activate nvim-dap and neotest (lang.python uses both
      # as optional dependencies — they only load when these extras are on) ─
      dap.core.enable  = true;
      test.core.enable = true;
    };

    # ── Treesitter parsers (baked in at build time) ────────────────────────
    treesitterParsers = with pkgs.vimPlugins.nvim-treesitter-parsers; [
      bash c cpp css dockerfile fish go html javascript json lua
      markdown markdown_inline nix python query rust toml tsx
      typescript vim vimdoc yaml
    ];

    # ── Disable ruff hover: pyright provides better type/docstring hover ─────
    # ruff hover only shows lint rule descriptions; pyright handles K properly.
    plugins.ruff-hover-fix = ''
      return {
        {
          "neovim/nvim-lspconfig",
          init = function()
            vim.api.nvim_create_autocmd("LspAttach", {
              callback = function(args)
                local client = vim.lsp.get_client_by_id(args.data.client_id)
                if client and client.name == "ruff" then
                  client.server_capabilities.hoverProvider = false
                end
              end,
            })
          end,
        },
      }
    '';

    # ── iron.nvim — REPL (send code to a live Python/shell interpreter) ───
    # <leader>rs = start REPL   <leader>rc = send motion/visual
    # <leader>rl = send line    <leader>rf = send file   <leader>rq = quit
    plugins.iron = ''
      return {
        {
          "Vigemus/iron.nvim",
          opts = {
            config = {
              repl_definition = {
                python = { command = { "python3" } },
              },
              repl_open_cmd = "belowright 15 split",
            },
            keymaps = {
              send_motion  = "<leader>rc",
              visual_send  = "<leader>rc",
              send_file    = "<leader>rf",
              send_line    = "<leader>rl",
              cr           = "<leader>r<cr>",
              interrupt    = "<leader>r<space>",
              exit         = "<leader>rq",
              clear        = "<leader>rx",
            },
            highlight = { italic = true },
          },
          keys = {
            { "<leader>rs", "<cmd>IronRepl<cr>",    desc = "Start REPL" },
            { "<leader>rr", "<cmd>IronRestart<cr>", desc = "Restart REPL" },
            { "<leader>rh", "<cmd>IronHide<cr>",    desc = "Hide REPL" },
          },
        },
      }
    '';

    # ── image.nvim — inline image rendering via Kitty protocol ────────────
    # Required by molten-nvim for plot output. Uses Kitty's image protocol
    # (already enabled via use_kitty_protocol in nushell config).
    plugins.image = ''
      return {
        {
          "3rd/image.nvim",
          build = false,  -- nixpkgs pre-compiles the Lua binding; skip luarocks/hererocks
          opts = {
            backend = "kitty",
            integrations = {
              markdown = { enabled = true, clear_in_insert_mode = false },
            },
            max_width  = 100,
            max_height = 12,
            max_height_window_percentage = math.huge,
            max_width_window_percentage  = math.huge,
            window_overlap_clear_enabled = true,
            window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
          },
        },
      }
    '';

    # ── molten-nvim — Jupyter kernel inside Neovim ────────────────────────
    # Run `:MoltenInit` to attach a kernel. Outputs (including plots) render
    # inline via image.nvim + Kitty. Works with any ipykernel-compatible kernel.
    # <leader>mi = init kernel    <leader>me = eval operator
    # <leader>ml = eval line      <leader>mv = eval visual
    # <leader>mo = show output    <leader>md = delete cell
    plugins.molten = ''
      return {
        {
          "benlubas/molten-nvim",
          dependencies = { "3rd/image.nvim" },
          build = ":UpdateRemotePlugins",  -- registers Python rplugin; harmless if already done
          opts = {
            image_provider        = "image.nvim",
            auto_open_output      = false,
            virt_lines_off_by_1   = true,
            wrap_output           = false,
            output_win_max_height = 20,
          },
          keys = {
            { "<leader>mi", "<cmd>MoltenInit<cr>",                 desc = "Init kernel" },
            { "<leader>me", "<cmd>MoltenEvaluateOperator<cr>",     desc = "Eval operator", expr = true },
            { "<leader>ml", "<cmd>MoltenEvaluateLine<cr>",         desc = "Eval line" },
            { "<leader>mv", "<cmd>MoltenEvaluateVisual<cr>",       desc = "Eval visual",   mode = "v" },
            { "<leader>mr", "<cmd>MoltenReevaluateCell<cr>",       desc = "Re-eval cell" },
            { "<leader>md", "<cmd>MoltenDelete<cr>",               desc = "Delete cell" },
            { "<leader>mo", "<cmd>MoltenShowOutput<cr>",           desc = "Show output" },
            { "<leader>mh", "<cmd>MoltenHideOutput<cr>",           desc = "Hide output" },
            { "<leader>mx", "<cmd>MoltenInterrupt<cr>",            desc = "Interrupt kernel" },
          },
        },
      }
    '';

    # ── Catppuccin theme (not available as an extra — use plugin spec) ─────
    plugins.colorscheme = ''
      return {
        "catppuccin/nvim",
        name = "catppuccin",
        opts = { flavour = "mocha" },
      }
    '';
  };
}
