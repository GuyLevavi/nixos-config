{ pkgs, ... }:
let
  # Same server list zed and opencode get (home/lsp.nix); put the binaries on
  # nvim's PATH so vim.lsp.enable finds them by name.
  lspPackages = import ./lsp.nix { inherit pkgs; };
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = false; # zed stays the default editor
    viAlias = true;
    vimAlias = true;
    # The repo owns ~/.config/nvim (home/default.nix); provider env goes into
    # wrapper args instead of a generated init.lua.
    sideloadInitLua = true;
    extraPackages = lspPackages ++ [
      pkgs.gcc # treesitter parser builds
      pkgs.gnumake # telescope-fzf-native / LuaSnip jsregexp
      pkgs.tree-sitter # nvim-treesitter shells out to the CLI
    ];
  };
}
