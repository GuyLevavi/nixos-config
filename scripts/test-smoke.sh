#!/usr/bin/env bash
# scripts/test-smoke.sh — Binary + config smoke tests for headless profiles.
#
# Usage:
#   ./scripts/test-smoke.sh            # base tools only (wsl profile)
#   ./scripts/test-smoke.sh --airgap   # base + work tools (airgap profile)
#
# Run from host against a built image:
#   podman run --rm dev-headless bash ~/nixos-config/scripts/test-smoke.sh
#   podman run --rm dev-airgap   bash ~/scripts/test-smoke.sh --airgap
#
# Exit code: 0 = all pass, 1 = one or more failures.

set -uo pipefail

AIRGAP=false
[[ "${1:-}" == "--airgap" ]] && AIRGAP=true

PASS=0
FAIL=0

# Ensure Nix-managed binaries are on PATH inside containers.
export PATH=/home/gl/.nix-profile/bin:$PATH

# ── Helpers ───────────────────────────────────────────────────────────

ok()   { echo "  [OK]   $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

# check_bin NAME   — binary must exist on PATH
check_bin() {
  if command -v "$1" &>/dev/null; then ok "$1 present"
  else fail "$1 missing from PATH"; fi
}

# check_ver NAME CMD... — command must exit 0 and print output
check_ver() {
  local name="$1"; shift
  if "$@" &>/dev/null; then ok "$name --version"
  else fail "$name --version failed (binary broken or exits non-zero)"; fi
}

# check_cfg DESC CMD... — arbitrary command must succeed
check_cfg() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then ok "$desc"
  else fail "$desc"; fi
}

section() { echo ""; echo "── $1 ──────────────────────────────────────────"; }

# ── Base tools (both profiles) ────────────────────────────────────────

section "Shell & prompt"
check_ver "nushell"    nu --version
check_ver "starship"   starship --version
check_ver "carapace"   carapace --version
check_ver "atuin"      atuin --version
check_ver "zoxide"     zoxide --version
check_ver "fzf"        fzf --version

section "Editor"
check_ver "nvim"       nvim --version

section "Git"
check_ver "git"        git --version
check_ver "lazygit"    lazygit --version
check_ver "delta"      delta --version
check_cfg "git user.name set"  git config --global user.name
check_cfg "git user.email set" git config --global user.email

section "File tools"
check_ver "ripgrep"    rg --version
check_ver "fd"         fd --version
check_ver "bat"        bat --version
check_ver "eza"        eza --version
check_ver "sd"         sd --version
check_ver "dust"       dust --version
check_bin "yazi"
check_ver "glow"       glow --version
check_bin "lnav"
check_ver "fastfetch"  fastfetch --version

section "System monitoring"
check_ver "btop"       btop --version
check_bin "htop"
check_ver "procs"      procs --version

section "Containers"
check_bin "podman-compose"
check_bin "lazydocker"

section "Kubernetes"
check_ver "helm"       helm version
check_bin "k9s"

section "Python"
check_ver "uv"         uv --version

section "Multiplexer"
check_ver "tmux"       tmux -V

section "Misc"
check_bin "tv"           # television fuzzy finder
check_bin "opencode"
check_bin "posting"

# ── Airgap-only: work tools + credential manager ──────────────────────

if $AIRGAP; then
  section "Work tools (airgap only)"
  check_ver "glab"           glab --version
  check_ver "jf (jfrog-cli)" jf --version
  check_ver "oc"             oc version --client
  check_ver "mc"             mc --version
  check_ver "git-lfs"        git-lfs --version

  section "Credential manager (airgap only)"
  check_ver "gpg"            gpg --version
  check_ver "pass"           pass --version
  check_bin "pass-git-helper"
  check_bin "pinentry-tty"
  check_cfg "git credential.helper = pass-git-helper" \
    bash -c "git config --global credential.helper | grep -q pass-git-helper"
  check_cfg "glab check_update = false" \
    grep -q "check_update: false" /home/gl/.config/glab-cli/config.yml
fi

# ── Summary ───────────────────────────────────────────────────────────

echo ""
echo "── Results ─────────────────────────────────────────────────────────"
echo "  Passed : $PASS"
echo "  Failed : $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "SMOKE TEST FAILED — $FAIL check(s) did not pass."
  exit 1
fi

echo "All smoke tests passed."
exit 0
