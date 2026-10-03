# Declared once, routed onto each editor's PATH: zed and neovim via
# extraPackages (home/zed.nix, home/neovim.nix), opencode via its wrapped PATH
# (home/programs.nix). Appended, so a project dev shell's own copies (prepended
# by direnv) win and pin LSP+runtime together; these global builds are the
# fallback for launches with no dev shell (e.g. the $mod,Z bind). Prefer these
# over letting an editor download its own.
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
