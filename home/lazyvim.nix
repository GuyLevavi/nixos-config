# Declarative LazyVim via pfassina/lazyvim-nix — zero-config by design, so
# this stays tiny. Telescope, blink-cmp, gitsigns, which-key, session restore
# etc. are LazyVim defaults; don't re-add them here.
{ pkgs, lib, ... }:
let
  # tokyonight and catppuccin are omitted: LazyVim already ships both.
  #
  # Wired by store path, NOT "owner/repo". lazyvim-nix scans the plugins dir
  # for quoted "a/b" tokens and resolves them against pkgs.vimPlugins by name;
  # "rose-pine/neovim" and "Shatur/neovim-ayu" resolve to attrs that don't
  # exist and fall through to builtins.fetchGit, which fails under pure eval.
  # The scan reads the *previous* generation, so that breaks one rebuild late.
  colorschemes = {
    gruvbox = pkgs.vimPlugins.gruvbox-nvim;
    kanagawa = pkgs.vimPlugins.kanagawa-nvim;
    rose-pine = pkgs.vimPlugins.rose-pine;
    ayu = pkgs.vimPlugins.neovim-ayu;
    nord = pkgs.vimPlugins.nord-nvim;
    dracula = pkgs.vimPlugins.dracula-nvim;
    eldritch = pkgs.vimPlugins.eldritch-nvim;
  };

  colorschemeSpecs = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: drv: "  { dir = \"${drv}\", name = \"${name}\", lazy = true },"
    ) colorschemes
  );
in
{
  programs.lazyvim = {
    enable = true;

    extras = {
      # render-markdown.nvim (in-buffer tables/headings/code blocks, `<leader>um`
      # toggles it), marksman, markdown-preview. installDependencies pulls
      # markdownlint-cli2 + markdown-toc, the runtime ones pull node — which
      # markdown-preview's server also needs.
      lang.markdown = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = true;
      };
      lang.nix.enable = true;
      lang.python = {
        enable = true;
        installDependencies = true;
        installRuntimeDependencies = true;
      };
    };

    # lang.nix ships no auto-installed deps (unlike python/go) — nixd is
    # manual, and so are the formatter/linter its extras/lang/nix.lua expects
    # on PATH (nixfmt, statix) — LazyVim's default nil_ls LSP is swapped for
    # nixd here, but the formatter/linter aren't swappable, just missing deps.
    #
    # lang.markdown's LSP (marksman: link/heading completion, workspace
    # symbols, rename across notes) is a manual dep the same way.
    extraPackages = [
      pkgs.nixd
      pkgs.nixfmt
      pkgs.statix
      pkgs.marksman
    ];

    # Noctalia picks the colorscheme *plugin*, not the colours: its hooks
    # (home/noctalia.nix) write the file read below. No live reload — like
    # ghostty, nvim picks it up on restart.
    plugins.colorscheme = ''
      return {
      ${colorschemeSpecs}
        {
          "LazyVim/LazyVim",
          opts = {
            colorscheme = function()
              local state = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
              -- absent until Noctalia has run its hook at least once, and
              -- always absent on a TTY or over ssh
              local ok, theme = pcall(dofile, state .. "/noctalia/nvim-theme.lua")
              if not (ok and type(theme) == "table" and theme.colorscheme) then
                theme = { colorscheme = "tokyonight-night", background = "dark" }
              end
              -- gruvbox.nvim is one colorscheme switching on this; the others
              -- set it themselves, so writing it first is harmless
              vim.o.background = theme.background or "dark"
              if not pcall(vim.cmd.colorscheme, theme.colorscheme) then
                vim.cmd.colorscheme("tokyonight-night")
              end
            end,
          },
        },
      }
    '';

    # Two fixes to what lang.markdown ships. Both specs name the plugin *without*
    # the owner prefix: the user-plugin scan only picks up quoted "owner/repo"
    # tokens, and lazy.nvim merges a bare name into the spec the extra already
    # declared — so this overrides rather than declaring a second copy.
    plugins.markdown = ''
      return {
        {
          -- LazyVim turns off the glyph-dependent parts of the renderer; the
          -- terminal font has them, so turn checkboxes back on and round the
          -- table borders. Everything else is render-markdown's default.
          "render-markdown.nvim",
          opts = {
            checkbox = { enabled = true },
            pipe_table = { preset = "round" },
          },
        },
        {
          -- The from-source build has no app/node_modules, and LazyVim's build
          -- step (mkdp#util#install) would try to write them into the read-only
          -- store. The nixpkgs copy ships them prebuilt, and mkdp falls back to
          -- running that server under `node` when there's no pre-built binary.
          "markdown-preview.nvim",
          dir = "${pkgs.vimPlugins.markdown-preview-nvim}",
          build = false,
        },
      }
    '';

    # Debounced write-on-idle; :ASToggle to pause it for a buffer session.
    plugins.autosave = ''
      return {
        "okuuva/auto-save.nvim",
        cmd = "ASToggle",
        event = { "InsertLeave", "TextChanged" },
        opts = {},
      }
    '';
  };

  home.sessionVariables.EDITOR = "nvim";
}
