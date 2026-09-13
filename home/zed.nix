{ pkgs, ... }:
{
  programs.zed-editor = {
    enable = true;
    mutableUserSettings = true;
    # EDITOR/VISUAL = `zeditor -w`; zed is the default editor now
    defaultEditor = true;
    extraPackages = with pkgs; [
      basedpyright
      ruff
      nixd
      nixpkgs-fmt
      bash-language-server
      yaml-language-server
      taplo
      # C/C++ grammars are built into zed; clang-tools supplies clangd
      # (LSP + formatting) so zed doesn't download its own binary.
      clang-tools
      # Obsidian-style markdown LSP (wikilinks, backlinks, daily notes) for the
      # vault at ~/GoogleDrive/Obsidian. The extension resolves the binary from
      # PATH first, so this nix build is what actually runs.
      markdown-oxide
    ];
    extensions = [
      "nix"
      "toml"
      "dockerfile"
      "env"
      "basedpyright"
      "markdown-oxide"
      # Themes mapped from Noctalia's builtins by the sync hook in
      # home/noctalia.nix. Gruvbox/Ayu ship with zed, no extension needed.
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
      format_on_save = "on";
      # Seed only — the hooks in home/noctalia.nix rewrite this block on
      # palette/mode switch (settings.json is mutable; zed live-reloads it).
      theme = {
        mode = "system";
        dark = "Catppuccin Mocha";
        light = "Catppuccin Latte";
      };
      # Everything docks right, nothing on the left. Panels are keyboard
      # toggles (ctrl-shift-e/g/b, ctrl-b toggles the whole dock, agent is
      # ctrl-? / ctrl-alt-i / ctrl-alt-m), so the status-bar buttons stay hidden.
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
        # Auto-approve tool calls (incl. terminal commands) without prompting.
        tool_permissions.default = "allow";
        # The message input box is monospace (like the editor); bump from 12 to
        # match buffer_font_size so typing doesn't feel cramped.
        agent_buffer_font_size = 16;
      };
      # Built-in which-key: holds a key combo briefly → shows available
      # follow-up keys. Handy for discovering vim/bindings as you go.
      which_key = {
        enabled = true;
        delay_ms = 500;
      };
      tab_bar = {
        show_nav_history_buttons = false;
        show_tab_bar_buttons = false;
      };
      languages = {
        # The registry "Nix" extension declares nil as its LSP; we use nixd
        # instead (it ships via extraPackages and is already configured above).
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
          # Hide/show the whole right dock — panel ToggleFocus actions only
          # move focus, they never close the panel.
          "ctrl-b" = "workspace::ToggleRightDock";
          # Direct agent toggle (stock: ctrl-?, ctrl-alt-i in the VSCode map)
          "ctrl-alt-m" = "agent::ToggleFocus";
        };
      }
    ];
  };
}
