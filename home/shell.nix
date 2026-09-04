{ pkgs, ... }:
{
  # bash stays the login shell (modules/core.nix) so scripts/systemd/`bash -c`
  # keep POSIX semantics; it execs into fish on interactive start. The
  # BASH_EXECS_FISH marker survives the exec, so a deliberate nested `bash`
  # from inside fish doesn't bounce straight back.
  programs.bash = {
    enable = true;
    initExtra = ''
      if [[ -z "''${BASH_EXECS_FISH:-}" ]]; then
        export BASH_EXECS_FISH=1
        exec ${pkgs.fish}/bin/fish
      fi
    '';
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = "set -g fish_greeting"; # no welcome banner
    shellAliases = {
      ls = "eza --icons --group-directories-first";
      ll = "eza -l --icons --git";
      cat = "bat -p";
      lg = "lazygit";
    };
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = true;
  };
  programs.zoxide = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = true;
  };
  programs.atuin = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = true;
    settings = {
      auto_sync = false;
      update_check = false;
    };
  };
  programs.fzf = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = true;
    historyWidget.command = ""; # atuin owns Ctrl-R; fzf keeps Ctrl-T/Alt-C
  };

  programs.tmux = {
    enable = true;
    prefix = "C-a";
    baseIndex = 1;
    escapeTime = 0;
    terminal = "tmux-256color";
    mouse = true;
    keyMode = "vi";
    extraConfig = ''
      set -as terminal-features ",*:RGB"
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %
    '';
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "guy";
      user.email = "guylevavi@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
  programs.lazygit.enable = true;
  programs.gh.enable = true;
}
