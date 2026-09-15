# SDLC agent remediation demo

Autonomous software supply chain remediation using OpenCode on OpenShift. See **[spec.md](spec.md)** for the full system design.

GitLab auth uses **username + password** in cluster Secrets; a PAT is **derived at runtime** when MCP needs it—see [.opencode/reference/gitlab-credentials.md](.opencode/reference/gitlab-credentials.md).

**Agent triggers (current):** Nexus and GitLab **webhooks → Ansible EDA** → OpenCode — see [spec.md §3](spec.md). **Infra:** Argo CD GitOps ([`gitops/`](gitops/README.md)); Ansible is only for EDA rulebooks and event playbooks ([spec.md §1.4](spec.md)). **Not used:** Artifactory (OSS webhooks), Jenkins. **Future option:** GitLab CI in [gitlab/](gitlab/README.md).

## Demo flow (Nexus webhook onwards)

Artifact ingress is **Sonatype Nexus** repository webhooks (Lightwell `redhat-packages-*` repos), not Artifactory. EDA runs [`eda-rulebooks/sdlc-remediation.yml`](eda-rulebooks/sdlc-remediation.yml); playbooks live under [`playbooks/`](playbooks/).

```mermaid
sequenceDiagram
  participant Nexus
  participant EDA as Ansible EDA
  participant TPA as RHTPA
  participant OC as OpenCode
  participant GL as GitLab

  Note over Nexus,EDA: Phase 1 — impact discovery
  Nexus->>EDA: Webhook component CREATED (:5000)
  EDA->>TPA: query-tpa.yml (SBOM API + Keycloak token)
  EDA->>EDA: POST tpa_results (callback)
  Note over EDA,OC: Phase 2 — remediation MR
  EDA->>OC: trigger-impact-analyzer (impact-analyzer)
  OC->>GL: MCP branch, bump deps, open MR (update-artifact-*)

  Note over GL,OC: Phase 3 — verify MR
  GL->>EDA: MR webhook opened (update-artifact-*)
  EDA->>OC: trigger-mr-verifier (mr-verifier)
  OC->>GL: MCP MR note (build / ephemeral deploy summary)
```

| Step | What happens |
|------|----------------|
| 1 | Nexus publishes to **validated** or **remediated** repo; webhook hits **EDA** (`EDA_WEBHOOK_URL`). |
| 2 | Rule matches `CREATED` or `vulnerability_fix_published` → **`playbooks/query-tpa.yml`**. |
| 3 | Playbook queries **RHTPA**, then POSTs **`tpa_results`** back to EDA (`eda_webhook_url`). |
| 4 | Rule matches `tpa_results` → **`playbooks/trigger-impact-analyzer.yml`** → OpenCode **`impact-analyzer`** / skill **`dependency-impact-remediation`**. |
| 5 | Agent opens a GitLab **MR** on branch **`update-artifact-*`** with handoff JSON in the description. |
| 6 | GitLab **MR webhook** → EDA → **`playbooks/trigger-mr-verifier.yml`** → **`mr-verifier`** / **`mr-verify-ephemeral`**. |
| 7 | Agent runs isolated verify (Job/Pipeline) and optional ephemeral deploy; posts results on the MR. |

**GitOps prep (before the loop runs):** fill [`gitops/base/cluster-config/cluster-config.yaml`](gitops/base/cluster-config/cluster-config.yaml), wire [`gitops/secrets/`](gitops/secrets/README.md), sync **`sdlc-eda`** (rulebook activation), **`nexus-webhooks`**, **`sdlc-control-plane`**. See [`gitops/README.md`](gitops/README.md) and [`docs/reference/infra-platform-stack.md`](docs/reference/infra-platform-stack.md).

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

Set `OPENCODE_IMAGE` in [`gitops/base/cluster-config/cluster-config.yaml`](gitops/base/cluster-config/cluster-config.yaml) (or your overlay). Prefer `sha-*` or a semver tag from `v*` releases—not `latest` alone in production.

### Manual verification (post-setup)

1. Open a PR to `main` and confirm **build** + **test** pass without **publish**.
2. Configure Quay secrets, merge to `main`, confirm push to Quay.
3. Push git tag `v0.1.0` and confirm GitHub Release + Quay semver tags.
