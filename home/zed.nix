{ pkgs, ... }:
let
  # One declaration for every editor — see home/lsp.nix.
  lspPackages = import ./lsp.nix { inherit pkgs; };
in
{
  programs.zed-editor = {
    enable = true;
    mutableUserSettings = true;
    defaultEditor = true; # EDITOR/VISUAL = zeditor -w
    extraPackages = lspPackages;
    extensions = [
      "nix"
      "toml"
      "dockerfile"
      "env"
      "basedpyright"
      "markdown-oxide"
      # Palette-sync map targets (home/noctalia.nix); gruvbox/ayu ship with zed.
      "tokyo-night"
      "catppuccin"
      "kanagawa-themes"
      "rose-pine-theme"
      "nord"
      "dracula"
      "eldritch-theme"
    ];
    userSettings = {
      base_keymap = "VSCode";
      vim_mode = true;
      buffer_font_family = "JetBrainsMono Nerd Font";
      buffer_font_size = 16;
      ui_font_size = 18;
      telemetry = {
        metrics = false;
        diagnostics = false;
      };
      # AI autocomplete off; "none" also hides the status-bar Z icon.
      edit_predictions.provider = "none";
      autosave = "on_focus_change";
      format_on_save = "on";
      # Seed only — the hook in home/noctalia.nix rewrites this block.
      theme = {
        mode = "system";
        dark = "Catppuccin Mocha";
        light = "Catppuccin Latte";
      };
      # Everything docks right; panels are keyboard toggles, so the
      # status-bar buttons stay hidden.
      project_panel = {
        dock = "right";
        button = false;
      };
      git_panel = {
        dock = "right";
        button = false;
      };
      outline_panel = {
        dock = "right";
        button = false;
      };
      collaboration_panel = {
        dock = "right";
        button = false;
      };
      agent = {
        dock = "right"; # upstream default is left
        button = false;
        sidebar_side = "right"; # the panel's threads sidebar
        # Auto-approve agent tool calls; font matches buffer_font_size.
        tool_permissions.default = "allow";
        agent_buffer_font_size = 16;
      };
      # Hold a combo briefly to see available follow-up keys.
      which_key = {
        enabled = true;
        delay_ms = 500;
      };
      tab_bar = {
        show_nav_history_buttons = false;
        show_tab_bar_buttons = false;
      };
      languages = {
        # Registry declares nil; use nixd (ships via extraPackages).
        Nix = {
          language_servers = [ "nixd" "!nil" ];
        };
        Python = {
          language_servers = [
            "basedpyright"
            "!pyright"
            "ruff"
          ];
          formatter.language_server.name = "ruff";
        };
        Markdown.soft_wrap = "editor_width"; # prose wraps, code doesn't
      };
    };
    userKeymaps = [
      {
        context = "Workspace";
        bindings = {
          # Toggle the whole right dock — panel ToggleFocus only moves focus.
          "ctrl-b" = "workspace::ToggleRightDock";
          # Extra agent toggle next to the stock ctrl-? / ctrl-alt-i.
          "ctrl-alt-m" = "agent::ToggleFocus";
        };
      }
    ];
  };
}
