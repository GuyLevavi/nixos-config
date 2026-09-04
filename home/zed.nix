{ pkgs, ... }:
{
  programs.zed-editor = {
    enable = true;
    mutableUserSettings = true;
    extraPackages = with pkgs; [
      basedpyright
      ruff
      nixd
      nixpkgs-fmt
      bash-language-server
      yaml-language-server
      taplo
    ];
    extensions = [
      "nix"
      "toml"
      "dockerfile"
      "env"
      "basedpyright"
      "catppuccin"
    ];
    userSettings = {
      base_keymap = "VSCode";
      vim_mode = false;
      buffer_font_family = "JetBrainsMono Nerd Font";
      buffer_font_size = 14;
      telemetry = {
        metrics = false;
        diagnostics = false;
      };
      format_on_save = "on";
      theme = {
        mode = "dark";
        light = "Catppuccin Mocha";
        dark = "Catppuccin Mocha";
      };
      languages.Python = {
        language_servers = [
          "basedpyright"
          "!pyright"
          "ruff"
        ];
        formatter.language_server.name = "ruff";
      };
    };
  };
}
