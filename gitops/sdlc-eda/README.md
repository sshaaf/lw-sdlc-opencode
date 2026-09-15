# EDA rulebooks — configured and ready (AAP)

Platform **AAP + EDA** is pre-installed. This path **loads** content from this git repository into an EDA **project**, syncs SCM, and enables an **activation** on `eda-rulebooks/sdlc-remediation.yml` with `extra_var` from cluster config + secrets.

## SCM layout (repo root)

```
eda-rulebooks/sdlc-remediation.yml
playbooks/
```

Set `EDA_PROJECT_SCM_URL` in [`../base/cluster-config/cluster-config.yaml`](../base/cluster-config/cluster-config.yaml) to this repo (HTTPS). AAP must reach the URL; use a GitLab mirror + credential if GitHub is blocked.

## GitOps bootstrap Job

| Resource | Role |
|----------|------|
| `bootstrap-aap-eda.py` | Idempotent AAP API: project → sync → decision env → activation + `extra_var` |
| `bootstrap-job.yaml` | PostSync Job (wave `0` — before Nexus webhook reconcile) |

### Prerequisites

1. Filled `sdlc-cluster-config` (especially `AAP_CONTROLLER_URL`, `EDA_*`, TPA/GitLab/OpenCode URLs).
2. Secrets:
   - `aap-credentials` — `username`, `password` (AAP admin or automation user)
   - `eda-activation-secrets` — `tpa_uploader_password`, `opencode_server_password`

See [`../secrets/README.md`](../secrets/README.md).

### Argo CD

Application: `gitops/argocd/applications/sdlc-eda.yaml` (destination `sdlc-control-plane`).

**Skip bootstrap** until config and secrets exist — set `SKIP_EDA_BOOTSTRAP=true` on the Job via cluster config patch, or do not sync this app until ready.

## Manual bootstrap (no Job)

```bash
export AAP_CONTROLLER_URL=... AAP_USERNAME=... AAP_PASSWORD=...
# Map sdlc-cluster-config keys to env (see bootstrap-job.yaml)
export TPA_UPLOADER_PASSWORD=... OPENCODE_SERVER_PASSWORD=...
python3 gitops/sdlc-eda/bootstrap-aap-eda.py
```

## Acceptance

- AAP → Event-Driven Ansible → Activations: **`sdlc-remediation`** status **running**
- Rulebook: **`sdlc-remediation.yml`**
- Project import_state: **completed**
- Webhook URL matches `EDA_WEBHOOK_URL` in cluster config

## Local rulebook check

```bash
ansible-playbook --syntax-check playbooks/query-tpa.yml
# Optional: ansible-rulebook --rulebook eda-rulebooks/sdlc-remediation.yml --check
```

Reference: Lightwell `deploy-eda-complete.yml` / `deploy-aap-remediation.yml` (activation PATCH with `extra_var`).
