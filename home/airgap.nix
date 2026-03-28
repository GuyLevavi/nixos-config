# home/airgap.nix — overrides for airgap / offline deployments
# Imported on top of base.nix for the homeConfigurations.airgap flake output.
# Disables anything that phones home or requires internet at runtime.
# Also adds work-specific CLI tools (GitLab, JFrog, OpenShift, MinIO).
{ pkgs, lib, ... }:

{
  # ── Online-tool overrides ─────────────────────────────────────────────
  # opencode: disable auto-update and online plugins
  programs.opencode.settings.autoupdate = lib.mkForce false;
  programs.opencode.settings.plugin     = lib.mkForce [];

  # atuin: already has auto_sync=false in base.nix; also disable update check
  programs.atuin.settings.update_check = lib.mkForce false;

  # ── Work CLI tools ────────────────────────────────────────────────────
  # These target the internal work network (GitLab, Artifactory, OpenShift).
  # k9s and helm are already in base.nix.
  home.packages = with pkgs; [
    glab          # GitLab CLI — MR/issue/CI management
    jfrog-cli     # JFrog Artifactory / Xray CLI
    openshift     # oc — OpenShift + kubectl CLI
    minio-client  # mc — S3-compatible object storage CLI
    git-lfs       # Git Large File Storage

    # Credential management (GPG-backed, fully offline)
    pass             # password-store: encrypted credential vault
    gnupg            # GNU Privacy Guard (required by pass)
    pinentry-tty     # TTY PIN entry — works headless and in Docker
    pass-git-helper  # git credential helper that reads from pass
  ];

  # ── Git credential helper ─────────────────────────────────────────────
  # pass-git-helper maps remote URLs to pass entries.
  # Setup:
  #   gpg --gen-key
  #   pass init <gpg-key-id>
  #   pass insert work/gitlab (enter: username on line 1, token on line 2)
  # Then create ~/.config/pass-git-helper/git-pass-mapping.ini:
  #   [gitlab.company.com]
  #   target=work/gitlab
  programs.git.settings.credential.helper =
    "${pkgs.pass-git-helper}/bin/pass-git-helper";

  # ── GPG agent (headless / Docker) ────────────────────────────────────
  # pinentry-tty works without Wayland/X11.
  # In Docker without systemd the socket won't auto-start — run:
  #   eval $(gpg-agent --daemon --pinentry-program $(which pinentry-tty))
  programs.gpg.enable = true;
  services.gpg-agent = {
    enable           = true;
    pinentry.package = pkgs.pinentry-tty;
    defaultCacheTtl = 28800;  # 8 h — covers a full airgap work session
    maxCacheTtl     = 86400;  # 24 h
  };

  # ── lazy.nvim bootstrap (airgap only) ────────────────────────────────
  # LazyVim's init.lua clones lazy.nvim from GitHub on first launch if absent.
  # On an online machine, that clone must succeed so lazy.nvim can git-manage
  # itself (self-update, integrity checks). Pre-linking a Nix store path breaks
  # that because lazy.nvim requires a real git repo at that location.
  # Airgap has no network, so we pre-link the nixpkgs copy to skip the clone.
  xdg.dataFile."nvim/lazy/lazy.nvim".source = pkgs.vimPlugins.lazy-nvim;

  # ── glab — disable update check ──────────────────────────────────────
  home.file.".config/glab-cli/config.yml".text = ''
    check_update: false
  '';
}
