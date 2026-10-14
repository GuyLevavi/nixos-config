{ lib, pkgs, ... }:
let
  # Same server list zed and opencode get (home/lsp.nix). Appended to PATH by
  # the wrapper, so a project dev shell's own servers (zls, rust-analyzer) win.
  lspPackages = import ./lsp.nix { inherit pkgs; };

  extras = [
    "lang.nix"
    "lang.python"
    "lang.rust"
    "lang.zig"
    "lang.yaml"
    "lang.toml"
    "lang.clangd"
  ];

  # LazyVim core + the extras above. A plugin missing here shows as "not
  # installed" in :Lazy (nothing is ever cloned); add its nixpkgs attr.
  plugins = with pkgs.vimPlugins; [
    LazyVim
    blink-cmp
    bufferline-nvim
    conform-nvim
    flash-nvim
    friendly-snippets
    gitsigns-nvim
    grug-far-nvim
    lazydev-nvim
    lualine-nvim
    mini-ai
    mini-icons
    mini-pairs
    noice-nvim
    nui-nvim
    nvim-lint
    nvim-lspconfig
    nvim-treesitter
    nvim-treesitter-textobjects
    nvim-ts-autotag
    persistence-nvim
    plenary-nvim
    snacks-nvim
    todo-comments-nvim
    tokyonight-nvim
    trouble-nvim
    ts-comments-nvim
    which-key-nvim
    # extras
    SchemaStore-nvim
    clangd_extensions-nvim
    crates-nvim
    rustaceanvim
    venv-selector-nvim
  ];

  # Not in any LazyVim spec: one per Noctalia builtin, picked by
  # noctalia-theme-sync (home/noctalia.nix) through ~/.local/state/nvim/theme.lua.
  themes = with pkgs.vimPlugins; [
    dracula-nvim
    eldritch-nvim
    gruvbox-nvim
    kanagawa-nvim
    neovim-ayu
    nord-nvim
    rose-pine
  ];

  # lazy.nvim resolves dev plugins as <path>/<name>; nixpkgs' pname is that
  # name, except catppuccin, which LazyVim's spec renames.
  devRoot = pkgs.linkFarm "lazyvim-plugins" (
    map (p: {
      name = p.pname;
      path = p;
    }) plugins
    ++ [
      {
        name = "catppuccin";
        path = pkgs.vimPlugins.catppuccin-nvim;
      }
    ]
  );

  # Every grammar, so LazyVim never tries to compile one; site/ survives
  # lazy.nvim's runtimepath reset.
  grammars = pkgs.symlinkJoin {
    name = "nvim-treesitter-grammars";
    paths = pkgs.vimPlugins.nvim-treesitter.withAllGrammars.dependencies;
  };
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = false; # zed stays the default editor
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;
    # nvim/ (the repo, symlinked live) holds only LazyVim's lua/config and
    # lua/plugins; this bootstrap is loaded through wrapper args instead.
    sideloadInitLua = true;
    initLua = ''
      -- LazyVim's runtime state; its default (stdpath config) is the repo.
      vim.g.lazyvim_json = vim.fn.stdpath("state") .. "/lazyvim.json"
      vim.opt.rtp:prepend("${pkgs.vimPlugins.lazy-nvim}")
      require("lazy").setup({
        spec = {
          { "LazyVim/LazyVim", import = "lazyvim.plugins" },
          ${lib.concatMapStrings (e: ''{ import = "lazyvim.plugins.extras.${e}" },'') extras}
          { "mason-org/mason.nvim", enabled = false },
          { "mason-org/mason-lspconfig.nvim", enabled = false },
          ${lib.concatMapStrings (p: ''{ dir = "${p}", name = "${p.pname}", lazy = true },'') themes}
          { import = "plugins" },
        },
        dev = { path = "${devRoot}", patterns = { "" }, fallback = false },
        install = { missing = false },
        checker = { enabled = false },
        change_detection = { enabled = false },
        rocks = { enabled = false },
        lockfile = vim.fn.stdpath("state") .. "/lazy-lock.json",
      })
    '';
    extraPackages = lspPackages ++ [
      # tools LazyVim core and lang.nix call by name
      pkgs.lua-language-server
      pkgs.stylua
      pkgs.shfmt
      pkgs.nixfmt
      pkgs.statix
    ];
  };

  xdg.dataFile = {
    "nvim/site/parser".source = "${grammars}/parser";
    "nvim/site/queries".source = "${grammars}/queries";
  };
}
