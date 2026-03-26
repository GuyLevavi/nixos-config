#!/usr/bin/env bash
# test-container.sh — run inside an activated airgap container to verify the environment
# Usage: bash test-container.sh
set -uo pipefail

PASS=0; FAIL=0
green='\033[0;32m'; red='\033[0;31m'; bold='\033[1m'; reset='\033[0m'
pass() { printf "  ${green}✓${reset} %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${red}✗${reset} %s\n" "$1"; FAIL=$((FAIL+1)); }
section() { printf "\n${bold}── %s${reset}\n" "$1"; }

NIX_BIN="$HOME/.nix-profile/bin"
NU_ENV="$HOME/.config/nushell/env.nu"

section "Nushell startup (no errors)"
# --no-config-file: sanity check without any config
NU_OUT=$(timeout 8 "$NIX_BIN/nu" --no-config-file -c "echo ok" 2>&1)
[[ "$NU_OUT" == "ok" ]] && pass "nu --no-config-file starts clean" || fail "nu --no-config-file: $NU_OUT"

# With env.nu loaded: our guard code and PATH setup must not produce stderr.
# (nushell 0.111 only loads env.nu in interactive/TTY mode; --env-config
#  simulates what users get when they run 'exec nu' from bash.)
NU_ERR=$(timeout 8 "$NIX_BIN/nu" --env-config "$NU_ENV" -c "echo ok" 2>&1 >/dev/null)
[[ -z "$NU_ERR" ]] && pass "nu with env.nu: no stderr" || fail "nu env.nu stderr: $NU_ERR"

section "Core binaries"
for bin in nvim nu tmux zoxide starship fzf rg fd bat eza; do
    [[ -x "$NIX_BIN/$bin" ]] && pass "$bin" || fail "$bin missing from $NIX_BIN"
done

section "Neovim version"
NVIM_VER=$("$NIX_BIN/nvim" --version 2>/dev/null | head -1)
[[ "$NVIM_VER" == NVIM* ]] && pass "$NVIM_VER" || fail "nvim --version failed"

section "NixVim config"
[[ -f "$HOME/.config/nvim/init.lua" ]] && pass "~/.config/nvim/init.lua exists" \
    || fail "~/.config/nvim/init.lua missing"
[[ -d "$HOME/.config/nvim/lua" ]] && pass "~/.config/nvim/lua/ dir exists" \
    || fail "~/.config/nvim/lua/ dir missing"

section "LSP binaries (via nvim extraPackages PATH)"
# --clean skips user config (avoids startup hangs); extraPackages PATH is still
# injected by the nvim wrapper itself, so vim.fn.exepath() works correctly.
for bin in pyright-langserver nil lua-language-server bash-language-server \
           vtsls yaml-language-server ruff black stylua nixpkgs-fmt shfmt; do
    result=$(timeout 8 "$NIX_BIN/nvim" --headless --clean \
        -c "lua io.write(vim.fn.exepath('$bin') or '')" -c "qa" 2>/dev/null)
    [[ -n "$result" ]] && pass "$bin" || fail "$bin not found in nvim PATH"
done

section "Python provider (pynvim)"
PY3=$(timeout 8 "$NIX_BIN/nvim" --headless --clean \
    -c "lua io.write(vim.g.python3_host_prog or '')" -c "qa" 2>/dev/null)
[[ -z "$PY3" ]] && PY3="$NIX_BIN/nvim-python3"
if [[ -x "$PY3" ]]; then
    pass "python3_host_prog: $PY3"
    result=$("$PY3" -c "import pynvim" 2>&1)
    [[ -z "$result" ]] && pass "  import pynvim" || fail "  import pynvim: $result"
else
    fail "python3_host_prog not found: $PY3"
fi

section "Zoxide integration"
# Use --env-config so env.nu PATH setup runs (adds ~/.nix-profile/bin).
# This matches interactive 'exec nu' — the way users actually launch nushell.
ZO=$(timeout 8 "$NIX_BIN/nu" --env-config "$NU_ENV" -c "zoxide --version" 2>&1)
[[ "$ZO" == zoxide* ]] && pass "zoxide accessible from nu: $ZO" || fail "zoxide in nu: $ZO"

section "DOCKER_HOST guard (no XDG_RUNTIME_DIR crash)"
# Unset XDG_RUNTIME_DIR and verify our guard in env.nu prevents a crash.
ERR=$(env -u XDG_RUNTIME_DIR timeout 8 "$NIX_BIN/nu" --env-config "$NU_ENV" -c "echo ok" 2>&1 >/dev/null)
[[ -z "$ERR" ]] && pass "nu starts without XDG_RUNTIME_DIR" || fail "nu crash without XDG_RUNTIME_DIR: $ERR"

# ── Summary ───────────────────────────────────────────────────────────────────
printf "\n${bold}══════════════════════════════════${reset}\n"
printf "  ${green}PASSED: %d${reset}\n" "$PASS"
[[ $FAIL -gt 0 ]] \
    && printf "  ${red}FAILED: %d${reset}\n" "$FAIL" \
    || printf "  All checks passed.\n"
printf "${bold}══════════════════════════════════${reset}\n"
[[ $FAIL -eq 0 ]]
