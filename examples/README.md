# Drop-in workflow for maintainers

## Quick start

```bash
# From the root of your repo
mkdir -p .github/workflows
curl -fsSL https://raw.githubusercontent.com/Marc-cn/sbomit-pipeline/main/examples/sbomit.yml \
  -o .github/workflows/sbomit.yml

git checkout -b add-sbomit-attestation
git add .github/workflows/sbomit.yml
git commit -m "ci: add SBOMit attestation pipeline"
git push -u origin add-sbomit-attestation
gh pr create --fill
```

That's the entire integration. No secrets to configure, no external service to set up, no Makefile changes.

## What you get

On every push or PR, the workflow uploads a single artifact named `sbomit-<sha>` containing:

| File                 | What it is                                                          |
|----------------------|---------------------------------------------------------------------|
| `attestation.json`   | Signed witness attestation — every file read/written during build   |
| `sbom/sbom.spdx.json`| SPDX 2.3 SBOM, enriched with attestation data, catalog via syft     |
| `sbom/sbom.cdx.json` | CycloneDX 1.5 SBOM, same content                                    |
| `signing.pub`        | Ephemeral ED25519 public key for verifying the attestation          |

## Supported languages (auto-detected)

| Detected file                          | Language | Default build command                              |
|----------------------------------------|----------|----------------------------------------------------|
| `go.mod`                               | Go       | `go build -trimpath ./...`                         |
| `Cargo.toml`                           | Rust     | `cargo build --release --locked`                   |
| `package.json` (with `"build"` script) | Node     | `npm ci && npm run build`                          |
| `package.json` (no `"build"`)          | Node     | `npm ci`                                           |
| `pyproject.toml` with `[build-system]` | Python   | `pip install build && python -m build --wheel`     |
| `requirements.txt`                     | Python   | `pip install -r requirements.txt`                  |
| `setup.py` / `setup.cfg`               | Python   | `pip install .`                                    |

## Customizing

If the auto-detected command doesn't match your project, set `BUILD_COMMAND` near the top of the workflow:

```yaml
env:
  BUILD_COMMAND: "make build-no-tests"     # whatever your project uses
  SBOMIT_VERSION: "v0.1.0"
```

## Verifying an attestation

Anyone (you, your users, downstream consumers) can verify a release attestation locally:

```bash
# Download both files from the workflow run artifact
witness verify \
  --signer-public-key-path signing.pub \
  --attestations attestation.json \
  --policy policy.yaml         # optional: enforce policy constraints
```

## Repo

Source and releases: <https://github.com/Marc-cn/sbomit-pipeline>
