# home/airgap.nix — offline delta on top of base.nix for the work machine.
# Built into a store closure by scripts/build-airgap-closure.sh; imported on
# the airgapped box with `nix copy` (see README).
{ pkgs, lib, ... }:
{
  # ── Work CLI tools (internal GitLab / Artifactory / OpenShift / S3) ────
  home.packages = with pkgs; [
    glab jfrog-cli openshift minio-client git-lfs
    pass gnupg pinentry-tty pass-git-helper
  ];

  # ── Offline credentials: pass (GPG-backed) as git credential helper ────
  # One-time setup on the airgap box:
  #   gpg --gen-key && pass init <key-id> && pass insert work/gitlab
  # Then map remotes in ~/.config/pass-git-helper/git-pass-mapping.ini:
  #   [gitlab.company.com]  target=work/gitlab
  programs.git.settings.credential.helper =
    "${pkgs.pass-git-helper}/bin/pass-git-helper";
  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-tty;
    defaultCacheTtl = 28800; # 8h — a full work session
    maxCacheTtl = 86400;
  };

  # ── Kill anything that phones home ─────────────────────────────────────
  home.file.".config/glab-cli/config.yml".text = "check_update: false\n";
}
