# SBOMit Pipeline

A drop-in GitHub Actions workflow that adds **build-time attestation + SBOM generation** to any project via a single PR.

> **Goal:** Make adopting SBOMit zero-friction for project maintainers. Add one file, open one PR, done.

---

## How a maintainer adopts it

```bash
mkdir -p .github/workflows
curl -fsSL https://raw.githubusercontent.com/Marc-cn/sbomit-pipeline/main/examples/sbomit.yml \
  -o .github/workflows/sbomit.yml
git checkout -b add-sbomit-attestation
git add .github/workflows/sbomit.yml
git commit -m "ci: add SBOMit attestation pipeline"
git push -u origin add-sbomit-attestation
gh pr create --fill
```

That's it. No secrets. No external services. No Makefile changes.

See [`examples/README.md`](examples/README.md) for full maintainer documentation.

---

## What the workflow does

On every push and pull request:

1. **Auto-detects** the project language (Go, Rust, Node, Python) from files in the repo
2. **Installs** pinned, sha256-verified binaries of `witness` (with eBPF tracing backend) and `sbomit` from this repo's releases
3. **Generates** an ephemeral ED25519 signing key for this run
4. **Runs the build** under `witness run --trace --trace-backend ebpf`, capturing every file accessed during compilation
5. **Generates** enriched SBOMs in both SPDX 2.3 and CycloneDX 1.5 from the attestation, using syft as the catalog source
6. **Uploads** `attestation.json`, both SBOMs, and the public key as a single workflow artifact

The result: a signed, reproducible record of what was actually built, and SBOMs enriched with build-time facts (resolved versions, download URLs, syscalls) that post-hoc scanners cannot infer.

---

## Repo layout

```
sbomit-pipeline/
├── README.md                      ← this file
├── examples/
│   ├── sbomit.yml                 ← the drop-in workflow (copy this to your repo)
│   └── README.md                  ← maintainer instructions
└── scripts/                       ← reusable helpers (the workflow inlines logic;
    ├── install-witness.sh           these scripts are here for advanced users
    ├── install-sbomit.sh            who want to invoke pieces standalone or
    └── detect-language.sh           verify against the inline logic)
```

---

## Releases

Each release ships pinned Linux amd64 binaries with sha256 checksums:

- `sbomit-linux-amd64` — SBOM generator
- `sbomit-linux-amd64.sha256`
- `witness-ebpf-linux-amd64` — witness with eBPF tracing backend compiled in
- `witness-ebpf-linux-amd64.sha256`

Current release: **[v0.1.0](https://github.com/Marc-cn/sbomit-pipeline/releases/tag/v0.1.0)**

The workflow pins `SBOMIT_VERSION: v0.1.0` by default. Maintainers can bump this in their copy of the workflow when new releases ship.

---

## Verifying an attestation

```bash
witness verify \
  --signer-public-key-path signing.pub \
  --attestations attestation.json
```

All three files (`attestation.json`, `signing.pub`, the SBOMs) come from the same workflow artifact, so users can audit each build end-to-end.

---

## Roadmap

- [ ] macOS and Windows runners
- [ ] arm64 binaries
- [ ] Container build support (`witness run` around `docker build`)
- [ ] Switch to upstream sbomit/witness releases once they ship eBPF-capable builds
- [ ] Composite action variant (for orgs that prefer `uses:` over copy-paste)
