# SDLC agent remediation demo

Autonomous software supply chain remediation using OpenCode on OpenShift. See **[spec.md](spec.md)** for the full system design.

GitLab auth uses **username + password** in cluster Secrets; a PAT is **derived at runtime** when MCP needs it—see [.opencode/reference/gitlab-credentials.md](.opencode/reference/gitlab-credentials.md).

**Agent triggers (current):** Nexus and GitLab **webhooks → Ansible EDA** → OpenCode — see [spec.md §3](spec.md). **Infra:** Argo CD GitOps only (`gitops/`, `openshift/`); Ansible is **not** used to deploy the cluster stack ([spec.md §1.4](spec.md)). **Future option:** GitLab CI in [gitlab/](gitlab/README.md).

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

Repository **`sshaaf/sdlc-opencode`** already has placeholders; replace them with real Quay credentials before relying on **publish**:

```bash
gh variable set QUAY_IMAGE_NAME --body "quay.io/sshaaf/sdlc-opencode"
gh secret set QUAY_USERNAME --body "YOUR_QUAY_ROBOT_OR_USER"
gh secret set QUAY_PASSWORD --body "YOUR_QUAY_TOKEN"
```

Verify (names only; values are hidden):

```bash
gh secret list
gh variable list
```

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
