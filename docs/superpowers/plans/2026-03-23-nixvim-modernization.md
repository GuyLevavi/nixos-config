# NixVim Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modernize `home/nixvim.nix` on a feature branch — fix bugs, consolidate UI under snacks.nvim, add Python testing/venv/outline/markdown tools, and expand LSP coverage.

**Architecture:** All changes land in `home/nixvim.nix` (plugins, keymaps, LSP, Python config) with one companion edit to `home/base.nix` (tmux smart-splits config). Each task ends with a successful `rb` (nixos-rebuild switch) and a commit. No Mason, no runtime downloads — everything through Nix.

**Tech Stack:** NixVim (Nix-managed Neovim), nixpkgs unstable, home-manager. Build command: `rb` = `sudo nixos-rebuild switch --flake /etc/nixos#nixbox`. Debug: add `--show-trace` on failure.

**Spec:** `docs/superpowers/specs/2026-03-23-nixvim-modernization-design.md`

---

## File Map

| File | Changes |
|------|---------|
| `home/nixvim.nix` | All plugin, keymap, LSP, and Python changes |
| `home/base.nix` | Task 5 only: add smart-splits tmux keybinding config |

---

## Task 1: Create the Feature Branch

**Files:** none (git only)

- [ ] **Step 1: Create and switch to branch**

  ```bash
  cd /etc/nixos
  git checkout -b feat/nixvim-modernization
  git status  # confirm on new branch
  ```

---

## Task 2: Remove Old Plugins and Fix Keymap Conflict

Remove 5 plugins (dashboard-nvim, indent-blankline, illuminate, fugitive, spectre), fix the `<leader>sr` conflict, remove `<C-hjkl>` and `<C-arrow>` manual keymaps (smart-splits will own these), update catppuccin integrations, and remove the orphaned `<leader>S` which-key group.

**Files:**
- Modify: `home/nixvim.nix`

- [ ] **Step 1: Remove `illuminate` plugin block (lines ~386–396)**

  Delete the entire `illuminate` block:
  ```nix
  # DELETE this block:
  illuminate = {
    enable = true;
    settings = {
      providers = [ "lsp" "treesitter" "regex" ];
      delay     = 200;
      under_cursor = true;
    };
  };
  ```

- [ ] **Step 2: Remove `indent-blankline` plugin block (lines ~296–302)**

  Delete the entire `indent-blankline` block:
  ```nix
  # DELETE this block:
  indent-blankline = {
    enable = true;
    settings = {
      indent.char    = "│";
      scope.enabled  = true;
    };
  };
  ```

- [ ] **Step 3: Remove `dashboard` plugin block (lines ~353–384)**

  Delete the entire `dashboard` block (from `dashboard = {` to its closing `};`).

- [ ] **Step 4: Remove `fugitive` and `spectre` (lines ~254, ~401)**

  Delete these two lines:
  ```nix
  # DELETE:
  fugitive.enable = true;
  # DELETE:
  spectre.enable  = true;
  ```

- [ ] **Step 5: Update catppuccin integrations block**

  In `colorschemes.catppuccin.settings.integrations`, make two changes:

  Replace:
  ```nix
  indent_blankline.enabled = true;
  ```
  With:
  ```nix
  indent_blankline.enabled = false;
  snacks.enabled           = true;
  ```

- [ ] **Step 6: Remove orphaned `<leader>S` which-key group**

  In the `which-key.settings.spec` list, delete:
  ```nix
  { __unkeyed-1 = "<leader>S"; group = "Spectre"; }
  ```

- [ ] **Step 7: Fix `<leader>sr` keymap conflict — Telescope resume**

  Find the line binding `<leader>sr` to Telescope resume (~line 467):
  ```nix
  { mode = "n"; key = "<leader>sr"; action = "<cmd>Telescope resume<cr>"; options.desc = "Resume search"; }
  ```
  Change the key to `<leader>sR`:
  ```nix
  { mode = "n"; key = "<leader>sR"; action = "<cmd>Telescope resume<cr>"; options.desc = "Resume search"; }
  ```

- [ ] **Step 8: Remove `<leader>sr`/`<leader>sw` spectre keymaps (lines ~519–521)**

  Delete these three lines:
  ```nix
  # DELETE:
  { mode = "n"; key = "<leader>sr"; action.__raw = "function() require('spectre').open() end"; options.desc = "Find & Replace (Spectre)"; }
  { mode = "n"; key = "<leader>sw"; action.__raw = "function() require('spectre').open_visual({select_word=true}) end"; options.desc = "Search word (Spectre)"; }
  { mode = "v"; key = "<leader>sw"; action.__raw = "function() require('spectre').open_visual() end"; options.desc = "Search selection (Spectre)"; }
  ```

- [ ] **Step 9: Remove manual `<C-hjkl>` window navigation keymaps (lines ~440–443)**

  Delete these four lines (smart-splits will own them):
  ```nix
  # DELETE:
  { mode = "n"; key = "<C-h>"; action = "<C-w>h"; options.desc = "Window left"; }
  { mode = "n"; key = "<C-l>"; action = "<C-w>l"; options.desc = "Window right"; }
  { mode = "n"; key = "<C-j>"; action = "<C-w>j"; options.desc = "Window down"; }
  { mode = "n"; key = "<C-k>"; action = "<C-w>k"; options.desc = "Window up"; }
  ```

- [ ] **Step 10: Remove manual `<C-arrow>` resize keymaps (lines ~445–448)**

  Delete these four lines (smart-splits will own resize):
  ```nix
  # DELETE:
  { mode = "n"; key = "<C-Up>"; action = "<cmd>resize +2<cr>"; options.desc = "Increase height"; }
  { mode = "n"; key = "<C-Down>"; action = "<cmd>resize -2<cr>"; options.desc = "Decrease height"; }
  { mode = "n"; key = "<C-Left>"; action = "<cmd>vertical resize -2<cr>"; options.desc = "Decrease width"; }
  { mode = "n"; key = "<C-Right>"; action = "<cmd>vertical resize +2<cr>"; options.desc = "Increase width"; }
  ```

- [ ] **Step 11: Build to verify clean removal**

  ```bash
  rb
  ```
  Expected: build succeeds. If it fails, run `sudo nixos-rebuild switch --flake /etc/nixos#nixbox --show-trace` to diagnose.

  Open `nvim` and verify:
  - No "please configure your own center" dashboard message (nvim opens to blank buffer now — fine, snacks comes next)
  - `:checkhealth` shows no errors for removed plugins

- [ ] **Step 12: Commit**

  ```bash
  cd /etc/nixos
  git add home/nixvim.nix
  git commit -m "refactor: remove deprecated plugins, fix keymap conflicts"
  ```

---

## Task 3: Add snacks.nvim

Adds the snacks.nvim plugin with 7 sub-modules: dashboard, indent, words, notifier, terminal, gitbrowse, lazygit. This restores the dashboard, indent guides, and word highlighting removed in Task 2.

**Files:**
- Modify: `home/nixvim.nix`

- [ ] **Step 1: Add the `snacks` plugin block**

  Inside the `plugins = {` block (after the existing plugin entries, before the closing `};`), add:

  ```nix
  # ── Snacks.nvim — modern utility collection ──────────────────────────
  # Replaces: dashboard-nvim, indent-blankline, illuminate.
  # Adds: notifier toasts, floating terminal, git-browse, lazygit float.
  snacks = {
    enable = true;
    settings = {
      # ── Replaces dashboard-nvim ───────────────────────────────────────
      dashboard = {
        enabled = true;
        preset = {
          header = ''
              ███╗   ██╗██╗██╗  ██╗██╗   ██╗██╗███╗   ███╗
              ████╗  ██║██║╚██╗██╔╝██║   ██║██║████╗ ████║
              ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██║██╔████╔██║
              ██║╚██╗██║██║ ██╔██╗ ╚██╗ ██╔╝██║██║╚██╔╝██║
              ██║ ╚████║██║██╔╝ ██╗ ╚████╔╝ ██║██║ ╚═╝ ██║
              ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝'';
          keys = [
            { icon = " "; key = "f"; desc = "Find File"; action = ":Telescope find_files"; }
            { icon = " "; key = "r"; desc = "Recent Files"; action = ":Telescope oldfiles"; }
            { icon = " "; key = "/"; desc = "Grep"; action = ":Telescope live_grep"; }
            { icon = " "; key = "s"; desc = "Restore Session"; action.__raw = "function() require('persistence').load() end"; }
            { icon = " "; key = "q"; desc = "Quit"; action = ":qa"; }
          ];
        };
      };
      # ── Replaces indent-blankline ─────────────────────────────────────
      indent = {
        enabled = true;
        animate.enabled = true;
      };
      # ── Replaces illuminate ───────────────────────────────────────────
      words = {
        enabled   = true;
        debounce  = 200;
      };
      # ── New: toast notifications ──────────────────────────────────────
      # noice still handles LSP/command-line messages.
      notifier = {
        enabled = true;
        timeout = 3000;
      };
      # ── New: floating terminal ────────────────────────────────────────
      terminal.enabled = true;
      # ── New: open file in browser ─────────────────────────────────────
      gitbrowse.enabled = true;
      # ── New: lazygit in a float ───────────────────────────────────────
      lazygit.enabled = true;
      # ── Disable: conflicts with telescope / mini.bufremove ────────────
      picker.enabled    = false;
      bufdelete.enabled = false;
      scroll.enabled    = false;
      animate.enabled   = false;
    };
  };
  ```

- [ ] **Step 2: Add snacks keymaps**

  In the `keymaps = [` list, add:

  ```nix
  # ── Snacks ────────────────────────────────────────────────────────────
  { mode = "n"; key = "<C-\\>"; action.__raw = "function() require('snacks').terminal() end"; options.desc = "Toggle terminal"; }
  { mode = "t"; key = "<C-\\>"; action.__raw = "function() require('snacks').terminal() end"; options.desc = "Toggle terminal"; }
  { mode = "n"; key = "<leader>gB"; action.__raw = "function() require('snacks').gitbrowse() end"; options.desc = "Git browse (open in browser)"; }
  { mode = "n"; key = "<leader>gl"; action.__raw = "function() require('snacks').lazygit() end"; options.desc = "Lazygit (float)"; }
  { mode = "n"; key = "<leader>un"; action.__raw = "function() require('snacks').notifier.hide() end"; options.desc = "Dismiss notifications"; }
  ```

- [ ] **Step 3: Build and verify**

  ```bash
  rb
  ```

  Open `nvim` (no file arg). Verify:
  - Dashboard shows with the ASCII header and 5 shortcuts
  - Press `f` on the dashboard → Telescope opens
  - Open a Python file: indent guides appear (animated when scrolling)
  - Hover a word: other occurrences highlight after ~200ms
  - `<C-\>` toggles a floating terminal
  - `<leader>gl` opens lazygit in a float

- [ ] **Step 4: Commit**

  ```bash
  git add home/nixvim.nix
  git commit -m "feat: add snacks.nvim (dashboard, indent, words, notifier, terminal)"
  ```

---

## Task 4: Add aerial.nvim — Code Outline

Shows a right-side symbol outline panel powered by LSP + treesitter. Essential for navigating large Python files.

**Files:**
- Modify: `home/nixvim.nix`

- [ ] **Step 1: Add the `aerial` plugin block**

  Inside `plugins = {`:

  ```nix
  # ── Aerial — code symbol outline ─────────────────────────────────────
  aerial = {
    enable = true;
    settings = {
      backends              = [ "lsp" "treesitter" ];
      layout.placement      = "edge";
      attach_mode           = "global";
      show_guides           = true;
      filter_kind           = false;  # show all symbol types
    };
  };
  ```

- [ ] **Step 2: Add telescope aerial extension**

  In `telescope = { ... extensions = { ... } }`, add:

  ```nix
  aerial.enable = true;
  ```

  So extensions block looks like:
  ```nix
  extensions = {
    fzf-native.enable = true;
    aerial.enable     = true;
  };
  ```

- [ ] **Step 3: Add `<leader>l` which-key group and aerial keymap**

  In `which-key.settings.spec`, add:
  ```nix
  { __unkeyed-1 = "<leader>l"; group = "Language"; }
  { __unkeyed-1 = "<leader>t"; group = "Test"; }
  ```

  In `keymaps = [`, add:
  ```nix
  # ── Aerial ────────────────────────────────────────────────────────────
  { mode = "n"; key = "<leader>lo"; action = "<cmd>AerialToggle<cr>"; options.desc = "Toggle outline"; }
  { mode = "n"; key = "<leader>ls"; action = "<cmd>Telescope aerial<cr>"; options.desc = "Symbol search"; }
  ```

- [ ] **Step 4: Build and verify**

  ```bash
  rb
  ```

  Open a Python file with functions/classes. Verify:
  - `<leader>lo` toggles the right-side outline panel showing functions/classes
  - `<leader>ls` opens telescope with symbol list
  - Which-key shows "Language" when pressing `<leader>l`

- [ ] **Step 5: Commit**

  ```bash
  git add home/nixvim.nix
  git commit -m "feat: add aerial.nvim code outline with telescope integration"
  ```

---

## Task 5: Add smart-splits.nvim — Tmux-aware Window Navigation

Replaces the manual `<C-hjkl>` keymaps with smart-splits versions that also navigate tmux panes. Resize moves to `<A-arrow>`.

**Files:**
- Modify: `home/nixvim.nix`
- Modify: `home/base.nix`

- [ ] **Step 1: Add the `smart-splits` plugin block**

  Inside `plugins = {` in `home/nixvim.nix`:

  ```nix
  # ── Smart Splits — tmux-aware window navigation ───────────────────────
  # <C-hjkl> crosses Neovim splits AND tmux panes.
  # <A-arrow> resizes splits from any tmux pane.
  smart-splits = {
    enable = true;
    settings = {
      ignored_filetypes     = [ "nofile" "quickfix" "prompt" ];
      ignored_buftypes      = [ "NvimTree" ];
      default_amount        = 3;
      at_edge               = "wrap";
      move_cursor_same_row  = false;
    };
  };
  ```

- [ ] **Step 2: Add smart-splits keymaps in `home/nixvim.nix`**

  In `keymaps = [`, add:

  ```nix
  # ── Smart Splits — navigate (tmux-aware) ─────────────────────────────
  { mode = "n"; key = "<C-h>"; action.__raw = "function() require('smart-splits').move_cursor_left() end"; options.desc = "Window left"; }
  { mode = "n"; key = "<C-j>"; action.__raw = "function() require('smart-splits').move_cursor_down() end"; options.desc = "Window down"; }
  { mode = "n"; key = "<C-k>"; action.__raw = "function() require('smart-splits').move_cursor_up() end"; options.desc = "Window up"; }
  { mode = "n"; key = "<C-l>"; action.__raw = "function() require('smart-splits').move_cursor_right() end"; options.desc = "Window right"; }
  # ── Smart Splits — resize (A-arrow, avoids A-j/A-k move-line conflict)
  { mode = "n"; key = "<A-Left>";  action.__raw = "function() require('smart-splits').resize_left() end"; options.desc = "Resize left"; }
  { mode = "n"; key = "<A-Down>";  action.__raw = "function() require('smart-splits').resize_down() end"; options.desc = "Resize down"; }
  { mode = "n"; key = "<A-Up>";    action.__raw = "function() require('smart-splits').resize_up() end"; options.desc = "Resize up"; }
  { mode = "n"; key = "<A-Right>"; action.__raw = "function() require('smart-splits').resize_right() end"; options.desc = "Resize right"; }
  ```

- [ ] **Step 3: Add tmux keybindings to `home/base.nix`**

  In `programs.tmux.extraConfig`, append after the existing content:

  ```nix
  # Smart-splits — tmux-side keybindings
  # These forward C-hjkl to Neovim when Neovim is focused,
  # and navigate tmux panes otherwise.
  is_vim = "ps -o state= -o comm= -t '#{pane_tty}' | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
  bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h' 'select-pane -L'
  bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j' 'select-pane -D'
  bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k' 'select-pane -U'
  bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l' 'select-pane -R'
  bind-key -T copy-mode-vi 'C-h' select-pane -L
  bind-key -T copy-mode-vi 'C-j' select-pane -D
  bind-key -T copy-mode-vi 'C-k' select-pane -U
  bind-key -T copy-mode-vi 'C-l' select-pane -R
  ```

  > **Note:** The `is_vim` value must be on a single line in tmux config. In Nix, put it inside the `''...''` multiline string as a single line.

- [ ] **Step 4: Build and verify**

  ```bash
  rb
  ```

  Open two nvim windows in a split. Verify:
  - `<C-h/j/k/l>` navigates between Neovim splits
  - `<A-Left/Right/Up/Down>` resizes splits
  - In tmux with two panes: `<C-h>` crosses from Neovim into the tmux pane

- [ ] **Step 5: Commit**

  ```bash
  git add home/nixvim.nix home/base.nix
  git commit -m "feat: add smart-splits.nvim with tmux integration"
  ```

---

## Task 6: Add render-markdown.nvim — Inline Markdown Rendering

Renders markdown headers, bold/italic, code blocks, and tables with icons and colors directly inside the buffer (not a split preview).

**Files:**
- Modify: `home/nixvim.nix`

- [ ] **Step 1: Add the `render-markdown` plugin block**

  Inside `plugins = {`:

  ```nix
  # ── Render Markdown — inline markdown rendering ───────────────────────
  # Renders .md files with styled headers, bold, code blocks, tables.
  # Toggle with <leader>um. Auto-enables on markdown filetype.
  render-markdown = {
    enable = true;
    settings = {
      file_types = [ "markdown" ];
      render_modes = [ "n" "c" "t" ];
      heading = {
        enabled = true;
        icons   = [ "󰲡 " "󰲣 " "󰲥 " "󰲧 " "󰲩 " "󰲫 " ];
      };
      code = {
        enabled   = true;
        sign      = false;
        style     = "full";
        border    = "thin";
      };
      bullet = {
        enabled = true;
        icons   = [ "●" "○" "◆" "◇" ];
      };
    };
  };
  ```

- [ ] **Step 2: Add toggle keymap**

  In `keymaps = [`, add:

  ```nix
  # ── Render Markdown ───────────────────────────────────────────────────
  { mode = "n"; key = "<leader>um"; action = "<cmd>RenderMarkdown toggle<cr>"; options.desc = "Toggle markdown render"; }
  ```

- [ ] **Step 3: Build and verify**

  ```bash
  rb
  ```

  Open any `.md` file. Verify:
  - Headers render with icons and color (e.g., `# Title` shows as a styled heading)
  - Code blocks have a visible border/background
  - `<leader>um` toggles back to raw markdown text
  - Which-key shows "Toggle markdown render" for `<leader>um`

- [ ] **Step 4: Commit**

  ```bash
  git add home/nixvim.nix
  git commit -m "feat: add render-markdown.nvim for inline markdown rendering"
  ```

---

## Task 7: Add neotest + neotest-python — Test Runner

Run pytest tests from within Neovim. Results appear in a sidebar. Integrates with the existing debugpy DAP setup.

**Files:**
- Modify: `home/nixvim.nix`

- [ ] **Step 1: Add the `neotest` plugin block**

  Inside `plugins = {`:

  ```nix
  # ── Neotest — test runner ─────────────────────────────────────────────
  # Runs pytest from the editor. <leader>tr = run nearest, <leader>ts = summary.
  # Integrates with dap-python for <leader>td = debug nearest test.
  neotest = {
    enable = true;
    adapters.python = {
      enable   = true;
      settings = {
        runner  = "pytest";
        python  = ".venv/bin/python";  # override per-project if needed
      };
    };
    settings = {
      output.open_on_run = true;
      status.signs       = true;
    };
  };
  ```

  > **Note:** If the build fails with "unknown option `adapters.python`", the NixVim neotest module may use a different adapter syntax. Fallback: use `extraPlugins = [ pkgs.vimPlugins.neotest-python ]` and configure via `extraConfigLua`.

- [ ] **Step 2: Add neotest keymaps**

  In `keymaps = [`, add:

  ```nix
  # ── Neotest ───────────────────────────────────────────────────────────
  { mode = "n"; key = "<leader>tr"; action.__raw = "function() require('neotest').run.run() end"; options.desc = "Run nearest test"; }
  { mode = "n"; key = "<leader>tT"; action.__raw = "function() require('neotest').run.run(vim.fn.expand('%')) end"; options.desc = "Run file"; }
  { mode = "n"; key = "<leader>ts"; action.__raw = "function() require('neotest').summary.toggle() end"; options.desc = "Test summary"; }
  { mode = "n"; key = "<leader>to"; action.__raw = "function() require('neotest').output.open({ enter = true }) end"; options.desc = "Test output"; }
  { mode = "n"; key = "<leader>tS"; action.__raw = "function() require('neotest').run.stop() end"; options.desc = "Stop tests"; }
  { mode = "n"; key = "<leader>td"; action.__raw = "function() require('neotest').run.run({ strategy = 'dap' }) end"; options.desc = "Debug nearest test"; }
  ```

- [ ] **Step 3: Build and verify**

  ```bash
  rb
  ```

  Open a Python file with pytest functions (e.g., `def test_foo(): assert True`). Verify:
  - `<leader>tr` with cursor on the function runs that test
  - `<leader>ts` opens the test summary sidebar
  - `<leader>to` shows the output panel
  - Which-key shows the "Test" group for `<leader>t`

- [ ] **Step 4: Commit**

  ```bash
  git add home/nixvim.nix
  git commit -m "feat: add neotest with pytest adapter for Python test running"
  ```

---

## Task 8: Add venv-selector.nvim — Python Virtualenv Switcher

Finds virtualenvs (`.venv`, `venv`, `~/.virtualenvs`) and switches the active one, updating basedpyright + ruff LSP automatically.

**Files:**
- Modify: `home/nixvim.nix`

- [ ] **Step 1: Add venv-selector**

  First, try the NixVim module approach. Inside `plugins = {`:

  ```nix
  # ── Venv Selector — Python virtualenv switcher ────────────────────────
  # <leader>cv to pick a venv; auto-updates basedpyright + ruff LSP.
  venv-selector = {
    enable   = true;
    settings = {
      auto_refresh           = true;
      search_venv_managers   = false;
      dap_enabled            = true;     # updates dap-python when switching
    };
  };
  ```

  > **If the build fails** with "undefined attribute 'venv-selector'" (no NixVim module), use extraPlugins instead. Replace with:
  >
  > In `extraPlugins`:
  > ```nix
  > extraPlugins = with pkgs.vimPlugins; [ venv-selector-nvim ];
  > ```
  > In `extraConfigLua` (append):
  > ```lua
  > require('venv-selector').setup({
  >   auto_refresh = true,
  >   search_venv_managers = false,
  >   dap_enabled = true,
  > })
  > ```

- [ ] **Step 2: Add venv-selector keymap**

  In `keymaps = [`, add:

  ```nix
  # ── Venv Selector ─────────────────────────────────────────────────────
  { mode = "n"; key = "<leader>cv"; action = "<cmd>VenvSelect<cr>"; options.desc = "Select Python venv"; }
  ```

- [ ] **Step 3: Build and verify**

  ```bash
  rb
  ```

  In a directory with a `.venv`, open nvim and verify:
  - `<leader>cv` opens a picker listing virtualenvs
  - Selecting one updates the LSP (`:LspInfo` shows updated Python path)
  - Which-key shows "Select Python venv" for `<leader>cv`

- [ ] **Step 4: Commit**

  ```bash
  git add home/nixvim.nix
  git commit -m "feat: add venv-selector.nvim for Python virtualenv switching"
  ```

---

## Task 9: Add yanky.nvim — Clipboard Ring

Replaces built-in `p`/`P` with a yank history ring. Also remaps telescope `<C-p>` (git_files) to `<leader>fG` to avoid naming confusion.

**Files:**
- Modify: `home/nixvim.nix`

- [ ] **Step 1: Add the `yanky` plugin block**

  Inside `plugins = {`:

  ```nix
  # ── Yanky — clipboard ring ────────────────────────────────────────────
  # p/P paste from the ring; <C-p>/<C-n> cycle back/forward.
  # <leader>fy browses history in telescope.
  yanky = {
    enable = true;
    settings = {
      ring = {
        history_length  = 100;
        storage         = "shada";
        sync_with_numbered_registers = true;
      };
      preserve_cursor_position.enabled = true;
      textobj.enabled = false;
    };
  };
  ```

- [ ] **Step 2: Remap telescope `<C-p>` → `<leader>fG`**

  In `telescope.keymaps`, change:
  ```nix
  "<C-p>" = { action = "git_files"; options.desc = "Git files"; };
  ```
  To:
  ```nix
  "<leader>fG" = { action = "git_files"; options.desc = "Git files"; };
  ```

- [ ] **Step 3: Add yanky keymaps**

  In `keymaps = [`, add:

  ```nix
  # ── Yanky — clipboard ring ────────────────────────────────────────────
  { mode = ["n" "x"]; key = "p";    action = "<Plug>(YankyPutAfter)";       options.desc = "Paste after"; }
  { mode = ["n" "x"]; key = "P";    action = "<Plug>(YankyPutBefore)";      options.desc = "Paste before"; }
  { mode = ["n" "x"]; key = "gp";   action = "<Plug>(YankyGPutAfter)";      options.desc = "Paste after (cursor after)"; }
  { mode = ["n" "x"]; key = "gP";   action = "<Plug>(YankyGPutBefore)";     options.desc = "Paste before (cursor after)"; }
  { mode = "n";       key = "<C-p>"; action = "<Plug>(YankyCycleForward)";   options.desc = "Cycle yank forward"; }
  { mode = "n";       key = "<C-n>"; action = "<Plug>(YankyCycleBackward)";  options.desc = "Cycle yank backward"; }
  { mode = "n";       key = "<leader>fy"; action = "<cmd>Telescope yank_history<cr>"; options.desc = "Yank history"; }
  ```

  > **Note:** The `v` mode `p` keymap at line ~536 (`{ mode = "v"; key = "p"; action = '"_dP'; ... }`) conflicts with yanky. Delete it — yanky's visual paste handles this correctly.

- [ ] **Step 4: Remove the old visual `p` keymap**

  Find and delete:
  ```nix
  # DELETE:
  { mode = "v"; key = "p"; action = ''"_dP''; options.desc = "Paste without yank"; }
  ```

- [ ] **Step 5: Build and verify**

  ```bash
  rb
  ```

  Verify:
  - Yank a word, yank another word, paste with `p` — get the last yanked
  - Press `<C-p>` after pasting to cycle back to the previous yank
  - `<leader>fy` opens telescope with yank history
  - `<leader>fG` opens git files (was `<C-p>`)

- [ ] **Step 6: Commit**

  ```bash
  git add home/nixvim.nix
  git commit -m "feat: add yanky.nvim clipboard ring, remap telescope git_files to <leader>fG"
  ```

---

## Task 10: Add grug-far.nvim — Modern Find & Replace

Replaces spectre with grug-far for project-wide search and replace. The spec reviewer confirmed `pkgs.vimPlugins.grug-far-nvim` exists in nixpkgs.

**Files:**
- Modify: `home/nixvim.nix`

- [ ] **Step 1: Add the `grug-far` plugin block**

  Inside `plugins = {`:

  ```nix
  # ── Grug Far — project-wide find & replace ───────────────────────────
  # Panel-based search/replace with ripgrep. LazyVim's replacement for spectre.
  # <leader>sr = open; <leader>sw = search word under cursor.
  grug-far = {
    enable = true;
    settings = {
      headerMaxWidth    = 80;
      keymaps.replace   = "<C-enter>";
    };
  };
  ```

  > **If the build fails** with "undefined attribute 'grug-far'", the NixVim module may not exist yet. Use extraPlugins instead:
  > ```nix
  > extraPlugins = with pkgs.vimPlugins; [ grug-far-nvim ];
  > ```
  > And in `extraConfigLua`:
  > ```lua
  > require('grug-far').setup({ headerMaxWidth = 80 })
  > ```

- [ ] **Step 2: Add grug-far keymaps**

  In `keymaps = [`, add:

  ```nix
  # ── Grug Far — find & replace ─────────────────────────────────────────
  { mode = "n"; key = "<leader>sr"; action = "<cmd>GrugFar<cr>"; options.desc = "Find & Replace (grug-far)"; }
  { mode = "n"; key = "<leader>sw"; action.__raw = "function() require('grug-far').open({ prefills = { search = vim.fn.expand('<cword>') } }) end"; options.desc = "Search word (grug-far)"; }
  { mode = "v"; key = "<leader>sw"; action.__raw = "function() require('grug-far').with_visual_selection() end"; options.desc = "Search selection (grug-far)"; }
  ```

  No which-key group change needed — grug-far bindings live under the existing `<leader>s` "Search" group. The `<leader>S` Spectre group was already removed in Task 2.

- [ ] **Step 3: Build and verify**

  ```bash
  rb
  ```

  Verify:
  - `<leader>sr` opens the grug-far panel
  - Type a search term and replacement, press `<C-enter>` to apply
  - `<leader>sw` with cursor on a word pre-fills the search
  - `:checkhealth grug-far` shows no errors (if checkhealth module exists)

- [ ] **Step 4: Commit**

  ```bash
  git add home/nixvim.nix
  git commit -m "feat: add grug-far.nvim as modern find & replace"
  ```

---

## Task 11: Expand LSP and Formatters

Add 4 new LSP servers (clangd, bashls, marksman, taplo) and 2 new formatters (shfmt, clang-format). All LSP binaries are auto-provided by NixVim; only shfmt and clang-tools need `extraPackages` entries.

**Files:**
- Modify: `home/nixvim.nix`

- [ ] **Step 1: Add new LSP servers to `lsp.servers`**

  Inside `plugins.lsp.servers`, after the existing servers, add:

  ```nix
  # C / C++
  clangd.enable = true;
  # Bash / Shell scripts
  bashls.enable = true;
  # Markdown
  marksman.enable = true;
  # TOML (pyproject.toml, Cargo.toml, flake.nix schemas)
  taplo.enable = true;
  ```

  > **Note:** Do NOT add these to `extraPackages` — NixVim auto-provides the LSP server binaries when `enable = true`.

- [ ] **Step 2: Add shfmt and clang-tools to `extraPackages`**

  In `extraPackages = with pkgs; [...]`, add:

  ```nix
  shfmt        # shell formatter (used by conform)
  clang-tools  # provides clang-format (used by conform)
  ```

- [ ] **Step 3: Add new conform formatter entries**

  In `conform-nvim.settings.formatters_by_ft`, add:

  ```nix
  sh   = [ "shfmt" ];
  bash = [ "shfmt" ];
  c    = [ "clang_format" ];
  cpp  = [ "clang_format" ];
  ```

  > **Note:** conform uses `clang_format` (underscore), not `clang-format` (hyphen).

- [ ] **Step 4: Build and verify**

  ```bash
  rb
  ```

  Verify:
  - Open a `.sh` file: bashls diagnostics appear, `<leader>cf` formats with shfmt
  - Open a `.c` file: clangd diagnostics appear, `<leader>cf` formats with clang-format
  - Open a `pyproject.toml`: taplo provides completions and diagnostics
  - Open a `.md` file: marksman activates (`:LspInfo` shows marksman)

- [ ] **Step 5: Commit**

  ```bash
  git add home/nixvim.nix
  git commit -m "feat: add clangd, bashls, marksman, taplo LSP + shfmt/clang-format"
  ```

---

## Task 12: Python LSP Quality Improvements

Disable noisy ruff hover (basedpyright handles it better), add basedpyright diagnostic overrides for false-positive-heavy rules, and add missing DAP keymaps.

**Files:**
- Modify: `home/nixvim.nix`

- [ ] **Step 1: Add basedpyright `diagnosticSeverityOverrides`**

  In `lsp.servers.basedpyright.settings.basedpyright.analysis`, add after the existing keys:

  ```nix
  # Reduce false-positive noise on typical Python codebases.
  # numpy/pandas/etc lack type stubs → reportMissingTypeStubs is very noisy.
  # Dynamic Python patterns → reportUnknownMemberType / reportUnknownVariableType
  # generate more false positives than real issues in standard mode.
  diagnosticSeverityOverrides = {
    reportMissingTypeStubs    = "none";
    reportUnknownMemberType   = "none";
    reportUnknownVariableType = "none";
  };
  ```

  The full server block should look like:
  ```nix
  basedpyright = {
    enable = true;
    settings.basedpyright.analysis = {
      typeCheckingMode      = "standard";
      autoImportCompletions = true;
      diagnosticSeverityOverrides = {
        reportMissingTypeStubs    = "none";
        reportUnknownMemberType   = "none";
        reportUnknownVariableType = "none";
      };
    };
  };
  ```

- [ ] **Step 2: Disable ruff hover via `extraConfigLua`**

  In `programs.nixvim`, find or add the `extraConfigLua` attribute and append:

  ```nix
  extraConfigLua = ''
    -- Disable ruff hover: basedpyright provides better type/docstring hover.
    -- ruff hover only shows lint rule descriptions which is less useful.
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == "ruff" then
          client.server_capabilities.hoverProvider = false
        end
      end,
    })
  '';
  ```

  > **If `extraConfigLua` already exists**, append to it rather than creating a duplicate.

- [ ] **Step 3: Add missing DAP keymaps**

  In `keymaps = [`, add after the existing DAP keymaps:

  ```nix
  # ── DAP — additional keymaps ──────────────────────────────────────────
  { key = "<leader>dB"; action.__raw = "function() require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: ')) end"; options.desc = "Conditional breakpoint"; }
  { key = "<leader>dC"; action.__raw = "function() require('dap').run_to_cursor() end"; options.desc = "Run to cursor"; }
  { key = "<leader>dt"; action.__raw = "function() require('dap').terminate() end"; options.desc = "Terminate session"; }
  ```

- [ ] **Step 4: Build and verify**

  ```bash
  rb
  ```

  Open a Python file from a project that uses numpy or pandas. Verify:
  - No "reportMissingTypeStubs" warnings in the diagnostics (`<leader>xx`)
  - Press `K` on a function → see type/docstring from basedpyright (not ruff rule text)
  - Set a conditional breakpoint: `<leader>dB` → prompts for condition → breakpoint appears with condition shown
  - `<leader>dt` terminates an active debug session

- [ ] **Step 5: Commit**

  ```bash
  git add home/nixvim.nix
  git commit -m "feat: reduce Python LSP noise, disable ruff hover, add DAP keymaps"
  ```

---

## Task 13: Final Verification and PR

Rebuild from scratch, do a full feature smoke test, then open a PR.

**Files:** none (verification + git only)

- [ ] **Step 1: Full rebuild**

  ```bash
  rb
  ```

  Expected: clean build, no warnings about unknown options.

- [ ] **Step 2: Smoke test checklist**

  Open `nvim` with no args and verify each feature:

  | Feature | How to test |
  |---------|------------|
  | Dashboard | `nvim` → see ASCII header + 5 shortcuts |
  | Indent guides | Open any file → see animated `│` indent guides |
  | Word highlight | Open Python file → hover word → all occurrences highlight |
  | Notifications | Trigger an LSP action → see toast notification |
  | Floating terminal | `<C-\>` → terminal floats; `<C-\>` again → hides |
  | Git browse | In a git repo, `<leader>gB` → browser opens |
  | Lazygit | `<leader>gl` → lazygit float |
  | Code outline | Open Python file → `<leader>lo` → outline panel |
  | Symbol search | `<leader>ls` → Telescope aerial symbols |
  | Window nav | Two splits → `<C-h/j/k/l>` navigate |
  | Window resize | `<A-Left/Right/Up/Down>` resize |
  | Markdown render | Open `.md` → styled headers/code blocks |
  | Markdown toggle | `<leader>um` → toggles raw/rendered |
  | Test runner | Python file with `test_` fn → `<leader>tr` → runs |
  | Test summary | `<leader>ts` → sidebar |
  | Venv select | `<leader>cv` → venv picker |
  | Yanky | Yank two words → paste → `<C-p>` cycles |
  | Yank history | `<leader>fy` → Telescope yank list |
  | Find & replace | `<leader>sr` → grug-far panel |
  | Search word | Cursor on word → `<leader>sw` → pre-filled |
  | Shell LSP | Open `.sh` → diagnostics from bashls |
  | C LSP | Open `.c` → diagnostics from clangd |
  | TOML LSP | Open `pyproject.toml` → completions from taplo |
  | Python no noise | Open file with numpy → no typeStubs warnings |
  | Hover | `K` on Python fn → basedpyright docstring (not ruff rule) |
  | Cond breakpoint | `<leader>dB` → prompts for condition |
  | Telescope resume | `<leader>sR` → resumes last telescope search |
  | Which-key groups | `<leader>t` → "Test", `<leader>l` → "Language" |

- [ ] **Step 3: Open pull request**

  ```bash
  gh pr create \
    --title "feat: nixvim full modernization (snacks, aerial, neotest, Python quality)" \
    --body "$(cat <<'EOF'
  ## Summary
  - Replace dashboard-nvim/indent-blankline/illuminate/fugitive/spectre with snacks.nvim (−4 plugins)
  - Add: aerial (outline), smart-splits (tmux nav), render-markdown, neotest+pytest, venv-selector, yanky, grug-far
  - Expand LSP: clangd, bashls, marksman, taplo
  - Python: reduce basedpyright noise, disable ruff hover, add DAP keymaps (conditional breakpoint, run-to-cursor, terminate)
  - Fix: broken dashboard (center section), unreachable <leader>sr telescope resume keymap

  ## Test plan
  - [ ] All 25 smoke tests in Task 13 pass
  - [ ] `rb` builds clean with no warnings
  - [ ] Airgap-safe: all plugins from nixpkgs vimPlugins, no runtime downloads

  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  EOF
  )"
  ```

---

## Troubleshooting Reference

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Build fails: "undefined attribute 'X'" | NixVim has no module for plugin X | Use `extraPlugins = [ pkgs.vimPlugins.X-nvim ]` + `extraConfigLua` |
| Build fails: "unexpected argument 'adapters'" | neotest adapter syntax differs in your nixvim version | Check `nix repl` → `:doc programs.nixvim.plugins.neotest` |
| Dashboard shows blank | snacks.dashboard config issue | Temporarily set `dashboard.enabled = false`, rebuild, then fix |
| `<C-h>` in tmux doesn't navigate | tmux config not reloaded | Run `tmux source ~/.config/tmux/tmux.conf` or start a new tmux session |
| ruff hover still showing | LspAttach autocmd not firing | Add `vim.notify("ruff attached")` inside the callback to confirm it fires |
| neotest "no test found" | pytest not in PATH | Set `adapters.python.settings.python = ".venv/bin/python"` explicitly |
