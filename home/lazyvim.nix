# Declarative LazyVim via pfassina/lazyvim-nix — zero-config by design, so
# this stays tiny. Telescope, blink-cmp, gitsigns, which-key, session restore
# etc. are LazyVim defaults; don't re-add them here.
{ pkgs, lib, ... }:
let
  # Colorschemes Noctalia can select. tokyonight and catppuccin are omitted on
  # purpose — LazyVim's own plugins/colorscheme.lua already ships both.
  #
  # These are wired by absolute store path (`dir = ...`) instead of the usual
  # "owner/repo" spec. lazyvim-nix scans ~/.config/nvim/lua/plugins for quoted
  # "a/b" tokens (nix/lib/file-scanning.nix) and resolves them against
  # pkgs.vimPlugins by name pattern. "rose-pine/neovim" resolves to
  # vimPlugins.neovim and "Shatur/neovim-ayu" to vimPlugins.neovim_ayu —
  # neither exists, so it falls back to builtins.fetchGit, which hard-errors
  # under the flake's pure evaluation. A store path holds no bare "a/b" token,
  # so nothing is resolved and lazy.nvim loads each plugin from the store.
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
    extraPackages = [
      pkgs.nixd
      pkgs.nixfmt
      pkgs.statix
    ];

    # Noctalia picks the colorscheme *plugin*, not the colours. Its
    # colors_changed/theme_mode_changed/started hooks (home/noctalia.nix) run a
    # script that writes the file read below. Every scheme is then the real,
    # hand-tuned plugin by its own author rather than a matugen palette forced
    # into base16's sixteen semantic slots — that mapping put green in base09
    # (constants/orange) and blue in base0B (strings/green), which is why it
    # never looked right.
    #
    # No live reload on purpose: ghostty needs a restart on palette change too,
    # so nvim just reads this at startup. That drops the SIGUSR1 handler the
    # old community "neovim" template needed (and never actually had wired up).
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
