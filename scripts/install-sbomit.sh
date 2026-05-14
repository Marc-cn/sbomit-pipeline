#!/usr/bin/env bash
# install-sbomit.sh — download sbomit from sbomit-pipeline release.
# Verifies sha256 and installs to /usr/local/bin/sbomit.
set -euo pipefail

VERSION="${SBOMIT_VERSION:-v0.1.0}"
RELEASE_REPO="${SBOMIT_PIPELINE_REPO:-Marc-cn/sbomit-pipeline}"
ARCH="${ARCH:-linux-amd64}"
BIN_URL="https://github.com/${RELEASE_REPO}/releases/download/${VERSION}/sbomit-${ARCH}"
SUM_URL="${BIN_URL}.sha256"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading sbomit from $BIN_URL ..."
curl -fsSL "$BIN_URL" -o "$TMPDIR/sbomit"
curl -fsSL "$SUM_URL" -o "$TMPDIR/sbomit.sha256"

EXPECTED=$(awk '{print $1}' "$TMPDIR/sbomit.sha256")
ACTUAL=$(sha256sum "$TMPDIR/sbomit" | awk '{print $1}')

if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "ERROR: sha256 mismatch for sbomit"
  echo "  expected: $EXPECTED"
  echo "  actual:   $ACTUAL"
  exit 1
fi

chmod +x "$TMPDIR/sbomit"
sudo mv "$TMPDIR/sbomit" /usr/local/bin/sbomit
echo "Installed: $(sbomit help 2>&1 | head -1)"
