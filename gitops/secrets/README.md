# Secrets contract (GitOps)

**Never commit real credentials.** Store values in your cluster secret backend (Vault, OpenShift secrets, cloud SM) and sync with **External Secrets Operator** or Sealed Secrets.

Namespace for OpenCode: **`sdlc-control-plane`**. Nexus reconcile Job runs in the Argo destination namespace for `nexus-webhooks` (default `sdlc-control-plane` unless you override).

## Required secrets

| Secret name | Keys | Used by |
|-------------|------|---------|
| `opencode-server` | `password` | OpenCode Deployment (`OPENCODE_SERVER_PASSWORD`) |
| `gitlab-credentials` | `url`, `username`, `password` | OpenCode; optional `token` if PAT pre-provisioned |
| `opencode-llm` | `api_key` | OpenCode LLM provider env (name per provider docs) |
| `nexus-admin` | `password` | Nexus reconcile Job |
| `redhat-packages-credentials` | `username`, `password` | Nexus proxy repos (Lightwell Network) |

## EDA / AAP (not always Kubernetes Secrets)

| Credential | Consumer |
|------------|----------|
| `tpa_uploader_password` | EDA activation extra_vars / AAP credential |
| `opencode_server_password` | EDA activation extra_vars |

Bind these in AAP to match [`../base/cluster-config/cluster-config.yaml`](../base/cluster-config/cluster-config.yaml) non-secret fields.

## Optional

| Secret name | Keys | Used by |
|-------------|------|---------|
| `quay-pull-secret` | `.dockerconfigjson` | `imagePullSecrets` on OpenCode if registry is private |

## Apply examples

Copy and adapt `*.externalsecret.example.yaml` to your `ClusterSecretStore` / `SecretStore` name, then apply in the target namespace **before** or with wave `-1` relative to workloads:

```bash
kubectl apply -f gitops/secrets/overlays/managed/  # after customizing
```

Examples use placeholder `storeRef.name: platform-secret-store` — replace with your ESO store.
