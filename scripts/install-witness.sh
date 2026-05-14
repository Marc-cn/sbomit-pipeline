#!/usr/bin/env bash
# install-witness.sh — download witness (eBPF-capable) from sbomit-pipeline release.
# Verifies sha256 and installs to /usr/local/bin/witness.
set -euo pipefail

VERSION="${WITNESS_VERSION:-v0.1.0}"
RELEASE_REPO="${SBOMIT_PIPELINE_REPO:-Marc-cn/sbomit-pipeline}"
ARCH="${ARCH:-linux-amd64}"
BIN_URL="https://github.com/${RELEASE_REPO}/releases/download/${VERSION}/witness-ebpf-${ARCH}"
SUM_URL="${BIN_URL}.sha256"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading witness from $BIN_URL ..."
curl -fsSL "$BIN_URL" -o "$TMPDIR/witness"
curl -fsSL "$SUM_URL" -o "$TMPDIR/witness.sha256"

# .sha256 file format: "<hash>  filename" — strip path before verify
EXPECTED=$(awk '{print $1}' "$TMPDIR/witness.sha256")
ACTUAL=$(sha256sum "$TMPDIR/witness" | awk '{print $1}')

if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "ERROR: sha256 mismatch for witness"
  echo "  expected: $EXPECTED"
  echo "  actual:   $ACTUAL"
  exit 1
fi

chmod +x "$TMPDIR/witness"
sudo mv "$TMPDIR/witness" /usr/local/bin/witness
echo "Installed: $(witness version)"
