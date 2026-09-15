# SDLC agent remediation demo

Autonomous software supply chain remediation using OpenCode on OpenShift. See **[spec.md](spec.md)** for the full system design.

## Container image CI

Workflow: [`.github/workflows/ci-opencode-image.yml`](.github/workflows/ci-opencode-image.yml)

| Job | Purpose |
|-----|---------|
| `build` | Docker build (`container/Dockerfile`), tag `sdlc-opencode:ci`, upload artifact |
| `test` | Load image, run [`container/scripts/smoke-test.sh`](container/scripts/smoke-test.sh) |
| `publish` | Push to Quay (skipped on pull requests) |
| `release` | GitHub Release on `v*` tags with image coordinates |

### GitHub configuration

| Name | Type | Example |
|------|------|---------|
| `QUAY_IMAGE_NAME` | Variable (optional) | `quay.io/sshaaf/sdlc-opencode` (workflow default) |
| `QUAY_USERNAME` | Secret | Quay robot or user |
| `QUAY_PASSWORD` | Secret | Robot token |

### Local build and smoke test

The Dockerfile copies `opencode.json` and `.opencode/` from the **repo root**. The final `.` is required (without it, Podman/Docker use `container/` as context and `COPY` fails).

```bash
# from repository root
docker build -f container/Dockerfile -t sdlc-opencode:ci .

# or
./container/build.sh

bash container/scripts/smoke-test.sh sdlc-opencode:ci
```

### OpenShift image after CI

After a successful run on `main`, use the immutable tag from Quay:

```text
quay.io/sshaaf/sdlc-opencode:sha-<short-git-sha>
```

Update [`openshift/deployment.yaml`](openshift/deployment.yaml) `image:` (or your Kustomize/Helm overlay). Prefer `sha-*` or a semver tag from `v*` releases—not `latest` alone in production.

### Manual verification (post-setup)

1. Open a PR to `main` and confirm **build** + **test** pass without **publish**.
2. Configure Quay secrets, merge to `main`, confirm push to Quay.
3. Push git tag `v0.1.0` and confirm GitHub Release + Quay semver tags.
