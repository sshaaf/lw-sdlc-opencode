# EDA / AAP integration (config reference)

EDA is **pre-installed** on the platform. This directory does not deploy the EDA operator.

## GitOps role

- [`configmap-activation-reference.yaml`](configmap-activation-reference.yaml) — documents how `sdlc-cluster-config` keys map to EDA `extra_vars`.
- Rulebook and playbooks live in repo root: `eda-rulebooks/`, `playbooks/`.

## Operator steps

1. Ensure [`../base/cluster-config/cluster-config.yaml`](../base/cluster-config/cluster-config.yaml) is filled and synced (`sdlc-config` or `sdlc-control-plane` Application).
2. In AAP, create/update **EDA activation** `EDA_ACTIVATION_NAME` with rulebook from this git repository.
3. Set activation extra_vars from `sdlc-cluster-config` + AAP credentials for passwords (`tpa_uploader_password`, `opencode_server_password`).
4. Confirm webhook URL: `EDA_WEBHOOK_URL` (in-cluster) and `EDA_WEBHOOK_ROUTE_URL` / `GITLAB_WEBHOOK_TARGET_URL` for external callers.

See also [`eda/README.md`](../../eda/README.md) and [`eda/example-extra-vars.yml`](../../eda/example-extra-vars.yml) (local/AAP template; prefer GitOps config as source of truth).
