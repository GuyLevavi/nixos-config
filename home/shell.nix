{ pkgs, ... }:
{
  programs = {
    # bash stays the login shell (modules/core.nix) so scripts/systemd/`bash -c`
    # keep POSIX semantics; it execs into fish on interactive start.
    #
    # The guard is the *parent process*, not an exported marker. The marker this
    # used to use (BASH_EXECS_FISH=1, set just before the exec) was inherited by
    # every descendant of the fish session, so anything that later spawned
    # $SHELL from inside it — an editor's integrated terminal, a tmux pane,
    # anything started from an already-fish terminal — found the marker set and
    # stayed in bare bash: no starship, no aliases, no atuin. Parent-is-fish is
    # the one case that must not bounce back: you typed `bash` at a fish prompt
    # and meant it.
    #
    # The -t checks keep GUI tools alive: Zed captures its environment by
    # spawning `bash -l -i -c` with no terminal attached, and an unconditional
    # exec replaces bash before the -c command runs — fish starts reading stdin
    # instead, the capture finds no JSON, and every worktree loses its PATH
    # (nixd "not available in your environment"). No tty -> stay in bash and
    # let the capture command run.
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
        # nix-shell's interactive bash runs with --rcfile (stdenv setup) instead
        # of sourcing ~/.bashrc, so the exec-to-fish guard never fires inside
        # it. Wrap the command instead: --run fish starts fish (still interactive
        # on a tty, so config.fish/starship load) with the nix env on PATH.
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
