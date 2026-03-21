#!/usr/bin/env bash
# build-airgap-closure.sh — Run on a CONNECTED machine (has internet).
# Produces all artifacts needed to deploy headless config on an airgapped machine.
#
# Usage:
#   ./scripts/build-airgap-closure.sh [output-dir]
#
# Output:
#   airgap-artifacts/
#     nix-<version>-x86_64-linux.tar.xz  — Nix installer (one-time bootstrap)
#     nix-store/                          — Binary cache of the full closure
#     activation-store-path               — Store path for home-manager activation
#
# Transfer the entire airgap-artifacts/ directory to the airgapped machine.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-$REPO_DIR/airgap-artifacts}"

echo "==> Output directory: $OUT_DIR"
mkdir -p "$OUT_DIR"

# ── 1. Build home-manager activation package ────────────────────────
echo "==> Building home-manager activation package..."
nix build "$REPO_DIR#homeConfigurations.wsl.activationPackage" \
  --out-link "$OUT_DIR/result"

ACTIVATION_PATH="$(readlink -f "$OUT_DIR/result")"
echo "$ACTIVATION_PATH" > "$OUT_DIR/activation-store-path"
echo "    Activation path: $ACTIVATION_PATH"

# ── 2. Export closure as binary cache ────────────────────────────────
# nix copy --to file:// creates a fast binary cache format.
# Much faster to import than nix-store --export/--import.
echo "==> Exporting Nix store closure to binary cache..."
rm -rf "$OUT_DIR/nix-store"
nix copy --to "file://$OUT_DIR/nix-store" "$ACTIVATION_PATH"
echo "    Closure size: $(du -sh "$OUT_DIR/nix-store" | cut -f1)"

# ── 3. Download Nix installer for offline bootstrap ──────────────────
# Only needed for first-time setup on a machine without Nix.
NIX_VERSION="$(nix --version | grep -oP '\d+\.\d+\.\d+')"
NIX_TARBALL="nix-${NIX_VERSION}-x86_64-linux.tar.xz"
NIX_URL="https://releases.nixos.org/nix/nix-${NIX_VERSION}/${NIX_TARBALL}"

if [ ! -f "$OUT_DIR/$NIX_TARBALL" ]; then
  echo "==> Downloading Nix ${NIX_VERSION} installer..."
  curl -L "$NIX_URL" -o "$OUT_DIR/$NIX_TARBALL"
else
  echo "==> Nix installer already cached: $NIX_TARBALL"
fi

# ── 4. Summary ───────────────────────────────────────────────────────
echo ""
echo "==> Done! Artifacts in $OUT_DIR:"
ls -lh "$OUT_DIR/" | grep -v "^total"
echo ""
echo "Transfer '$OUT_DIR/' to the airgapped machine, then build with:"
echo "  podman build -f Dockerfile.airgap \\"
echo "    --build-arg ACTIVATION_STORE_PATH=$(cat "$OUT_DIR/activation-store-path") \\"
echo "    -t dev-headless ."
