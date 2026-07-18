# home/gui.nix — desktop apps. COSMIC itself is configured in its Settings
# GUI (RON files in ~/.config/cosmic/); snapshot with `cosmic-save`.
{ pkgs, lib, ... }:
{
  # Electron/Chromium apps run native Wayland.
  home.sessionVariables.NIXOS_OZONE_WL = "1";

  # ── Terminal ───────────────────────────────────────────────────────────
  # COSMIC ships cosmic-term; kitty kept as the daily driver. Delete this
  # block and switch to cosmic-term if you find you don't care.
  programs.kitty = {
    enable = true;
    font = { name = "JetBrainsMono Nerd Font"; size = 12; };
    themeFile = "Catppuccin-Mocha";
  };

  # ── Editor: Zed (VSCode keybindings, no vim mode) ──────────────────────
  # extraPackages PATH-wraps zed so LSPs are found without global installs.
  programs.zed-editor = {
    enable = true;
    mutableUserSettings = true; # Nix wins on rebuild; Zed may write between
    extraPackages = with pkgs; [
      basedpyright ruff                       # python
      nixd nixpkgs-fmt                        # nix
      bash-language-server yaml-language-server taplo
    ];
    extensions = [ "nix" "toml" "dockerfile" "env" "basedpyright" ];
    userSettings = {
      base_keymap = "VSCode";
      vim_mode = false;
      buffer_font_family = "JetBrainsMono Nerd Font";
      buffer_font_size = 14;
      terminal.shell.program = "fish";
      telemetry = { metrics = false; diagnostics = false; };
      format_on_save = "on";
      languages.Python = {
        language_servers = [ "basedpyright" "!pyright" "ruff" ];
        formatter.language_server.name = "ruff";
      };
    };
  };

  # ── Browsers / apps ────────────────────────────────────────────────────
  programs.google-chrome.enable = true;
  programs.firefox.enable = true;

  home.packages = with pkgs; [
    wl-clipboard   # wl-copy / wl-paste
    keepassxc
  ];

  # ── COSMIC settings ⇄ git (see COSMIC.md) ─────────────────────────────
  # Rung 2: daily auto-snapshot of ~/.config/cosmic into the repo.
  # Commit when `git status` shows drift you want to keep.
  systemd.user.services.cosmic-snapshot = {
    Unit.Description = "Snapshot COSMIC settings into /etc/nixos";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.rsync}/bin/rsync -a --delete %h/.config/cosmic/ /etc/nixos/cosmic-snapshot/";
    };
  };
  systemd.user.timers.cosmic-snapshot = {
    Timer = { OnCalendar = "daily"; Persistent = true; };
    Install.WantedBy = [ "timers.target" ];
  };

  # Rung 3: fresh machine seeds itself from the snapshot (only if no
  # settings exist yet — never overwrites live GUI-managed config).
  home.activation.seedCosmic = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/cosmic" ] && [ -d /etc/nixos/cosmic-snapshot ]; then
      cp -r /etc/nixos/cosmic-snapshot "$HOME/.config/cosmic"
    fi
  '';
}
