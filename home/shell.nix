{ pkgs, ... }:
{
  programs = {
    # bash stays the login shell (modules/core.nix) so scripts/systemd/`bash -c`
    # keep POSIX semantics; it execs into fish on interactive start.
    #
    # The guard is the *parent process*, not an exported marker. The marker this
    # used to use (BASH_EXECS_FISH=1, set just before the exec) was inherited by
    # every descendant of the fish session, so anything that later spawned
    # $SHELL from inside it — nvim's `:terminal`, a tmux pane, anything started
    # from an already-fish terminal — found the marker set and stayed in bare
    # bash: no starship, no aliases, no atuin. Parent-is-fish is the one case
    # that must not bounce back: you typed `bash` at a fish prompt and meant it.
    bash = {
      enable = true;
      initExtra = ''
        if [[ $- == *i* ]] &&
          [[ "$(${pkgs.procps}/bin/ps -o comm= -p $PPID 2>/dev/null)" != fish ]]; then
          exec ${pkgs.fish}/bin/fish
        fi
      '';
    };

    fish = {
      enable = true;
      interactiveShellInit = "set -g fish_greeting"; # no welcome banner
      shellAliases = {
        ls = "eza --icons --group-directories-first";
        ll = "eza -l --icons --git";
        cat = "bat -p";
        lg = "lazygit";
      };
    };

    starship = {
      enable = true;
      enableBashIntegration = false;
      enableFishIntegration = true;
    };
    zoxide = {
      enable = true;
      enableBashIntegration = false;
      enableFishIntegration = true;
    };
    atuin = {
      enable = true;
      enableBashIntegration = false;
      enableFishIntegration = true;
      settings = {
        auto_sync = false;
        update_check = false;
      };
    };
    fzf = {
      enable = true;
      enableBashIntegration = false;
      enableFishIntegration = true;
      historyWidget.command = ""; # atuin owns Ctrl-R; fzf keeps Ctrl-T/Alt-C
    };

    tmux = {
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

    git = {
      enable = true;
      settings = {
        user.name = "guy";
        user.email = "guylevavi@gmail.com";
        init.defaultBranch = "main";
        pull.rebase = true;
      };
    };
    delta = {
      enable = true;
      enableGitIntegration = true;
    };
    lazygit.enable = true;
    gh.enable = true;
  };
}
