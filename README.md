# SBOMit Pipeline

Build-time **attestation + SBOM generation** for any project.

The pipeline runs your build under [`witness`](https://github.com/in-toto/witness),
producing a signed, tamper-evident record of what the build *actually did*,
every file accessed, process spawned, and (where supported) network call, then
derives an enriched SBOM from that evidence. SBOMs built this way
reflect the real build, not a manifest's claims about it.

## Integrate it (pick one)

Both options deliver the **identical, validated pipeline**.

| Option | What you do | Dependency | Best for |
|--------|-------------|------------|----------|
| **1. Copy the workflow file** *(recommended)* | drop `examples/sbomit.yml` into `.github/workflows/` in your repo | none (you own the file) | full ownership, no runtime dependency |
| **2. Reference the reusable workflow** | add a ~5-line workflow with `uses: …@v1` | `@v1` (auto-updates) | automatic fixes, no manual action |

Full reference: **[`STANDARD-PROCEDURE.md`](STANDARD-PROCEDURE.md)**.

### Option 1 — copy the workflow file (recommended)

From the root of your git repository:

```bash
mkdir -p .github/workflows
curl -fsSL \
  https://raw.githubusercontent.com/Marc-cn/sbomit-pipeline/v1/examples/sbomit.yml \
  -o .github/workflows/sbomit.yml
```

Review the file, commit it, push, open a PR. You now own the file; there is
no runtime dependency on any external repository. To update later, re-download
and review the diff.

### Option 2 — reference the reusable workflow

Create `.github/workflows/sbomit.yml` in your repo with:

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

All logic lives in this repository and is pinned by `@v1`; you receive
backward-compatible fixes automatically. Override a non-standard build with
`with: { build_command: "make just-install" }`.

---

## What the workflow does

On every push and pull request:

1. **Auto-detects** the project language (Go, Rust, Node, Python).
2. **Installs tooling** (pinned, checksum-verified):
   - `witness` — eBPF-capable build first; falls back to the official
     `in-toto/witness` release (ptrace) if unavailable.
   - `sbomit` — official module `go install github.com/sbomit/sbomit` first;
     a prebuilt binary only as a fallback.
   - `syft` — pinned Anchore release, SHA-256 verified against the official
     checksum manifest.
3. **Generates** an ephemeral ED25519 signing key for the run.
4. **Runs the build under `witness`**, capturing build-time facts as a signed
   attestation (eBPF tracing where available, otherwise ptrace).
5. **Produces the SBOM — server-first with local fallback:**
   - If a central server is configured (`SBOMIT_SERVER` + `SBOMIT_TOKEN`), the
     attestation is POSTed there and a server-generated SPDX SBOM is fetched.
     The response is validated (HTTP 2xx **and** a non-empty, structurally
     valid SPDX document) before it is trusted.
   - Otherwise, or on any server failure, the SBOM is generated **locally**
     (SPDX always; CycloneDX best-effort) with a syft catalog of the source.
   - A misconfigured or down server **never fails the build and never ships
     an empty SBOM** — it falls back cleanly.
6. **Uploads** `attestation.json`, the SBOM(s), and the public key as a single
   workflow artifact.

If no server is configured the pipeline is fully self-contained: no secrets,
no external services.

---

## Optional: central inventory

Supplying `SBOMIT_SERVER` (repo variable) and `SBOMIT_TOKEN` (repo secret)
makes each run also send its attestation to a central server and retrieve a
server-generated SBOM — a single place to query "which projects use this
vulnerable library?". Strictly opt-in; without both set, the code path
does not run and there is zero overhead. The server builds the SBOM from the
attestation itself and never accesses your source.

---

## Versioning

Releases follow the GitHub Actions convention:

- **`@v1`** — latest backward-compatible `v1.x`; recommended for most projects.
- **`@v1.0.1`** — immutable exact version; use for strict reproducibility.

Breaking changes only ever appear under a new major tag (`@v2`), never within
an existing one.

---

## Repo layout

```
sbomit-pipeline/
├── README.md                            ← this file
├── STANDARD-PROCEDURE.md                ← full maintainer integration reference
├── .github/workflows/
│   └── sbomit-reusable.yml              ← Option 2: the reusable pipeline (workflow_call)
├── examples/
│   ├── sbomit.yml                       ← Option 1: copy this into your repo
│   ├── caller-example.yml               ← the ~5-line Option-2 snippet
│   └── README.md
└── scripts/                             ← standalone helpers (advanced/diagnostic use)
    ├── install-witness.sh
    ├── install-sbomit.sh
    └── detect-language.sh
```

---

## Verifying an attestation

```bash
witness verify \
  --signer-public-key-path signing.pub \
  --attestations attestation.json
```

`attestation.json`, `signing.pub`, and the SBOM(s) all come from the same
workflow artifact, so each build can be audited end to end.

---

## Status

Validated end-to-end across five real projects spanning the supported
ecosystems (Go, Python, Rust). The server-first path and both integration
options have been proven in CI.

Part of the OpenSSF **SBOMit** effort.
