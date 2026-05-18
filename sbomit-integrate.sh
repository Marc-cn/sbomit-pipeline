#!/usr/bin/env sh
# ============================================================================
#  sbomit-integrate.sh  --  one-time SBOMit integration for any GitHub project
# ============================================================================
#
#  WHAT THIS DOES
#    Writes a self-contained SBOMit attestation workflow into your repository
#    at .github/workflows/sbomit.yml. The workflow is pinned to a released,
#    checksum-verified version. After it runs you own the file outright --
#    there is no runtime dependency on any external repository.
#
#  SECURITY
#    This script is intended to be downloaded and READ before you run it.
#    Do NOT pipe it straight from the network into a shell. It performs no
#    privileged actions, sets no secrets, and prints every step. The workflow
#    it fetches is verified against a published SHA-256 before being written;
#    if verification fails the script aborts and writes nothing.
#
#  USAGE
#    1. cd into the root of your git repository
#    2. Review this script
#    3. sh sbomit-integrate.sh                 # local-only mode (no server)
#       sh sbomit-integrate.sh https://your-sbomit-server.example.org
#                                              # also wire central inventory
#
#  REQUIREMENTS
#    git, curl, sha256sum (or shasum). 'gh' is optional and only used to set
#    the server repository variable when a server URL is supplied.
# ============================================================================

set -eu

# ---- Pinned release ---------------------------------------------------------
# The workflow is fetched from this exact tag, never a moving branch, so every
# maintainer who runs this gets the same validated file. Bumping the pin is a
# deliberate, separate re-release.
PIN_TAG="v1.0.0"
RAW_BASE="https://raw.githubusercontent.com/Marc-cn/sbomit-pipeline/${PIN_TAG}"
WF_URL="${RAW_BASE}/examples/sbomit.yml"
SHA_URL="${RAW_BASE}/examples/sbomit.yml.sha256"
DEST=".github/workflows/sbomit.yml"

SERVER_URL="${1:-}"

say()  { printf '%s\n' "$*"; }
err()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# ---- Preconditions ----------------------------------------------------------
command -v git    >/dev/null 2>&1 || err "git is required."
command -v curl   >/dev/null 2>&1 || err "curl is required."
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || err "Run this from inside your git repository (no .git found here)."

# pick a sha256 tool
if command -v sha256sum >/dev/null 2>&1; then
  SHA_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  SHA_CMD="shasum -a 256"
else
  err "Need sha256sum or shasum to verify the download."
fi

say "SBOMit integration"
say "  pinned release : ${PIN_TAG}"
say "  destination    : ${DEST}"
if [ -n "${SERVER_URL}" ]; then
  say "  central server : ${SERVER_URL} (server-first, local fallback)"
else
  say "  mode           : local-only (no server; fully self-contained)"
fi
say ""

# ---- Fetch workflow + its published checksum --------------------------------
TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

say "Downloading workflow and checksum from the pinned tag..."
curl -fsSL "${WF_URL}"  -o "${TMPDIR}/sbomit.yml"      || err "Could not download ${WF_URL}"
curl -fsSL "${SHA_URL}" -o "${TMPDIR}/sbomit.yml.sha256" || err "Could not download ${SHA_URL}"

# ---- Verify ----------------------------------------------------------------
# The .sha256 file is published alongside the workflow at the same pinned tag.
# We recompute the hash of what we received and require an exact match.
EXPECTED="$(awk '{print $1}' "${TMPDIR}/sbomit.yml.sha256")"
ACTUAL="$(${SHA_CMD} "${TMPDIR}/sbomit.yml" | awk '{print $1}')"

if [ -z "${EXPECTED}" ]; then
  err "Published checksum file was empty -- aborting (nothing written)."
fi
if [ "${EXPECTED}" != "${ACTUAL}" ]; then
  say "  expected: ${EXPECTED}"
  say "  actual  : ${ACTUAL}"
  err "Checksum mismatch -- the downloaded workflow does not match the
       published hash for ${PIN_TAG}. Aborting; nothing written."
fi
say "  checksum verified: ${ACTUAL}"
say ""

# ---- Install ---------------------------------------------------------------
mkdir -p "$(dirname "${DEST}")"
if [ -f "${DEST}" ]; then
  cp "${DEST}" "${DEST}.bak.$(date +%s)"
  say "Existing ${DEST} backed up."
fi
cp "${TMPDIR}/sbomit.yml" "${DEST}"
say "Wrote ${DEST}"
say ""

# ---- Optional: wire the central server --------------------------------------
# We set ONLY the non-secret repository variable (the server URL). The token
# is a secret and is never handled by this script -- we print the exact
# command for you to run yourself.
if [ -n "${SERVER_URL}" ]; then
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if gh variable set SBOMIT_SERVER --body "${SERVER_URL}" >/dev/null 2>&1; then
      say "Set repository variable SBOMIT_SERVER = ${SERVER_URL}"
    else
      say "Could not set the SBOMIT_SERVER variable automatically."
      say "Set it manually:  gh variable set SBOMIT_SERVER --body \"${SERVER_URL}\""
    fi
  else
    say "gh CLI not authenticated; set the server variable manually:"
    say "  gh variable set SBOMIT_SERVER --body \"${SERVER_URL}\""
  fi
  say ""
  say "ACTION REQUIRED -- set the server token yourself (this script never"
  say "handles secret values). Run, with your real token:"
  say ""
  say "  gh secret set SBOMIT_TOKEN --body \"<your-server-token>\""
  say ""
  say "Until both SBOMIT_SERVER and SBOMIT_TOKEN are set the workflow runs"
  say "in local-only mode (it still works; it just won't use the server)."
  say ""
fi

# ---- Next steps -------------------------------------------------------------
say "Done. Next steps:"
say "  1. Review the workflow:   git diff -- ${DEST}"
say "  2. Commit it:             git add ${DEST} && git commit -m 'ci: add SBOMit attestation'"
say "  3. Push / open a PR."
say ""
say "The workflow runs on every push and pull request, attests the build,"
say "and uploads the SBOM as a build artifact. In server mode it also sends"
say "the attestation to your central inventory and retrieves the SBOM from"
say "it, falling back to local generation if the server is unavailable."
