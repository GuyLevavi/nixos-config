# Shared language servers, declared once and routed onto each editor's PATH:
#   zed      -> programs.zed-editor.extraPackages   (home/zed.nix)
#   opencode -> wrapped PATH                        (home/programs.nix)
#   nvim     -> programs.neovim.extraPackages, when it comes back
# Add a server here and every consumer sees it; each editor config only has to
# name the binary. The editor configs live in their own trees (zed userSettings,
# ~/.config/opencode/opencode.jsonc) because each speaks a different dialect.
#
# Why we prefer the nix builds over letting each editor download its own:
#   clang-tools            clangd = C/C++ LSP + formatter
#   package-version-server zed's prebuilt binary can't run on NixOS
#   markdown-oxide         Obsidian-style markdown LSP for ~/GoogleDrive/Obsidian
# nixpkgs-fmt is not an LSP — it rides along because zed formats Nix with it.
{ pkgs }:
with pkgs;
[
  basedpyright # Python types (pyright fork)
  ruff # Python lint + format server
  nixd # Nix
  nixpkgs-fmt # Nix formatter (zed)
  bash-language-server
  yaml-language-server
  taplo # TOML
  clang-tools # clangd
  package-version-server # package.json version hover
  markdown-oxide # Obsidian markdown
]
