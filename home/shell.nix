{ pkgs, ... }:
{
  programs = {
    # Keep bash as login shell (modules/core.nix); exec into fish on interactive
    # start, unless the parent is fish (you typed it) or there's no tty (Zed's
    # env capture runs `bash -l -i -c`).
    bash = {
      enable = true;
      initExtra = ''
        if [[ $- == *i* ]] && [[ -t 0 && -t 1 ]] &&
          [[ "$(${pkgs.procps}/bin/ps -o comm= -p $PPID 2>/dev/null)" != fish ]]; then
          exec ${pkgs.fish}/bin/fish
        fi
      '';
    };

    fish = {
      enable = true;
      interactiveShellInit = ''
        set -g fish_greeting # no welcome banner
        # nix-shell runs --rcfile, not ~/.bashrc, so the exec guard never
        # fires; append --run fish to land in fish with the nix env on PATH.
        function nix-shell --wraps=nix-shell
          if string match -q -- '--run*' $argv
            command nix-shell $argv
          else
            command nix-shell $argv --run fish
          end
        end
      '';
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
