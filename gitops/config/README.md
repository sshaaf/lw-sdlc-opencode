# Cluster integration config (GitOps)

All **non-secret** endpoints and names needed to wire the remediation loop live in **`cluster-config.yaml`**. Fill every `CHANGE_ME` (and `sha-REPLACE_ME` image) **before** syncing dependent Argo CD Applications.

## Files

| File | Purpose |
|------|---------|
| [`../base/cluster-config/cluster-config.yaml`](../base/cluster-config/cluster-config.yaml) | ConfigMap `sdlc-cluster-config` — URLs, realms, repo paths, image tag |
| [`integration-catalog.yaml`](integration-catalog.yaml) | Inventory: who provides each value, which Secret keys apply |
| [`../secrets/README.md`](../secrets/README.md) | Secret names and ExternalSecret examples |

## Workflow

1. **Platform / ops** — Hand off URLs and credentials per [`integration-catalog.yaml`](integration-catalog.yaml).
2. **Edit** `cluster-config.yaml` in git (reviewable PR).
3. **Create Secrets** in cluster (`gitops/secrets/`) via External Secrets Operator or sealed secrets — not in this ConfigMap.
4. **Argo CD** — Sync `sdlc-config` Application first, then `sdlc-control-plane`, `nexus-webhooks`.
5. **AAP EDA** — Map the same keys to activation extra_vars (see [`../sdlc-eda/README.md`](../sdlc-eda/README.md)).

## EDA / AAP mapping

| ConfigMap key | EDA extra_var |
|---------------|---------------|
| `TPA_URL` | `tpa_url` |
| `KEYCLOAK_URL` | `keycloak_url` |
| `KEYCLOAK_TPA_REALM` | `keycloak_tpa_realm` |
| `TPA_OAUTH_CLIENT_ID` | `tpa_oauth_client_id` |
| `TPA_UPLOADER_USERNAME` | `tpa_uploader_username` |
| `TPA_SBOM_LABEL` | `tpa_sbom_label` |
| `EDA_WEBHOOK_URL` | `eda_webhook_url` |
| `GITLAB_URL` | `gitlab_url` |
| `REMEDIATION_APP_GITLAB_PATH` | `remediation_app_gitlab_path` |
| `OPENCODE_BASE_URL` | `opencode_base_url` |
| `OPENCODE_SERVER_USERNAME` | `opencode_server_username` |
| `VALIDATE_CERTS` | `validate_certs` |

Passwords: `tpa_uploader_password`, `opencode_server_password` → Secrets only.

## Nexus Job mapping

| ConfigMap key | Nexus reconcile env |
|---------------|---------------------|
| `NEXUS_URL` | `NEXUS_URL` |
| `EDA_WEBHOOK_URL` | `EDA_WEBHOOK_URL` |
| `NEXUS_WEBHOOK_REPOSITORIES` | `NEXUS_WEBHOOK_REPOSITORIES` |
| `SKIP_REPOSITORY_SETUP` | `SKIP_REPOSITORY_SETUP` |
| `SKIP_WEBHOOK_SETUP` | `SKIP_WEBHOOK_SETUP` |
