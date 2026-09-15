# GitOps: Nexus → EDA webhooks

Nexus **repository webhook capabilities** are **platform configuration** and MUST be applied via **Argo CD**, not Ansible EDA playbooks or one-off `ansible-playbook deploy`.

## Argo ownership

- Application (example): `gitops/argocd/applications/nexus-webhooks.yaml` → syncs manifests in this directory.
- Implementation: PreSync/PostSync Job, Operator wrapper, or pinned container that runs the idempotent API flow in [`docs/reference/nexus-webhook-ansible-baseline.md`](../../docs/reference/nexus-webhook-ansible-baseline.md).

## Required inputs (from cluster / ESO, not git)

| Variable | Purpose |
|----------|---------|
| `NEXUS_URL` | Nexus base URL |
| `NEXUS_ADMIN_PASSWORD` | Admin basic auth for ExtDirect |
| `EDA_WEBHOOK_URL` | EDA listener (cluster DNS), e.g. `http://sdlc-eda-webhook.sdlc-control-plane.svc:5000/` |
| `NEXUS_WEBHOOK_REPOSITORIES` | JSON/YAML list of hosted repo names to attach `component` events |

## EDA side (separate Application)

EDA rulebook Deployment/Activation is its own GitOps Application; Nexus webhooks only **point** at the EDA URL once that Service exists.
