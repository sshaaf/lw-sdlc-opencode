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
| `aap-credentials` | `username`, `password` | EDA bootstrap Job → AAP API |
| `eda-activation-secrets` | `tpa_uploader_password`, `opencode_server_password` | EDA activation `extra_var` (bootstrap Job) |

## EDA / AAP (activation extra_var)

| Credential | Consumer |
|------------|----------|
Passwords for EDA are injected by [`../sdlc-eda/bootstrap-job.yaml`](../sdlc-eda/bootstrap-job.yaml) into activation `extra_var` (or set manually in AAP UI). Non-secret fields come from `sdlc-cluster-config`.

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
