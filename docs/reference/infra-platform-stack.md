# Shared infrastructure (pre-installed)

When this demo runs on the **managed OpenShift environment**, the following are **already deployed and operated by the platform team**. This repository does **not** install or upgrade them.

| Component | Role in SDLC demo |
|-----------|-------------------|
| **Keycloak SSO** | OpenShift login; TPA OAuth (password grant for automation user in `playbooks/tasks/get-tpa-token.yml`) |
| **Ansible Automation Platform** | Controller + **EDA** — hosts activations; consumes `eda-rulebooks/` + `playbooks/` from git |
| **RHTAS** | Signing / attestation (future: post-remediation attestations; not wired in v1 flow) |
| **RHTPA** | SBOM + vulnerability analysis — `query-tpa.yml` calls RHTPA HTTP API |
| **GitLab** | SCM; MR webhooks → EDA; GitLab MCP from OpenCode |
| **JFrog Artifactory** | May be present as a platform artifact proxy; **not used for this demo’s EDA trigger** — see below |
| **Jenkins** | May be on the platform; **not used** in this demo (no Jenkins-triggered EDA or verify jobs) |
| **SonarQube** | Quality gates (optional future integration with `mr-verifier`) |
| **Red Hat Quay** | Platform container registry (may host `sdlc-opencode` image in addition to `quay.io/sshaaf/sdlc-opencode` from GitHub CI) |
| **OpenShift GitOps (Argo CD)** | Delivers **lightwell-workshop** `bootstrap-infra` / `bootstrap-tenant` (not overlays under this repo’s `gitops/`) |

## What this repo still owns (SCM + image)

| Deliverable | Where |
|-------------|--------|
| OpenCode image | `container/`, GitHub Actions → Quay (or promote to platform Quay) |
| OpenCode Deployment / secrets / Nexus webhooks / EDA bootstrap | **`lightwell-workshop`** `automation/gitops/bootstrap-tenant` (see `gitops/DEPRECATED.md`) |
| EDA rulebook + event playbooks | `eda-rulebooks/sdlc-remediation.yml`, `playbooks/` — imported by tenant EDA project SCM URL |
| Tenant integration vars | ConfigMap `tenant-integration` from bootstrap-tenant |
| Agent skills / `opencode.json` | Baked in image via `.opencode/` |
| Demo A smoke | `docs/DEMO-A-SMOKE.md` |

## Artifact ingress: Nexus (chosen), not Artifactory

**Decision:** We do **not** use **JFrog Artifactory** to fire the remediation loop. **Artifactory OSS does not provide repository webhook capabilities** (webhooks are an Enterprise / paid feature). Polling Artifactory or relying on OSS-only APIs is out of scope for the event-driven design.

**Chosen path:** **Sonatype Nexus** repository webhooks → EDA, same as the Lightwell collateral demo:

| Piece | Location |
|-------|----------|
| Lightwell Maven proxies + hosted repos | `gitops/nexus/lightwell-repositories.json`, reconcile Job |
| Webhooks (`component` → EDA URL) | `gitops/nexus/nexus-reconcile.py` (ExtDirect), targets `redhat-packages-validated` / `redhat-packages-remediated` |
| EDA rules | `eda-rulebooks/sdlc-remediation.yml` — Nexus `CREATED` or `vulnerability_fix_published` |

Nexus may be deployed alongside the platform stack (dedicated namespace or lab instance), not replaced by Artifactory for this workflow. Artifactory can remain available for other teams without participating in EDA ingress.

Event ingress for artifacts is **Nexus webhooks only** (plus GitLab MR webhooks for the verifier). We do not use Jenkins to POST synthetic events to EDA.

## Integration checklist (first login to environment)

1. Collect access per [`gitops/config/integration-catalog.yaml`](../../gitops/config/integration-catalog.yaml).
2. Fill [`gitops/base/cluster-config/cluster-config.yaml`](../../gitops/base/cluster-config/cluster-config.yaml) in git (PR); wire [`gitops/secrets/`](../../gitops/secrets/README.md) via ESO.
3. Argo CD: sync `sdlc-config` → secrets → `sdlc-control-plane`, `nexus-webhooks`, `sdlc-eda` reference.
4. AAP EDA activation extra_vars from `sdlc-cluster-config` + credential passwords (see `gitops/sdlc-eda/`).
5. GitLab webhooks → `GITLAB_WEBHOOK_TARGET_URL` / EDA route; Nexus reconcile Job → EDA (`gitops/nexus/`).

## Out of scope for v1 OpenCode loop

- Installing AAP, EDA operator, RHTPA, GitLab, Artifactory, Jenkins, SonarQube, Quay, Keycloak (platform team); this demo does not integrate with Artifactory or Jenkins
- Replacing platform SSO or registry policies
