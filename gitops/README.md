# GitOps layout

Argo CD on the cluster syncs paths under this directory. **Fill integration data in git before turning on workloads.**

## Start here

| Step | Action |
|------|--------|
| 1 | Read [`config/integration-catalog.yaml`](config/integration-catalog.yaml) — what to request from platform/ops |
| 2 | Edit [`base/cluster-config/cluster-config.yaml`](base/cluster-config/cluster-config.yaml) — all non-secret URLs and names (`CHANGE_ME`) |
| 3 | Wire [`secrets/README.md`](secrets/README.md) — ExternalSecrets to your secret store |
| 4 | Sync Argo Applications in order below |

## Argo CD Applications

| Application | Path | Purpose |
|-------------|------|---------|
| `sdlc-config` | `gitops/config` | ConfigMap `sdlc-cluster-config` (optional early sync) |
| `sdlc-control-plane` | `gitops/sdlc-control-plane` | Namespace, config, OpenCode Deployment |
| `sdlc-eda` | `gitops/sdlc-eda` | EDA activation reference ConfigMap |
| `nexus-webhooks` | `gitops/nexus` | Lightwell repos + Nexus → EDA webhooks Job |

Manifests: [`argocd/applications/`](argocd/applications/).

**Sync order:** `sdlc-config` (or `sdlc-control-plane` which includes config) → **secrets** (manual/ESO) → `sdlc-control-plane` → `nexus-webhooks` → configure AAP EDA activation using `sdlc-eda` docs.

## Single source of truth

- **Non-secret:** `gitops/base/cluster-config/cluster-config.yaml`
- **Secret:** cluster Secret / ESO — names in `gitops/secrets/`
- **Not in scope:** Artifactory, Jenkins (see [`docs/reference/infra-platform-stack.md`](../docs/reference/infra-platform-stack.md))
