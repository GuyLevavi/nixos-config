# NixVim Modernization Design
**Date:** 2026-03-23
**Branch:** feature/nixvim-modernization
**File:** `home/nixvim.nix`

---

## Overview

A full modernization of the NixVim configuration in a separate branch. Goals:
1. Fix two known bugs (broken dashboard, unreachable keymap)
2. Consolidate UI plugins under `snacks.nvim` (fewer plugins, same features)
3. Add high-ROI capabilities: code outline, tmux-aware splits, markdown rendering, Python testing, venv switching, clipboard ring, modern find/replace
4. Expand LSP coverage for C/C++, Bash, Markdown, TOML while improving Python LSP quality (noise reduction)

---

## Section 1: Removals

| Plugin | Reason |
|--------|--------|
| `dashboard-nvim` | Replaced by `snacks.dashboard` (LazyVim's current default, properly themed) |
| `indent-blankline` | Replaced by `snacks.indent` (identical feature + animation support) |
| `illuminate` | Replaced by `snacks.words` (identical LSP-aware word highlighting) |
| `fugitive` | Dropped — neogit + diffview + gitsigns cover all use cases; fugitive is a vim-era holdover |
| `spectre` | Replaced by `grug-far.nvim` if packaged in nixpkgs; otherwise kept with fixed keymap |

Net: −4 (or −5) plugins, 0 features lost.

---

## Section 2: Bug Fixes

### 2a. Dashboard "please configure your own center"
The dashboard-nvim "doom" theme expects a `center` array, not a `shortcut` array. The existing config used `shortcut`, which dashboard-nvim ignores and replaces with the "please configure" placeholder. This is fully resolved by migrating to `snacks.dashboard`, which has sensible defaults and doesn't require a `center` section.

### 2b. `<leader>sr` keymap conflict
Currently bound to both Telescope resume (line 467 in nixvim.nix) and Spectre open (line 519). Spectre wins; Telescope resume is unreachable.

**Resolution:** Reassign Telescope resume to `<leader>sR`. The `<leader>sr` binding goes to grug-far (or stays with spectre if grug-far is unavailable).

---

## Section 3: Snacks.nvim Integration

Enable `plugins.snacks` with the following sub-modules. All other snacks modules (`picker`, `bufdelete`, `scroll`, etc.) remain disabled to avoid conflicts.

| Module | Replaces | Description |
|--------|----------|-------------|
| `dashboard` | dashboard-nvim | Welcome screen with LazyVim-style layout |
| `indent` | indent-blankline | Animated indent guides with scope highlighting |
| `words` | illuminate | LSP-aware word highlighting under cursor (delay: 200ms) |
| `notifier` | — (new) | Toast notifications; noice still handles LSP/command-line messages |
| `terminal` | — (new) | Floating terminal toggle: `<C-\>` |
| `gitbrowse` | — (new) | `<leader>gB` opens current file in GitHub/GitLab in browser |
| `lazygit` | — (new) | Opens lazygit in a snacks floating window: `<leader>gl` |

The existing `neogit`, `diffview`, and `gitsigns` plugins are kept.

---

## Section 4: New Plugins

### 4a. aerial.nvim — Code Outline
Shows a right-side panel with file symbols (functions, classes, methods) sourced from LSP + treesitter. Essential for navigating large Python files.

- **Keymap:** `<leader>lo` to toggle outline panel
- **which-key group:** Add `<leader>l` → "LSP/Language"
- **Backends:** `[ "lsp" "treesitter" ]`
- **Integration:** telescope extension for symbol search

### 4b. smart-splits.nvim — Tmux-aware Window Navigation
Replaces the manual `<C-hjkl>` window navigation keymaps. Same keys now seamlessly cross Neovim splits AND tmux panes without any modifier.

- **Navigate:** `<C-h/j/k/l>` (replaces existing `<C-hjkl>` keymaps)
- **Resize:** `<A-Left/Right/Up/Down>` (arrow keys, replaces existing `<C-arrow>` keymaps)
- **Note:** `<A-j>/<A-k>` move-line bindings are preserved — using arrow keys for resize avoids this conflict entirely
- **Note:** The existing `<C-hjkl>` and `<C-arrow>` keymaps in nixvim.nix must be removed (smart-splits registers them via its own setup)
- **Tmux requirement:** smart-splits.nvim's tmux plugin config must be added to tmux extraConfig in `home/base.nix`

### 4c. render-markdown.nvim — Inline Markdown Rendering
Renders markdown headers, bold/italic, tables, and code blocks with proper icons and colors *inside the buffer* (not a preview pane). Works with treesitter.

- **Auto-enabled** on `markdown` filetype
- **Toggle keymap:** `<leader>um` (under UI toggles group)
- **Works with:** blink-cmp (markdown in completion docs is also rendered)

### 4d. neotest + neotest-python — Test Runner
Run pytest tests from the editor. Results appear in a sidebar. Integrates with DAP for debugging tests.

- **Adapter:** `neotest-python` with pytest
- **Keymaps:**
  - `<leader>tr` — run nearest test
  - `<leader>tT` — run current file
  - `<leader>ts` — toggle test summary sidebar
  - `<leader>to` — show test output
  - `<leader>tS` — stop test run
- **which-key group:** Add `<leader>t` → "Test"
- **DAP integration:** `<leader>td` — debug nearest test (uses existing debugpy)

### 4e. venv-selector.nvim — Python Virtualenv Switcher
Searches for virtualenvs (`.venv`, `venv`, `~/.virtualenvs`, etc.) and switches the active venv. Automatically updates basedpyright and ruff LSP paths. Integrates with dap-python.

- **Keymap:** `<leader>cv` — open venv selector (under existing `<leader>c` "Code" group — intentional, consistent with LSP code actions)
- **Auto-detection:** reads `.venv` in project root on startup
- **Note:** NOT placed under `<leader>l` — see Section 7 which-key groups

### 4f. yanky.nvim — Clipboard Ring
Replaces built-in `p`/`P` paste with a cyclic paste that lets you walk back through yank history. Integrates with telescope for visual browsing.

- **Keymaps:** `p`/`P` (enhanced paste), `<C-p>`/`<C-n>` in paste-cycle mode to walk the ring
- **`<C-p>` note:** yanky's `<C-p>` only fires in paste-cycle context (after pressing `p`), not in normal mode — no conflict with telescope. However, the existing telescope `<C-p>` → `git_files` keymap should be remapped to `<leader>fG` for clarity.
- **Browse:** `<leader>fy` → telescope yanky history
- **Storage:** shada (persists across sessions), 100 entries

### 4g. grug-far.nvim — Modern Find & Replace
Replaces spectre. Panel-based project-wide search and replace with ripgrep. LazyVim migrated from spectre to grug-far.

- **Availability:** implement if `pkgs.vimPlugins.grug-far-nvim` exists in nixpkgs; otherwise keep spectre with fixed keymap
- **Keymaps:** `<leader>sr` (open), `<leader>sw` (search word under cursor)

---

## Section 5: LSP Expansion

### New servers

| Server | Language | Notes |
|--------|----------|-------|
| `clangd` | C / C++ | Completions, diagnostics, format via clang-format |
| `bashls` | Bash / Shell | nixvim auto-provides the binary — no extraPackages entry needed |
| `marksman` | Markdown | Go-to-definition between `.md` files, wiki-links; nixvim auto-provides |
| `taplo` | TOML | pyproject.toml, Cargo.toml, flake schemas; nixvim auto-provides |

### New formatters (extraPackages + conform)

| Package | Filetype |
|---------|----------|
| `shfmt` | sh, bash |
| `clang-format` (from `clang-tools`) | c, cpp |

Add to `conform.settings.formatters_by_ft`:
```
sh   = [ "shfmt" ]
bash = [ "shfmt" ]
c    = [ "clang_format" ]
cpp  = [ "clang_format" ]
```

---

## Section 6: Python LSP Quality Improvements

### 6a. Disable ruff hover
Basedpyright provides much better hover documentation (type info, docstrings). Ruff's hover only shows lint rule descriptions, which clutters `K`. Disable via `extraConfigLua`:

```lua
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == "ruff" then
      client.server_capabilities.hoverProvider = false
    end
  end,
})
```

### 6b. basedpyright noise reduction
Keep `typeCheckingMode = "standard"` but suppress the rules that generate the most false positives on typical Python codebases (especially data science libraries without type stubs):

```nix
diagnosticSeverityOverrides = {
  reportMissingTypeStubs    = "none";  # numpy, pandas, etc. lack stubs
  reportUnknownMemberType   = "none";  # too noisy in dynamic Python
  reportUnknownVariableType = "none";  # same
};
```

### 6c. Additional DAP keymaps
The existing DAP keymaps are missing: conditional breakpoint, run-to-cursor, and terminate session.

| Keymap | Action |
|--------|--------|
| `<leader>dB` | Conditional breakpoint (prompt for condition) |
| `<leader>dC` | Run to cursor |
| `<leader>dt` | Terminate debug session |

---

## Section 7: Keymap Cleanups

| Old binding | Issue | Fix |
|-------------|-------|-----|
| `<leader>sr` | Conflict: Telescope resume vs Spectre | Telescope resume → `<leader>sR` |
| `<C-hjkl>` | Manual, not tmux-aware | Removed; smart-splits registers these |
| `<C-arrow>` | Manual resize | Removed; smart-splits uses `<A-Left/Right/Up/Down>` instead |

### New which-key groups
Add to `which-key.settings.spec`:
- `<leader>t` → "Test" (neotest)
- `<leader>l` → "Language" (aerial symbol outline only — `<leader>lo`)
- Remove orphaned `<leader>S` → "Spectre" entry (spectre is removed)

Note: venv-selector stays under `<leader>c` (Code group), NOT under `<leader>l`.

---

## Implementation Notes

- **Branch:** create `feature/nixvim-modernization` from `master`
- **File:** all changes in `home/nixvim.nix`; tmux extraConfig changes in `home/base.nix`
- **Testing:** `rb` (nixos-rebuild switch) after each logical group of changes
- **Airgap:** all new plugins confirmed present in nixpkgs `vimPlugins` (reviewed by spec-reviewer)
- **grug-far availability:** reviewer confirmed `pkgs.vimPlugins.grug-far-nvim` exists; include it
- **smart-splits tmux:** add smart-splits tmux plugin keybinding config to `home/base.nix` tmux extraConfig

### Catppuccin integrations block update
In `colorschemes.catppuccin.settings.integrations`:
- Remove `indent_blankline.enabled = true` (plugin removed)
- Add `snacks.enabled = true` (catppuccin-nvim supports snacks integration)

### Snacks module enable flags (exact Nix syntax)
```nix
plugins.snacks = {
  enable = true;
  settings = {
    dashboard.enabled  = true;
    indent.enabled     = true;
    words.enabled      = true;
    notifier.enabled   = true;
    terminal.enabled   = true;
    gitbrowse.enabled  = true;
    lazygit.enabled    = true;
    # Explicitly disable to avoid conflicts:
    picker.enabled     = false;
    bufdelete.enabled  = false;
    scroll.enabled     = false;
    animate.enabled    = false;
  };
};
```

---

## Summary of Changes

| Category | Count | Details |
|----------|-------|---------|
| Plugins removed | 4–5 | dashboard-nvim, indent-blankline, illuminate, fugitive, (spectre) |
| Plugins added | 7–8 | snacks, aerial, smart-splits, render-markdown, neotest, venv-selector, yanky, (grug-far) |
| LSP servers added | 4 | clangd, bashls, marksman, taplo |
| Formatters added | 2 | shfmt, clang-format |
| Bug fixes | 2 | dashboard center, <leader>sr conflict |
| Python improvements | 3 | ruff hover disable, pyright noise reduction, DAP keymaps |
