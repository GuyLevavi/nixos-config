# home/nixvim.nix — NixVim configuration (replaces LazyVim)
# All plugins are pre-fetched by Nix at build time — fully airgap-safe.
# No lazy.nvim, no Mason, no runtime downloads.
{ pkgs, ... }:

{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    vimdiffAlias = true;

    # ── Formatters, linters, tools on PATH for conform + LSP ───────────
    extraPackages = with pkgs; [
      stylua                   # Lua formatter
      nixpkgs-fmt              # Nix formatter
      ruff                     # Python linter + formatter
      black                    # Python formatter (kept for projects that require it)
      nix-doc                  # hover docs for Nix builtins (used by nixd)
      nodePackages.prettier    # JS/TS/JSON/YAML/Markdown formatter
      python3Packages.debugpy  # Python DAP adapter
      ripgrep                  # telescope live_grep
      fd                       # telescope find_files
    ];

    globals = {
      mapleader = " ";
      maplocalleader = ",";
    };

    opts = {
      number         = true;
      relativenumber = true;
      expandtab      = true;
      tabstop        = 2;
      shiftwidth     = 2;
      signcolumn     = "yes";
      updatetime     = 250;
      termguicolors  = true;
      undofile       = true;
      ignorecase     = true;
      smartcase      = true;
      splitright     = true;
      splitbelow     = true;
      cursorline     = true;
      scrolloff      = 8;
      wrap           = false;
      showmode       = false;        # lualine shows the mode
      clipboard      = "unnamedplus"; # system clipboard
      mouse          = "a";
    };

    # ── Colorscheme ───────────────────────────────────────────────────────
    # Uses NixVim's built-in catppuccin module (NOT catppuccin/nix's nvim module).
    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "mocha";
        term_colors = true;
        transparent_background = false;
        integrations = {
          blink_cmp              = true;
          gitsigns               = true;
          neotree                = true;
          treesitter             = true;
          telescope.enabled      = true;
          indent_blankline.enabled = true;
          flash                  = true;
          which_key              = true;
          noice                  = true;
          dap.enabled            = true;
          dap.enable_ui          = true;
          mini.enabled           = true;
        };
      };
    };

    plugins = {

      # ── Treesitter — all grammars baked in at build time ───────────────
      treesitter = {
        enable = true;
        grammarPackages = pkgs.vimPlugins.nvim-treesitter.allGrammars;
        settings = {
          highlight.enable = true;
          indent.enable    = true;
        };
      };
      treesitter-context = {
        enable = true;
        settings.max_lines = 3;
      };

      # ── Telescope ─────────────────────────────────────────────────────
      telescope = {
        enable = true;
        extensions.fzf-native.enable = true;
        keymaps = {
          "<leader>ff" = { action = "find_files"; options.desc = "Find files"; };
          "<leader>fg" = { action = "live_grep"; options.desc = "Grep"; };
          "<leader>fb" = { action = "buffers"; options.desc = "Buffers"; };
          "<leader>fh" = { action = "help_tags"; options.desc = "Help"; };
          "<leader>fd" = { action = "diagnostics"; options.desc = "Diagnostics"; };
          "<leader>fr" = { action = "oldfiles"; options.desc = "Recent files"; };
          "<leader>fw" = { action = "grep_string"; options.desc = "Grep word"; };
          "<leader>gc" = { action = "git_commits"; options.desc = "Git commits"; };
          "<leader>gs" = { action = "git_status"; options.desc = "Git status"; };
          "<C-p>"      = { action = "git_files"; options.desc = "Git files"; };
        };
        settings.defaults = {
          sorting_strategy = "ascending";
          layout_config.prompt_position = "top";
          file_ignore_patterns = [ "^.git/" "^__pycache__/" "^node_modules/" ];
        };
      };

      # ── LSP ───────────────────────────────────────────────────────────
      lsp = {
        enable = true;
        inlayHints = true;
        keymaps = {
          silent = true;
          lspBuf = {
            "gd"         = "definition";
            "gD"         = "references";
            "K"          = "hover";
            "gi"         = "implementation";
            "gt"         = "type_definition";
            "<leader>rn" = "rename";
            "<leader>ca" = "code_action";
          };
          diagnostic = {
            "[d"        = "goto_prev";
            "]d"        = "goto_next";
            "<leader>d" = "open_float";
          };
        };
        servers = {
          # Lua — neovim config development
          lua_ls = {
            enable = true;
            settings.Lua = {
              runtime.version       = "LuaJIT";
              workspace.checkThirdParty = false;
              telemetry.enable      = false;
            };
          };
          # Nix — flake-aware
          nixd = {
            enable = true;
            settings.nixd.formatting.command = [ "nixpkgs-fmt" ];
          };
          # Python — type checking + completion
          basedpyright = {
            enable = true;
            settings.basedpyright.analysis = {
              typeCheckingMode     = "standard";
              autoImportCompletions = true;
            };
          };
          # Python — linting, formatting, code actions (ruff's built-in LSP)
          ruff.enable = true;
          # TypeScript / JavaScript
          ts_ls.enable = true;
          # YAML — with Kubernetes schema support
          yamlls = {
            enable = true;
            settings.yaml = {
              schemas."kubernetes" = "/*.yaml";
              schemaStore.enable   = true;
            };
          };
          # JSON / JSONC
          jsonls.enable = true;
          # Docker
          dockerls.enable = true;
          docker_compose_language_service.enable = true;
          # Helm charts
          helm_ls.enable = true;
        };
      };

      # ── Completion — blink-cmp (modern, fast) ─────────────────────────
      blink-cmp = {
        enable = true;
        setupLspCapabilities = true;
        settings = {
          keymap.preset = "super-tab";
          sources = {
            providers.buffer.score_offset = -7;
            # Enable completion in : / ? command line
            cmdline = {};
          };
          completion = {
            accept.auto_brackets.enabled = true;
            documentation.auto_show      = true;
          };
          appearance = {
            use_nvim_cmp_as_default = true;
            nerd_font_variant       = "normal";
          };
          signature.enabled = true;
        };
      };

      # ── Formatting — conform ─────────────────────────────────────────
      conform-nvim = {
        enable = true;
        settings = {
          format_on_save = {
            timeout_ms   = 500;
            lsp_fallback = true;
          };
          formatters_by_ft = {
            lua        = [ "stylua" ];
            nix        = [ "nixpkgs-fmt" ];
            python     = [ "ruff_format" ];
            javascript = [ "prettier" ];
            typescript = [ "prettier" ];
            json       = [ "prettier" ];
            yaml       = [ "prettier" ];
            markdown   = [ "prettier" ];
          };
        };
      };

      # ── DAP — Python debugging ───────────────────────────────────────
      dap = {
        enable = true;
        extensions = {
          dap-python.enable       = true;
          dap-ui.enable           = true;
          dap-virtual-text.enable = true;
        };
      };

      # ── Git ──────────────────────────────────────────────────────────
      gitsigns = {
        enable = true;
        settings = {
          signs = {
            add.text          = "│";
            change.text       = "│";
            delete.text       = "_";
            topdelete.text    = "‾";
            changedelete.text = "~";
          };
          current_line_blame = false;
        };
      };
      neogit = {
        enable = true;
        settings = {
          kind = "tab";
          integrations.diffview = true;
        };
      };
      diffview.enable = true;
      fugitive.enable = true;

      # ── File explorer ────────────────────────────────────────────────
      neo-tree = {
        enable = true;
        settings = {
          close_if_last_window = true;
          filesystem = {
            follow_current_file.enabled = true;
            use_libuv_file_watcher      = true;
            filtered_items = {
              hide_dotfiles   = false;
              hide_gitignored = true;
            };
          };
        };
      };

      # ── UI ───────────────────────────────────────────────────────────
      lualine = {
        enable = true;
        settings.options = {
          theme        = "catppuccin";
          globalstatus = true;
          component_separators = { left = ""; right = ""; };
          section_separators   = { left = ""; right = ""; };
        };
      };

      bufferline = {
        enable = true;
        settings.options = {
          diagnostics          = "nvim_lsp";
          always_show_bufferline = false;
          offsets = [{
            filetype  = "neo-tree";
            text      = "Explorer";
            highlight = "Directory";
          }];
        };
      };

      indent-blankline = {
        enable = true;
        settings = {
          indent.char    = "│";
          scope.enabled  = true;
        };
      };

      noice = {
        enable = true;
        settings = {
          lsp.override = {
            "vim.lsp.util.convert_input_to_markdown_lines" = true;
            "vim.lsp.util.stylize_markdown"                = true;
          };
          presets = {
            bottom_search         = true;
            command_palette       = true;
            long_message_to_split = true;
          };
        };
      };

      # ── Navigation ──────────────────────────────────────────────────
      flash = {
        enable = true;
        settings.modes.search.enabled = false;  # don't override /
      };

      which-key = {
        enable = true;
        settings = {
          icons.mappings = true;
          spec = [
            { __unkeyed-1 = "<leader>f"; group = "Find"; }
            { __unkeyed-1 = "<leader>g"; group = "Git"; }
            { __unkeyed-1 = "<leader>c"; group = "Code"; }
            { __unkeyed-1 = "<leader>d"; group = "Debug"; }
            { __unkeyed-1 = "<leader>b"; group = "Buffer"; }
            { __unkeyed-1 = "<leader>x"; group = "Trouble"; }
            { __unkeyed-1 = "<leader>w"; group = "Window"; }
            { __unkeyed-1 = "<leader>s"; group = "Search"; }
            { __unkeyed-1 = "<leader>u"; group = "UI"; }
            { __unkeyed-1 = "<leader>q"; group = "Quit/Session"; }
            { __unkeyed-1 = "<leader>S"; group = "Spectre"; }
          ];
        };
      };

      # ── Session management — persistence.nvim ────────────────────────
      # Saves/restores sessions per working directory (like lazyvim's extra).
      # <leader>qs = restore session; <leader>qS = select session; <leader>qd = delete
      persistence = {
        enable = true;
        settings.options = [ "buffers" "curdir" "tabpages" "winsize" "skiprtp" ];
      };

      # ── Dashboard — startup screen ────────────────────────────────────
      dashboard = {
        enable = true;
        settings = {
          theme = "doom";
          config = {
            header = [
              ""
              "  ███╗   ██╗██╗██╗  ██╗██╗   ██╗██╗███╗   ███╗"
              "  ████╗  ██║██║╚██╗██╔╝██║   ██║██║████╗ ████║"
              "  ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██║██╔████╔██║"
              "  ██║╚██╗██║██║ ██╔██╗ ╚██╗ ██╔╝██║██║╚██╔╝██║"
              "  ██║ ╚████║██║██╔╝ ██╗ ╚████╔╝ ██║██║ ╚═╝ ██║"
              "  ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝"
              ""
            ];
            shortcut = [
              { desc = "  Find File";    group = "Label"; action = "Telescope find_files";            key = "f"; }
              { desc = "  Recent Files"; group = "Label"; action = "Telescope oldfiles";              key = "r"; }
              { desc = "  Grep";         group = "Label"; action = "Telescope live_grep";             key = "/"; }
              { desc = "  Session";      group = "Label"; action.__raw = "require('persistence').load"; key = "s"; }
              { desc = "  Quit";         group = "Label"; action = "qa";                              key = "q"; }
            ];
            footer.__raw = ''
              function()
                local v = vim.version()
                return { "⚡ Neovim v" .. v.major .. "." .. v.minor .. "." .. v.patch }
              end
            '';
          };
        };
      };

      # ── Illuminate — highlight word under cursor ──────────────────────
      # Uses LSP references + treesitter to highlight all occurrences of the
      # word under the cursor. Much smarter than dumb string matching.
      illuminate = {
        enable = true;
        settings = {
          providers = [ "lsp" "treesitter" "regex" ];
          delay     = 200;
          under_cursor = true;
        };
      };

      # ── Spectre — project-wide find & replace ─────────────────────────
      # Panel-based search/replace across the entire project with regex support.
      # <leader>sr = open spectre; <leader>sw = search word under cursor
      spectre.enable = true;

      # ── Editing ─────────────────────────────────────────────────────
      todo-comments.enable  = true;
      trouble.enable        = true;
      comment.enable        = true;
      nvim-autopairs.enable = true;
      web-devicons.enable   = true;

      mini = {
        enable = true;
        modules = {
          surround = {};   # sa/sd/sr for add/delete/replace surrounding
          ai       = {};   # text objects: a/i with function, class, etc.
          bufremove = {};  # smarter buffer deletion (preserves layout)
          files    = {};   # floating file explorer (<leader>fm)
        };
      };
    };

    # ── Keymaps (LazyVim-compatible defaults) ────────────────────────────
    keymaps = [
      # ── File explorer ────────────────────────────────────────────────
      { key = "<leader>e";  action = "<cmd>Neotree toggle<cr>"; options.desc = "Explorer (neo-tree)"; }
      { key = "<leader>fm"; action.__raw = "function() require('mini.files').open(vim.api.nvim_buf_get_name(0)) end"; options.desc = "Mini files (current file)"; }
      { key = "<leader>fM"; action.__raw = "function() require('mini.files').open() end"; options.desc = "Mini files (cwd)"; }

      # ── Git ──────────────────────────────────────────────────────────
      { key = "<leader>gg"; action = "<cmd>Neogit<cr>"; options.desc = "Neogit"; }

      # ── Window management (<leader>w group) ──────────────────────────
      { mode = "n"; key = "<leader>wd"; action = "<C-w>c"; options.desc = "Close window"; }
      { mode = "n"; key = "<leader>ws"; action = "<cmd>split<cr>"; options.desc = "Split horizontal"; }
      { mode = "n"; key = "<leader>wv"; action = "<cmd>vsplit<cr>"; options.desc = "Split vertical"; }
      { mode = "n"; key = "<leader>ww"; action = "<C-w>w"; options.desc = "Other window"; }
      { mode = "n"; key = "<leader>-"; action = "<cmd>split<cr>"; options.desc = "Split horizontal"; }
      { mode = "n"; key = "<leader>|"; action = "<cmd>vsplit<cr>"; options.desc = "Split vertical"; }

      # ── Window navigation (Ctrl+hjkl) ────────────────────────────────
      { mode = "n"; key = "<C-h>"; action = "<C-w>h"; options.desc = "Window left"; }
      { mode = "n"; key = "<C-l>"; action = "<C-w>l"; options.desc = "Window right"; }
      { mode = "n"; key = "<C-j>"; action = "<C-w>j"; options.desc = "Window down"; }
      { mode = "n"; key = "<C-k>"; action = "<C-w>k"; options.desc = "Window up"; }

      # ── Window resize (Ctrl+arrows) ──────────────────────────────────
      { mode = "n"; key = "<C-Up>"; action = "<cmd>resize +2<cr>"; options.desc = "Increase height"; }
      { mode = "n"; key = "<C-Down>"; action = "<cmd>resize -2<cr>"; options.desc = "Decrease height"; }
      { mode = "n"; key = "<C-Left>"; action = "<cmd>vertical resize -2<cr>"; options.desc = "Decrease width"; }
      { mode = "n"; key = "<C-Right>"; action = "<cmd>vertical resize +2<cr>"; options.desc = "Increase width"; }

      # ── Buffer navigation ────────────────────────────────────────────
      { mode = "n"; key = "<S-h>"; action = "<cmd>bprevious<cr>"; options.desc = "Prev buffer"; }
      { mode = "n"; key = "<S-l>"; action = "<cmd>bnext<cr>"; options.desc = "Next buffer"; }
      { mode = "n"; key = "[b"; action = "<cmd>bprevious<cr>"; options.desc = "Prev buffer"; }
      { mode = "n"; key = "]b"; action = "<cmd>bnext<cr>"; options.desc = "Next buffer"; }
      { mode = "n"; key = "<leader>bb"; action = "<cmd>e #<cr>"; options.desc = "Alternate buffer"; }
      { mode = "n"; key = "<leader>bd"; action = "<cmd>bdelete<cr>"; options.desc = "Delete buffer"; }
      { mode = "n"; key = "<leader><leader>"; action = "<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>"; options.desc = "Switch buffer"; }

      # ── Search (Telescope extras) ────────────────────────────────────
      { mode = "n"; key = "<leader>/"; action = "<cmd>Telescope live_grep<cr>"; options.desc = "Grep"; }
      { mode = "n"; key = "<leader>,"; action = "<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>"; options.desc = "Buffers"; }
      { mode = "n"; key = "<leader>:"; action = "<cmd>Telescope command_history<cr>"; options.desc = "Command history"; }
      { mode = "n"; key = "<leader>fn"; action = "<cmd>enew<cr>"; options.desc = "New file"; }
      { mode = "n"; key = "<leader>sk"; action = "<cmd>Telescope keymaps<cr>"; options.desc = "Keymaps"; }
      { mode = "n"; key = "<leader>sm"; action = "<cmd>Telescope marks<cr>"; options.desc = "Marks"; }
      { mode = "n"; key = "<leader>sr"; action = "<cmd>Telescope resume<cr>"; options.desc = "Resume search"; }

      # ── UI toggles ──────────────────────────────────────────────────
      { mode = "n"; key = "<leader>ur"; action = "<cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><cr>"; options.desc = "Redraw / clear"; }
      { mode = "n"; key = "<leader>un"; action.__raw = "function() vim.o.number = not vim.o.number end"; options.desc = "Toggle line numbers"; }
      { mode = "n"; key = "<leader>uw"; action.__raw = "function() vim.o.wrap = not vim.o.wrap end"; options.desc = "Toggle word wrap"; }
      { mode = "n"; key = "<leader>ul"; action.__raw = "function() vim.o.relativenumber = not vim.o.relativenumber end"; options.desc = "Toggle relative numbers"; }

      # ── Better escape ────────────────────────────────────────────────
      { mode = "i"; key = "jk"; action = "<Esc>"; options.desc = "Escape"; }

      # ── Move lines ──────────────────────────────────────────────────
      { mode = "n"; key = "<A-j>"; action = "<cmd>m .+1<cr>=="; options.desc = "Move line down"; }
      { mode = "n"; key = "<A-k>"; action = "<cmd>m .-2<cr>=="; options.desc = "Move line up"; }
      { mode = "v"; key = "<A-j>"; action = ":m '>+1<cr>gv=gv"; options.desc = "Move down"; }
      { mode = "v"; key = "<A-k>"; action = ":m '<-2<cr>gv=gv"; options.desc = "Move up"; }
      { mode = "i"; key = "<A-j>"; action = "<esc><cmd>m .+1<cr>==gi"; options.desc = "Move down"; }
      { mode = "i"; key = "<A-k>"; action = "<esc><cmd>m .-2<cr>==gi"; options.desc = "Move up"; }

      # ── Quickfix / location list ─────────────────────────────────────
      { mode = "n"; key = "[q"; action = "<cmd>cprev<cr>"; options.desc = "Prev quickfix"; }
      { mode = "n"; key = "]q"; action = "<cmd>cnext<cr>"; options.desc = "Next quickfix"; }
      { key = "<leader>xl"; action = "<cmd>Trouble loclist toggle<cr>"; options.desc = "Location list"; }
      { key = "<leader>xq"; action = "<cmd>Trouble qflist toggle<cr>"; options.desc = "Quickfix list"; }

      # ── Trouble ──────────────────────────────────────────────────────
      { key = "<leader>xx"; action = "<cmd>Trouble diagnostics toggle<cr>"; options.desc = "Diagnostics"; }
      { key = "<leader>xd"; action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>"; options.desc = "Buffer diagnostics"; }

      # ── DAP (debugging) ──────────────────────────────────────────────
      { key = "<leader>db"; action.__raw = "function() require('dap').toggle_breakpoint() end"; options.desc = "Breakpoint"; }
      { key = "<leader>dc"; action.__raw = "function() require('dap').continue() end"; options.desc = "Continue"; }
      { key = "<leader>di"; action.__raw = "function() require('dap').step_into() end"; options.desc = "Step into"; }
      { key = "<leader>do"; action.__raw = "function() require('dap').step_over() end"; options.desc = "Step over"; }
      { key = "<leader>dO"; action.__raw = "function() require('dap').step_out() end"; options.desc = "Step out"; }
      { key = "<leader>dr"; action.__raw = "function() require('dap').repl.toggle() end"; options.desc = "REPL"; }
      { key = "<leader>du"; action.__raw = "function() require('dapui').toggle() end"; options.desc = "DAP UI"; }

      # ── Format ───────────────────────────────────────────────────────
      { mode = ["n" "v"]; key = "<leader>cf"; action.__raw = "function() require('conform').format({ async = true, lsp_fallback = true }) end"; options.desc = "Format"; }

      # ── Flash ────────────────────────────────────────────────────────
      { mode = ["n" "x" "o"]; key = "s"; action.__raw = "function() require('flash').jump() end"; options.desc = "Flash"; }
      { mode = ["n" "x" "o"]; key = "S"; action.__raw = "function() require('flash').treesitter() end"; options.desc = "Flash treesitter"; }

      # ── Session management ───────────────────────────────────────────
      { mode = "n"; key = "<leader>qs"; action.__raw = "function() require('persistence').load() end"; options.desc = "Restore session"; }
      { mode = "n"; key = "<leader>qS"; action.__raw = "function() require('persistence').select() end"; options.desc = "Select session"; }
      { mode = "n"; key = "<leader>ql"; action.__raw = "function() require('persistence').load({ last = true }) end"; options.desc = "Restore last session"; }
      { mode = "n"; key = "<leader>qd"; action.__raw = "function() require('persistence').stop() end"; options.desc = "Don't save session"; }

      # ── Spectre — find & replace ─────────────────────────────────────
      { mode = "n"; key = "<leader>sr"; action.__raw = "function() require('spectre').open() end"; options.desc = "Find & Replace (Spectre)"; }
      { mode = "n"; key = "<leader>sw"; action.__raw = "function() require('spectre').open_visual({select_word=true}) end"; options.desc = "Search word (Spectre)"; }
      { mode = "v"; key = "<leader>sw"; action.__raw = "function() require('spectre').open_visual() end"; options.desc = "Search selection (Spectre)"; }

      # ── Buffer delete (mini.bufremove) ───────────────────────────────
      { mode = "n"; key = "<leader>bd"; action.__raw = "function() require('mini.bufremove').delete() end"; options.desc = "Delete buffer"; }
      { mode = "n"; key = "<leader>bD"; action.__raw = "function() require('mini.bufremove').delete(0, true) end"; options.desc = "Delete buffer (force)"; }

      # ── Misc ─────────────────────────────────────────────────────────
      { mode = "n"; key = "<Esc>"; action = "<cmd>noh<cr>"; options.desc = "Clear highlights"; }
      { mode = "v"; key = "<"; action = "<gv"; }
      { mode = "v"; key = ">"; action = ">gv"; }
      { mode = ["n" "i" "v"]; key = "<C-s>"; action = "<cmd>w<cr><esc>"; options.desc = "Save"; }
      { mode = "n"; key = "<leader>qq"; action = "<cmd>qa<cr>"; options.desc = "Quit all"; }

      # ── Yank enhancements ────────────────────────────────────────────
      # Don't clobber register on paste in visual mode
      { mode = "v"; key = "p"; action = ''"_dP''; options.desc = "Paste without yank"; }
    ];

    # ── Performance ───────────────────────────────────────────────────────
    performance.byteCompileLua = {
      enable  = true;
      plugins = true;
    };
  };
}
