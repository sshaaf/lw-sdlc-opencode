# Nexus repository webhooks — Ansible baseline (GitOps port reference)

**Status:** Historical/ansible reference for **GitOps implementation** in `gitops/nexus/`. Do not run this as ad-hoc cluster deploy; Argo CD owns Nexus webhook configuration going forward.

## Source

Behavior is documented from the Lightwell demo Ansible task  
`lightwell-demo-collateral/ansible/playbooks/tasks/deploy-nexus-complete.yml` (ExtDirect webhook capabilities).

## Preconditions

1. Nexus is reachable at `nexus_url` (admin credentials in a Secret, not in git).
2. EDA webhook Service exists in cluster (e.g. `http://<eda-service>.<namespace>.svc.cluster.local:5000/`).
3. Maven **proxy** repositories `redhat-packages-validated` and `redhat-packages-remediated` exist (GitOps Job creates them from `gitops/nexus/lightwell-repositories.json`).

## Maven repositories (Lightwell)

Ported from `deploy-nexus-complete.yml` + `inventory/hosts.yml` → `nexus_repositories`:

| Name | Type | Remote |
|------|------|--------|
| `redhat-packages-validated` | proxy | `https://packages.redhat.com/lightwell/java/validated/` (auth) |
| `redhat-packages-remediated` | proxy | `https://packages.redhat.com/lightwell/java/remediated/` (auth) |
| `maven-central` | proxy | `https://repo1.maven.org/maven2/` |
| `maven-releases` | hosted | internal releases |

Create via REST `POST /service/rest/v1/repositories/maven/proxy` or `.../hosted`; accept **201** or **400** (already exists). Proxies that `requires_auth` use `LIGHTWELL_NETWORK_USERNAME` / `LIGHTWELL_NETWORK_PASSWORD` in the GitOps reconcile Job.

## Discovery (idempotent)

1. `GET {{ nexus_url }}/service/rest/v1/capabilities` — list existing `webhook.repository` capabilities.
2. Skip create if a capability already exists for the same `properties.repository` and `properties.url` (`eda_webhook_url`).

## Create webhook (Nexus ExtDirect)

Nexus OSS may return 500 on REST capability create; use **ExtDirect**:

- **URL:** `POST {{ nexus_url }}/service/extdirect`
- **Auth:** HTTP basic (`admin` + password)
- **Body (RPC):**

```json
{
  "action": "capability_Capability",
  "method": "create",
  "data": [{
    "typeId": "webhook.repository",
    "enabled": true,
    "notes": "SDLC EDA webhook — GitOps managed",
    "properties": {
      "repository": "<hosted-repo-name>",
      "names": "component",
      "url": "<eda_webhook_url>",
      "secret": ""
    }
  }],
  "type": "rpc",
  "tid": 1
}
```

## SDLC demo mapping

| Lightwell repo | SDLC use |
|----------------|----------|
| `redhat-packages-validated` | Optional: component publish staging |
| `redhat-packages-remediated` | Primary: fix/remediated artifact publish → EDA |

Configure one or more `repository` names via GitOps variables (`nexus_webhook_repositories`).

## Verification

- Re-list capabilities; expect `state: active` and `error: false` per webhook.
- Publish test component; EDA rulebook should receive event with `action: CREATED` (or custom `vulnerability_fix_published` if transformed at edge).

## GitOps delivery options

| Pattern | Description |
|---------|-------------|
| **Argo CD Job / PreSync hook** | Job image runs idempotent script implementing the steps above when `eda_webhook_url` / repos change |
| **ConfigMap + CronJob** | Reconcile drift on schedule (less ideal) |
| **External Secrets** | `NEXUS_ADMIN_PASSWORD` mounted into hook Job only |

Webhook URL MUST use in-cluster EDA Service DNS unless a Route is explicitly required.
