# SBOMit Pipeline

Build-time **attestation + SBOM generation** for any GitHub project.

The pipeline runs your build under [`witness`](https://github.com/in-toto/witness),
producing a signed, tamper-evident record of what the build *actually did* —
every file accessed, process spawned, and (where supported) network call — then
derives an enriched SPDX 2.3 SBOM from that evidence. SBOMs built this way
reflect the real build, not a manifest's claims about it.

> **Goal:** zero-friction adoption for maintainers, with a security posture
> consistent with what a supply-chain tool should model.

---

## Integrate it (pick one)

All three options deliver the **identical, validated pipeline**.

| Option | What you do | Dependency | Best for |
|--------|-------------|------------|----------|
| **1. Generator** *(recommended)* | review + run one command; a self-contained workflow is written into your repo | none (you own the file) | full ownership, no runtime dependency |
| **2. Reusable workflow** | add a ~5-line workflow referencing `@v1` | `@v1` (auto-updates) | hands-off compatible updates |
| **3. Manual copy** | copy `examples/sbomit.yml` in by hand | none | zero tooling |

Full reference: **[`STANDARD-PROCEDURE.md`](STANDARD-PROCEDURE.md)**.

### Option 1 — the generator (recommended)

From the root of your git repository:

```bash
# 1. Download the integration script (pinned release)
curl -fsSLO https://raw.githubusercontent.com/Marc-cn/sbomit-pipeline/v1.0.0/sbomit-integrate.sh

# 2. REVIEW it (short, documented, performs no privileged actions)
less sbomit-integrate.sh

# 3. Run it — local-only:
sh sbomit-integrate.sh
#    ...or also wire a central inventory server:
sh sbomit-integrate.sh https://your-sbomit-server.example.org
```

The script fetches the standalone workflow from a **pinned tag**, verifies it
against a **published SHA-256** before writing anything (aborts on mismatch),
and writes `.github/workflows/sbomit.yml`. It is meant to be downloaded and
read before running — not piped from the network into a shell. If you pass a
server URL it sets the non-secret `SBOMIT_SERVER` repository variable and
**prints** the command for you to set the `SBOMIT_TOKEN` secret yourself; the
script never handles your token value.

### Option 2 — the reusable workflow

Add `.github/workflows/sbomit.yml`:

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

All logic lives here and is pinned by `@v1`; you get backward-compatible fixes
automatically. Override a non-standard build with
`with: { build_command: "make just-install" }`.

### Option 3 — manual copy

Copy [`examples/sbomit.yml`](examples/sbomit.yml) directly into
`.github/workflows/sbomit.yml`. Same self-contained file Option 1 installs,
copied by hand. You own it; no automatic updates.

---

## What the workflow does

On every push and pull request:

1. **Auto-detects** the project language (Go, Rust, Node, Python).
2. **Installs tooling** (pinned, checksum-verified — never `curl | sh`):
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
vulnerable library?". This is strictly opt-in; without both set, the code path
does not run and there is zero overhead. The server builds the SBOM from the
attestation itself and never accesses your source.

---

## Versioning

Releases follow the GitHub Actions convention:

- **`@v1`** — latest backward-compatible `v1.x`; recommended for most projects.
- **`@v1.0.0`** — immutable exact version; use for strict reproducibility.

Breaking changes only ever appear under a new major tag (`@v2`), never within
an existing one.

---

## Repo layout

```
sbomit-pipeline/
├── README.md                            ← this file
├── STANDARD-PROCEDURE.md                ← full maintainer integration reference
├── sbomit-integrate.sh                  ← Option 1: self-serve generator
├── .github/workflows/
│   └── sbomit-reusable.yml              ← Option 2: the reusable pipeline (workflow_call)
├── examples/
│   ├── sbomit.yml                       ← Option 3: standalone copy (self-contained)
│   ├── sbomit.yml.sha256                ← integrity companion (verified by the generator)
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

## Security posture

- **No piped remote execution.** Every tool is downloaded at a pinned version
  and SHA-256-verified before it runs. The generator is download-and-review,
  not `curl | sh`.
- **No secrets in the default path.** Central inventory is strictly opt-in.
- **Fail-safe SBOM acceptance.** Server responses are validated by HTTP status
  and SPDX content; anything invalid falls back to local generation rather
  than shipping an empty SBOM.

---

## Status

Validated end-to-end across five real projects spanning the supported
ecosystems (Go, Python, Rust). The server-first path and all three integration
options have been proven in CI.

Part of the OpenSSF **SBOMit** effort.
