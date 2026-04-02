# Zed Editor — NixOS Config Design

Date: 2026-04-01

## Summary

Add Zed editor to `home/gui.nix` using the `programs.zed-editor` home-manager module with `catppuccin.zed.enable` for automatic theming. No vim mode. LSP tools injected via `extraPackages`. All AI/telemetry disabled.

## Approach

Option A: `programs.zed-editor` module + `catppuccin.zed.enable`. Follows the same pattern as kitty, waybar, rofi in this config. Catppuccin module fires when `programs.zed-editor.enable = true`, injecting Mocha/Mauve theme and catppuccin-icons extension automatically.

## File Changed

`home/gui.nix` — add alongside existing GUI program blocks.

## Design

### Module + Theming

```nix
catppuccin.zed.enable = true;
catppuccin.zed.icons.enable = true;

programs.zed-editor = {
  enable = true;
  mutableUserSettings = true;
  ...
};
```

- `catppuccin.zed` injects `theme.dark/light = "Catppuccin Mocha"` (mauve accent produces no suffix per module logic), writes theme JSON, adds `catppuccin-icons` extension slug
- `mutableUserSettings = true`: activation-time merge (`$dynamic * $static`), Nix wins on conflict, changes from Zed UI persist until next `rb`

### extraPackages (PATH-wrapped into `zeditor` binary)

- `basedpyright` — Python LSP
- `ruff` — Python linter/formatter
- `nixd` — Nix LSP (flake-aware)
- `nixpkgs-fmt` — Nix formatter
- `bash-language-server`
- `yaml-language-server`
- `taplo` — TOML LSP + formatter
- `nodePackages.prettier` — YAML/JSON/Markdown formatter (matches `nixvim.nix` pattern)

All already present in `nixvim.extraPackages`; this is a second reference to same store paths.

### userSettings

- `vim_mode = false`
- Fonts: `JetBrainsMono Nerd Font` at size 14 (matches Kitty)
- Terminal shell: `nu` explicitly
- Telemetry: `metrics = false`, `diagnostics = false`
- AI: `features.edit_prediction_provider = "none"`
- `format_on_save = "on"`, `autosave = { after_delay.milliseconds = 1000; }` (Zed JSON: `{"after_delay": {"milliseconds": 1000}}`)
- `catppuccin.zed.italics` defaults to `true` — intentionally left at default (italicized mocha variant)
- Python: `languages."Python".language_servers = ["basedpyright" "!pyright" "ruff"]` (capital-P key required), formatter = ruff
- No ruff hover override needed — Zed uses the first server in `language_servers` for hover; basedpyright is first, so ruff hover is naturally suppressed

### Extensions

Declared in `programs.zed-editor.extensions`:
- `"nix"`, `"toml"`, `"dockerfile"`, `"env"`, `"basedpyright"`

Auto-added by catppuccin module (not listed here):
- `"catppuccin"`, `"catppuccin-icons"`

Note: YAML built-in to Zed, no extension needed.

## Constraints

- Extensions still download on first launch (Zed extension API requires network; no airgap override)
- `basedpyright` extension required so Zed recognises the adapter name in `language_servers`
- `catppuccin.zed` only fires when `programs.zed-editor.enable = true` (standard catppuccin-nix pattern)
