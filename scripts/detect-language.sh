#!/usr/bin/env bash
# detect-language.sh — auto-detect project language and build command.
# Writes LANGUAGE and BUILD_CMD to $GITHUB_OUTPUT (when running in GHA)
# and also prints them to stdout for local testing.
#
# Detection precedence: go > rust > node > python > unknown
# Override: if BUILD_COMMAND env var is set and non-empty, it wins.
set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

LANGUAGE="unknown"
BUILD_CMD=""

if [ -f go.mod ]; then
  LANGUAGE="go"
  BUILD_CMD="go build -trimpath ./..."
elif [ -f Cargo.toml ]; then
  LANGUAGE="rust"
  BUILD_CMD="cargo build --release --locked"
elif [ -f package.json ]; then
  LANGUAGE="node"
  if grep -q '"build"' package.json 2>/dev/null; then
    BUILD_CMD="npm ci && npm run build"
  else
    BUILD_CMD="npm ci"
  fi
elif [ -f pyproject.toml ] || [ -f setup.py ] || [ -f setup.cfg ]; then
  LANGUAGE="python"
  if [ -f pyproject.toml ] && grep -q '\[build-system\]' pyproject.toml 2>/dev/null; then
    BUILD_CMD="python -m pip install --upgrade pip build && python -m build --wheel"
  elif [ -f requirements.txt ]; then
    BUILD_CMD="python -m pip install --upgrade pip && python -m pip install -r requirements.txt"
  else
    BUILD_CMD="python -m pip install --upgrade pip && python -m pip install ."
  fi
fi

# Allow override via env var
if [ -n "${BUILD_COMMAND:-}" ]; then
  BUILD_CMD="$BUILD_COMMAND"
  echo "Build command overridden by BUILD_COMMAND env var"
fi

echo "Detected language: $LANGUAGE"
echo "Build command:     $BUILD_CMD"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "language=$LANGUAGE"
    echo "build_cmd=$BUILD_CMD"
  } >> "$GITHUB_OUTPUT"
fi
