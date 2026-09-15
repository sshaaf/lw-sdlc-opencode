# GitOps: Nexus (Lightwell repos + EDA webhooks)

Configures an **existing** Nexus instance (for example `lightwell-nexus` from the Lightwell Ansible stack). **JFrog Artifactory is not used** for EDA triggers—Artifactory OSS lacks repository webhooks (Enterprise feature); Nexus webhooks are the chosen ingress ([`docs/reference/infra-platform-stack.md`](../../docs/reference/infra-platform-stack.md)).

This directory does **not** deploy the Nexus StatefulSet; it runs an idempotent **PostSync Job** that mirrors:

`lightwell-demo-collateral/ansible/playbooks/tasks/deploy-nexus-complete.yml`

| Step | Ansible task | GitOps |
|------|----------------|--------|
| Wait for API | `Wait for Nexus API` | `nexus-reconcile.py` |
| Anonymous access | `Enable anonymous access` | same (best-effort) |
| Maven proxies | `Create Maven proxy repositories` | `lightwell-repositories.json` |
| Maven hosted | `Create Maven hosted repositories` | same |
| EDA webhooks | ExtDirect `webhook.repository` | same (validated + remediated) |

## Argo CD

- Application: `gitops/argocd/applications/nexus-webhooks.yaml`
- Build: **Kustomize** (`kustomization.yaml`) — ConfigMaps from `nexus-reconcile.py` + `lightwell-repositories.json`, Job `reconcile-job.yaml`

## Prerequisites

1. [`../base/cluster-config/cluster-config.yaml`](../base/cluster-config/cluster-config.yaml) synced as `sdlc-cluster-config` in `sdlc-control-plane`.
2. Secrets per [`../secrets/README.md`](../secrets/README.md): `nexus-admin`, `redhat-packages-credentials`.
3. EDA webhook Service up before webhooks are created (`EDA_WEBHOOK_URL` in cluster config).

Default webhook targets match Ansible: **`redhat-packages-validated`** and **`redhat-packages-remediated`**.

## Repository catalog

[`lightwell-repositories.json`](lightwell-repositories.json) — same list as `ansible/inventory/hosts.yml` → `nexus_repositories`:

- Proxies: `redhat-packages-validated`, `redhat-packages-remediated`, `maven-central`
- Hosted: `maven-releases`

## Local dry-run

```bash
export NEXUS_URL=https://nexus.example.com
export NEXUS_ADMIN_PASSWORD=...
export LIGHTWELL_NETWORK_USERNAME=...
export LIGHTWELL_NETWORK_PASSWORD=...
export EDA_WEBHOOK_URL=http://127.0.0.1:5000/
python3 gitops/nexus/nexus-reconcile.py
```

## Reference

- [`docs/reference/nexus-webhook-ansible-baseline.md`](../../docs/reference/nexus-webhook-ansible-baseline.md)
