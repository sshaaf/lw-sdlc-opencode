# Event-Driven Ansible (SDLC remediation)

Ansible in this repository is **only** for EDA rulebooks and event playbooks. Cluster infra (OpenCode, EDA Deployment, Nexus webhooks, secrets) is **GitOps via Argo CD** — see `gitops/argocd/applications/` and `spec.md` §1.4.

## Rulebook

| File | Purpose |
|------|---------|
| `eda-rulebooks/sdlc-remediation.yml` | Webhook source `:5000`; Nexus/vulnerability → `query-tpa.yml`; `tpa_results` → `trigger-impact-analyzer.yml`; GitLab MR → `trigger-mr-verifier.yml` |

Mount the rulebook and `playbooks/` into the EDA activation (same paths as in-repo).

## Activation extra_vars

Set on the EDA Activation (or rulebook vars file). Example shape: `eda/example-extra-vars.yml` (no secrets in git).

| Variable | Purpose |
|----------|---------|
| `tpa_url` | Trusted Profile Analyzer base URL |
| `keycloak_url` | Keycloak base (password grant for TPA uploader) |
| `keycloak_tpa_realm` | Realm (default `trusted-profile-analyzer`) |
| `tpa_uploader_username` / `tpa_uploader_password` | TPA UI user for OAuth |
| `tpa_oauth_client_id` | OAuth client (default `trustify-ui`) |
| `tpa_sbom_label` | SBOM label for `GET /api/v2/sbom?labels.name=` |
| `eda_webhook_url` | Callback URL for `query-tpa.yml` to POST `tpa_results` (same EDA listener) |
| `gitlab_url` | GitLab base for repo URLs in `affected_repos` |
| `remediation_app_gitlab_path` | e.g. `group/remediation-app` |
| `opencode_base_url` | OpenCode HTTP API (in-cluster Service) |
| `opencode_server_username` | Basic auth user (default `opencode`) |
| `opencode_server_password` | Basic auth password (Secret) |

## Webhook URLs

| Source | POST target | Notes |
|--------|-------------|--------|
| Nexus (GitOps) | `http://<eda-service>.<ns>.svc:5000/` | Component `CREATED` or custom `vulnerability_fix_published` |
| `query-tpa.yml` | `eda_webhook_url` | Body `type: tpa_results` |
| GitLab instance/project webhook | Same EDA `:5000` | MR `opened`, branch `update-artifact-*` |

Rulebook path segment must match Nexus/GitLab configured URL (often `/` on port 5000).

## AAP Controller alternative

If you run on Ansible Automation Platform instead of in-cluster EDA, replace `run_playbook` in the rulebook with `run_job_template` pointing at Job Templates that wrap the same playbooks under `playbooks/`. Extra vars mapping stays identical.

## Lightwell reference

TPA query behavior is aligned with `lightwell-demo-collateral/lw-demo-eda-rules/playbooks/query-tpa.yml`. Nexus webhook API steps are **not** in Ansible here — see `docs/reference/nexus-webhook-ansible-baseline.md` and `gitops/nexus/`.

## Local verification

```bash
ansible-playbook --syntax-check playbooks/query-tpa.yml
ansible-playbook --syntax-check playbooks/trigger-impact-analyzer.yml
ansible-playbook --syntax-check playbooks/trigger-mr-verifier.yml
ansible-playbook playbooks/verify-eda-webhook.yml  # optional curl-style checks (see playbook)
```
