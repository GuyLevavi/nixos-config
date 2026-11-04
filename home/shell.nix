{ lib, pkgs, ... }:
let
  # Noctalia's starship template owns a palette block in this same file, so it
  # can't be programs.starship.settings (a read-only store symlink).
  starshipConfig = pkgs.writeText "starship.toml" ''
    cmake.disabled = true
    git_branch.format = "[$symbol$branch]($style) "
    cmd_duration.format = "[$duration]($style) "
    c.format = "[$symbol]($style)"
    python.format = "[$symbol($virtualenv )]($style)"
    # Default ❄️ is emoji+VS16; fish/tmux mis-measure it and erase it on redraw.
    nix_shell.symbol = " "
    nix_shell.format = "[$symbol]($style)"
  '';
in
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

    # nix-direnv caches `use flake`; fish hook auto-injected.
    direnv = {
      enable = true;
      nix-direnv.enable = true;
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
    lazygit = {
      enable = true;
      # `|` cycles pagers. Output is piped, so delta can't detect the background: --dark is its fallback anyway.
      settings.git.diffRenderers = [
        {
          colorArg = "always";
          command = ''delta --dark --paging=never --hyperlinks --hyperlinks-file-link-format="lazygit-edit://{path}:{line}"'';
        }
        {
          type = "extDiff";
          command = "${pkgs.difftastic}/bin/difft --color=always";
        }
      ];
    };
    gh.enable = true;
  };

  # Rewrites everything outside Noctalia's palette block, keeping the block.
  home.activation.starshipConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="$HOME/.config/starship.toml"
    block=$(sed -n '/^# >>> NOCTALIA STARSHIP PALETTE >>>$/,/^# <<< NOCTALIA STARSHIP PALETTE <<<$/p' \
      "$cfg" 2>/dev/null || true)
    {
      if [ -n "$block" ]; then echo 'palette = "noctalia"'; fi
      cat ${starshipConfig}
      if [ -n "$block" ]; then printf '\n%s\n' "$block"; fi
    } >"$cfg.tmp"
    if cmp -s "$cfg" "$cfg.tmp"; then rm "$cfg.tmp"; else run mv "$cfg.tmp" "$cfg"; fi
  '';
}
