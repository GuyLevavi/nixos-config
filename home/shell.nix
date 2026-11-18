{ lib, pkgs, ... }:
let
  # Noctalia's starship template owns a palette block in this same file, so it
  # can't be programs.starship.settings (a read-only store symlink).
  # Upstream's no-runtime-versions preset minus "via"/"with", dropping the tables that
  # starshipOverrides sets as dotted keys (TOML rejects defining a table twice).
  starshipConfig = pkgs.runCommand "starship.toml" { } ''
    cat ${starshipOverrides} >$out
    ${lib.getExe pkgs.starship} preset no-runtime-versions \
      | awk '/^\[/ { skip = ($0 ~ /^\[(c|cmake|python)\]$/) } !skip' \
      | sed -E "s/^format = ([\"'])(via|with) /format = \1/" >>$out
  '';
  starshipOverrides = pkgs.writeText "starship-overrides.toml" ''
    cmake.disabled = true
    package.disabled = true
    git_branch.format = "[$symbol$branch]($style) "
    cmd_duration.format = "[$duration]($style) "
    c.format = "[$symbol]($style)"
    python.format = "[$symbol($virtualenv )]($style)"
    # Default ❄️ is emoji+VS16; fish/tmux mis-measure it and erase it on redraw.
    nix_shell.symbol = " "
    # The glyph draws wider than its one cell; the extra space keeps it off the next segment.
    nix_shell.format = "[$symbol]($style) "
    # Marks a nu nested in fish; empty indicators keep fish/bash prompts unchanged.
    shell.disabled = false
    shell.fish_indicator = ""
    shell.bash_indicator = ""
    # The space lives in the indicator: a "( )" group around a styled one never renders.
    shell.nu_indicator = "nu "
    shell.style = "bold green"
    shell.format = "[$indicator]($style)"
  '';

  # atuin's nu hooks are background jobs, which starship's jobs module counts
  # as yours (✦). Label atuin's and leave them out of the count; the greps fail
  # the build if either upstream init stops matching.
  atuinNu = pkgs.runCommand "atuin-nushell-config.nu" {
    nativeBuildInputs = [ pkgs.writableTmpDirAsHomeHook ];
  } ''
    ${lib.getExe pkgs.atuin} init nu | sed 's/job spawn {/job spawn --description atuin {/' >$out
    grep -q 'job spawn --description atuin' $out
  '';
  starshipNu = pkgs.runCommand "starship-nushell-config.nu" { } ''
    ${lib.getExe pkgs.starship} init nu \
      | sed 's/(job list | length)/(job list | where description? != "atuin" | length)/' >$out
    grep -q 'description? != "atuin"' $out
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

    # Secondary shell, started from fish; never a login shell.
    nushell = {
      enable = true;
      settings.show_banner = false;
      # After fzf, as home-manager orders atuin's, so atuin keeps Ctrl-R.
      extraConfig = lib.mkOrder 2000 ''
        use ${starshipNu}
        source ${atuinNu}
      '';
    };

    starship = {
      enable = true;
      enableBashIntegration = false;
      enableFishIntegration = true;
      enableNushellIntegration = false; # atuin-aware copy in nushell.extraConfig
    };
    zoxide = {
      enable = true;
      enableBashIntegration = false;
      enableFishIntegration = true;
      enableNushellIntegration = true;
    };
    atuin = {
      enable = true;
      enableBashIntegration = false;
      enableFishIntegration = true;
      enableNushellIntegration = false; # see nushell.extraConfig
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
      enableNushellIntegration = true;
      silent = true;
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
