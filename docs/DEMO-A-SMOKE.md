# Demo depth A — blast radius + single app smoke

Canonical change: [`openspec/changes/sdlc-blast-radius-demo-a/`](../openspec/changes/sdlc-blast-radius-demo-a/).

## Story

Lightwell publishes a remediating package → **Nexus** webhook → **EDA** → **TPA blast radius** (1 app) → OpenCode **`impact-analyzer`** → GitLab MR → **`mr-verifier`** (ephemeral OpenShift). No promote-to-prod in A.

## App

| Item | Value |
|------|--------|
| Source | `lightwell-demo-collateral/apps/lw-demo-help-app` |
| Maven | `com.redhat.tpa:help-im-vulnerable:1.0.0` |
| Tenant GitLab | `lightwell/lw-demo-help-app-<guid>` |
| TPA SBOM label | `sdlc-demo-<guid>` (bootstrap-tenant seed) |

Seed GitLab after tenant create:

The tenant chart Job **`create-gitlab-tenant`** seeds help-app sources automatically (`gitlab.helpAppSeed.enabled`, default `true`) from bundled `files/help-app-seed.tar.gz`.

Optional manual fallback (laptop):

```bash
export GITLAB_TOKEN=<root-or-maintainer-pat>
./scripts/seed-help-app-to-gitlab.sh <guid>
```

## Smoke GAV (publish into remediated repo)

Prefer a Lightwell remediating version that matches a help-app dependency. Example (adjust to your Lightwell Network feed):

| Vulnerable (in app / SBOM) | Publish to Nexus repo |
|----------------------------|------------------------|
| `com.fasterxml.woodstox:woodstox-core:6.0.3` | `redhat-packages-remediated-<guid>` with remediating version e.g. `6.0.3.rhlw-00001` (exact tag from Lightwell) |
| `org.json:json:20220320` | remediating `*.rhlw-*` per advisory |

Nexus component `CREATED` on that repo must hit EDA (`EDA_WEBHOOK_URL` / Route).

## Expected EDA chain

1. `query-tpa.yml` → `tpa_results` with `blast_radius.count: 1`, `affected_repos[0].gitlab_path` = help-app path  
2. `trigger-impact-analyzer.yml` → OpenCode session (skipped if `count: 0`)  
3. MR branch `update-artifact-*` on help-app  
4. GitLab MR webhook → `mr-verifier` → Job + ephemeral NS + MR note  

Negative: publish an unrelated GAV → `count: 0` → no OpenCode impact session.

## GitOps

Deploy via **`lightwell-workshop`** `bootstrap-infra` + `bootstrap-tenant` only. This repo supplies SCM (rulebooks/playbooks/agents/image). See [`gitops/DEPRECATED.md`](../gitops/DEPRECATED.md).

GitLab mutations use **`python3 /app/scripts/gitlab_api.py`** (PAT), not GitLab MCP (requires GitLab ≥18.6).
