# SBOMit Attestation — Standard Integration Procedure

This is the standard way to add build-time SBOM attestation to any GitHub
project. It produces a signed [in-toto/witness](https://github.com/in-toto/witness)
attestation of your build and an enriched SPDX 2.3 SBOM on every push and
pull request.

## The integration

Two options, both delivering the identical, validated pipeline. Pick one.

### Option 1 — copy the workflow file (recommended)

From the root of your git repository:

```bash
mkdir -p .github/workflows
curl -fsSL \
  https://raw.githubusercontent.com/Marc-cn/sbomit-pipeline/v1/examples/sbomit.yml \
  -o .github/workflows/sbomit.yml
```

Then review the file, commit, push, and open a PR. The workflow runs on every
subsequent push and pull request. There are no secrets to configure and no
external services in the default mode. You own the file outright; to update
later, re-download and review the diff.

### Option 2 — reference the reusable workflow

Add a single file to your repository at `.github/workflows/sbomit.yml`:

```yaml
name: SBOMit
on:
  push:
    branches: [main, master]
  pull_request:

jobs:
  sbomit:
    uses: Marc-cn/sbomit-pipeline/.github/workflows/sbomit-reusable.yml@v1
```

This is ~5 lines and references the published reusable workflow at the pinned
`@v1` tag. All pipeline logic lives in the referenced repository; you receive
backward-compatible fixes automatically without any manual action.

## What it does

On every push and PR the workflow:

1. Auto-detects your project's language (Go, Rust, Node, Python).
2. Runs your build under `witness`, recording every file accessed, process
   spawned, and (where supported) network call — a tamper-evident record of
   what actually happened during the build.
3. Generates an enriched SPDX 2.3 SBOM from that attestation, augmented with
   a `syft` catalog of your source tree.
4. Uploads the attestation, the SBOM, and the ephemeral public key as a
   single build artifact downloadable from the workflow run.

## Customization

Everything is optional. Defaults work for the common case.

| Input | Purpose | Default |
|---|---|---|
| `build_command` | Override the auto-detected build (e.g. for a project whose `make build` runs a long test suite). | auto-detect |
| `sbomit_server` | Base URL of a central inventory server (see below). | unset (local) |
| `sbomit_version` | Pin for the eBPF witness / prebuilt sbomit release assets. | `v0.1.0` |
| `witness_version` | Official `in-toto/witness` fallback version. | `0.11.0` |
| `sbomit_go_module` | Official sbomit Go module (primary install). | `github.com/sbomit/sbomit@latest` |
| `syft_version` | Pinned, checksum-verified syft release. | `1.44.0` |

Example for a project whose default build is too heavy (Option 2 form):

```yaml
jobs:
  sbomit:
    uses: Marc-cn/sbomit-pipeline/.github/workflows/sbomit-reusable.yml@v1
    with:
      build_command: "make just-install"
```

For Option 1, edit the `env: BUILD_COMMAND:` field at the top of the copied
`sbomit.yml` file.

## Tool sourcing (transparency)

- **witness**: an eBPF-capable build is used when available (richer
  tracing); otherwise the workflow falls back to the official
  `in-toto/witness` release using ptrace. Both are checksum-verified.
- **sbomit**: installed from the official module
  `go install github.com/sbomit/sbomit` first; a pinned prebuilt binary
  is only a fallback.
- **syft**: a pinned release is downloaded and its SHA-256 verified
  against Anchore's published checksums before use. No piped shell.

## Optional: central inventory (advanced, opt-in)

By default the workflow is fully self-contained — nothing leaves your
runner except the artifact attached to your own workflow run.

If you operate a central SBOM inventory server, you can additionally
have each run POST its attestation there and request a server-generated
SBOM. This is **opt-in** and requires two settings in the repository:

- Variable `SBOMIT_SERVER`: the server's base URL (not a secret)
- Secret `SBOMIT_TOKEN`: the bearer token for the server

For Option 2 (reusable workflow), supply them as inputs/secrets in the
caller:

```yaml
jobs:
  sbomit:
    uses: Marc-cn/sbomit-pipeline/.github/workflows/sbomit-reusable.yml@v1
    with:
      sbomit_server: "https://sbomit.example.org"
    secrets:
      sbomit_token: ${{ secrets.SBOMIT_TOKEN }}
```

For Option 1 (copied workflow), set them as a repository variable and
secret directly (Settings → Secrets and variables → Actions).

Behavior when configured: the attestation is POSTed to the server, and
the SBOM is requested from it. The server builds the SBOM from the
attestation itself; it cannot — and does not — access your source tree.
If the server is unreachable, returns an error, or returns anything that
is not a valid non-empty SPDX document, the run automatically falls back
to local generation. A misconfigured or down server never fails your
build and never ships an empty SBOM — this is enforced by explicit
HTTP-status and SPDX-content validation.

If `sbomit_server` / `sbomit_token` are not set, none of this runs and
there is zero overhead — the public, no-secret story is fully preserved.

## Version pinning

- `@v1` — tracks the latest backward-compatible `v1.x`. Recommended for
  most projects; you receive fixes automatically.
- `@v1.0.1` — an immutable exact version. Use this if you require a
  frozen, fully reproducible dependency.

Breaking changes will only ever be introduced under a new major tag
(`@v2`), never within an existing one.
