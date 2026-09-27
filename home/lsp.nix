# Declared once, routed onto each editor's PATH: zed via extraPackages
# (home/zed.nix), opencode via its wrapped PATH (home/programs.nix). Add a
# server here and every consumer sees it. Prefer these builds over letting an
# editor download its own.
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
