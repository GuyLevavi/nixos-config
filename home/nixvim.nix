# Minimal by design — not an IDE (that's home/zed.nix). Extend, don't rewrite.
{ pkgs, ... }:
{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    nixpkgs.pkgs = pkgs; # reuse the system nixpkgs, don't evaluate a second

    colorschemes.catppuccin = {
      enable = true;
      settings.flavour = "mocha";
    };

    globals.mapleader = " ";
    opts = {
      number = true;
      relativenumber = true;
      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
      smartindent = true;
      ignorecase = true;
      smartcase = true;
      signcolumn = "yes";
      termguicolors = true;
      clipboard = "unnamedplus";
      scrolloff = 8;
      splitright = true;
      splitbelow = true;
    };

    plugins = {
      treesitter = {
        enable = true;
        settings = {
          highlight.enable = true;
          indent.enable = true;
        };
      };

      lsp = {
        enable = true;
        servers = {
          nixd.enable = true;
          basedpyright.enable = true;
          bashls.enable = true;
          lua_ls.enable = true;
        };
      };
      lsp-format.enable = true;

      telescope = {
        enable = true;
        extensions.fzf-native.enable = true;
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fg" = "live_grep";
          "<leader>fb" = "buffers";
          "<leader>fh" = "help_tags";
        };
      };

      blink-cmp = {
        enable = true;
        settings.keymap.preset = "default";
      };

      gitsigns.enable = true;
      lualine.enable = true;
      comment.enable = true;
      which-key.enable = true;
      persistence.enable = true; # per-directory session restore
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>e";
        action = ":Ex<CR>";
        options.desc = "Open netrw file explorer";
      }
      {
        mode = "n";
        key = "<leader>w";
        action = ":w<CR>";
        options.desc = "Save";
      }
    ];
  };
}
