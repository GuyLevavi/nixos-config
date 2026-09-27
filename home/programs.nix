{ pkgs, ... }:
let
  # One declaration for every editor — see home/lsp.nix.
  lspPackages = import ./lsp.nix { inherit pkgs; };
  # opencode ships only ripgrep on PATH; add the shared language servers so
  # its `lsp` config can spawn nix-built binaries by name.
  opencodeWithLsp = pkgs.symlinkJoin { # re-wrap the binary, don't rebuild it
    name = "opencode-${pkgs.opencode.version}";
    paths = [ pkgs.opencode ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/opencode \
        --prefix PATH : ${pkgs.lib.makeBinPath lspPackages}
    '';
  };
in
{
  programs = {
    # Colours come from Noctalia's template at runtime; only non-colour settings
    # belong here. Ghostty doesn't hot-reload — new window after a palette switch.
    ghostty = {
      enable = true;
      settings = {
        theme = "noctalia";
        command = "tmux new-session -A -s main";
        font-family = "JetBrainsMono Nerd Font";
        font-size = 14;
        window-decoration = false;
        # Padding is charged in whole cells here: 2 never costs a column, 4
        # sometimes does, 8 always.
        window-padding-x = 4;
        window-padding-y = 0;
        # Not "extend": that duplicates the nearest grid row into the padding.
        window-padding-color = "background";
        # Spreads the undrawable remainder across both edges.
        window-padding-balance = true;
        confirm-close-surface = false;
      };
    };

    bat.enable = true;
    eza.enable = true;
    ripgrep.enable = true;

    # gpu0 = dGPU via NVML on gpubox (host overlay adds the driver runpath),
    # iGPU via i915 on cpubox. color_theme=noctalia keeps Noctalia's template
    # hook a no-op against this read-only file.
    btop = {
      enable = true;
      settings = {
        color_theme = "noctalia";
        shown_boxes = "cpu mem gpu0";
      };
    };
  };

  # Noctalia can't theme the cursor; pick one legible on any palette. No
  # gtk.enable (ownership rule) — Wayland apps read XCURSOR_THEME from the env.
  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    hyprcursor.enable = true;
  };

  home.packages = with pkgs; [
    # screenshots / media
    hyprpicker
    grim
    slurp
    wf-recorder
    cliphist
    imv
    mpv
    unzip
    jq
    helix # zero-config terminal editor fallback

    # CLI (no home-manager module)
    fd
    bubblewrap # bwrap — zed's agent uses it to sandbox terminal commands
    dust
    yazi
    podman-compose
    lazydocker

    # dev
    gcc
    python3
    uv
    nodejs
    claude-code
    opencodeWithLsp # opencode + the shared language-server PATH
  ];
}
