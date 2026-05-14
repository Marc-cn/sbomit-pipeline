# SBOMit Pipeline

A drop-in GitHub Actions workflow that adds **build-time attestation + SBOM generation** to any project via a single PR.

## What it does

On every push or pull request, this workflow:
1. Auto-detects the project language (Go, Python, Node, Rust)
2. Runs the build under `witness --trace --trace-backend ebpf` to capture a signed attestation of every file accessed during the build
3. Generates enriched SBOMs in SPDX 2.3 and CycloneDX 1.5 from the attestation
4. Uploads `attestation.json`, `sbom.spdx.json`, `sbom.cdx.json`, and the ephemeral public key as workflow artifacts

No external services, no secrets required.

## Quick start

Copy [`examples/sbomit.yml`](examples/sbomit.yml) to `.github/workflows/sbomit.yml` in your repo and open a PR.

## Releases

Each release ships pinned binaries:
- `sbomit-linux-amd64` — SBOM generator
- `witness-ebpf-linux-amd64` — attestation tool with eBPF tracing backend

Both with `.sha256` checksums.
