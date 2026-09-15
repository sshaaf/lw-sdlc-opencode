Technical specification for the Autonomous Software Supply Chain Remediation Loop. Integration boundaries, API schemas, agent skills, MCP configuration, and OpenShift manifests are defined so an autonomous agent or engineer can implement the system without a custom Java control plane.

**Supersedes:** [docs/deprecated/spec-quarkus-langgraph.md](docs/deprecated/spec-quarkus-langgraph.md) (Quarkus, LangGraph4j, PostgreSQL harness — deprecated).

---

# Technical Specification: Autonomous Software Supply Chain Remediation System

## 1. System Overview

This system automates ingestion, security analysis, codebase remediation, and ephemeral testing when new software dependencies are published. The architecture spans Nexus, Event-Driven Ansible (EDA), Red Hat Trusted Profile Analyzer (RHTPA), GitLab, and OpenShift.

**Control plane:** [OpenCode](https://opencode.ai/docs/server/) running headless (`opencode serve`) in a container on OpenShift. Orchestration logic lives in **Agent Skills** (`SKILL.md`) and **named agents** in `opencode.json`, not in Quarkus or LangGraph4j.

**Deterministic work** (SBOM upload, webhook routing, optional JSON validation) stays in **Ansible**. **Non-deterministic work** (impact analysis, code changes, MR text, verify orchestration) runs in OpenCode with MCP tools.

### 1.1 Trigger and flow

1. **Nexus (webhook)** → **Ansible EDA** (listens on `:5000`)
2. **Ansible EDA** → **Red Hat TPA** (upload SBOM via BOMbastic API)
3. **Ansible EDA** → **OpenCode HTTP API** (start session, agent `impact-analyzer`, skill `dependency-impact-remediation`)
4. **Agent `impact-analyzer`** → **GitLab MCP** (branch, commit, open merge request)
5. **GitLab webhook** → **Ansible EDA** (filter MR events) → **OpenCode HTTP API** (agent `mr-verifier`, skill `mr-verify-ephemeral`)
6. **Agent `mr-verifier`** → **OpenShift Job or PipelineRun** (clone MR branch, `mvn clean verify` — **not** inside the OpenCode pod)
7. **Agent `mr-verifier`** → **OpenShift** (ephemeral namespace, deploy, Route)
8. **Agent `mr-verifier`** → **GitLab MCP** (MR note with test and deploy summary)

```
┌────────┐    ┌─────┐    ┌─────┐    ┌──────────────────┐    ┌──────────┐
│ Nexus  │───▶│ EDA │───▶│ TPA │    │ OpenCode (OCP)   │───▶│ GitLab   │
└────────┘    │     │    └─────┘    │ impact-analyzer  │    │ MR       │
              │     │───────────────▶│ mr-verifier      │◀───│ webhook  │
              └─────┘                └────────┬─────────┘    └──────────┘
                                              │
                                              ▼
                                    Job/Pipeline + ephemeral NS
```

### 1.2 Design principles

| Principle | Requirement |
|-----------|-------------|
| No custom JVM harness | Do not implement Agent 1/2 as Quarkus services. |
| Skills as workflow | Multi-step behavior is documented in `.opencode/skills/*/SKILL.md` and invoked via the `skill` tool. |
| MCP for GitLab | Use GitLab MCP (HTTP or stdio); avoid bespoke GitLab REST clients in application code. |
| Isolated builds | Unit tests and compiles run in disposable OpenShift workloads, not in the long-lived OpenCode Deployment. |
| Stable handoff | MR descriptions include a machine-readable JSON block (§4.4) for the verifier agent and optional Ansible gates. |

### 1.3 Repository layout (target)

```
.
├── spec.md
├── opencode.json
├── .opencode/
│   ├── agents/
│   │   ├── impact-analyzer.md
│   │   └── mr-verifier.md
│   └── skills/
│       ├── dependency-impact-remediation/
│       │   └── SKILL.md
│       └── mr-verify-ephemeral/
│           └── SKILL.md
├── container/
│   └── Dockerfile
├── .github/
│   └── workflows/
│       └── ci-opencode-image.yml
├── openshift/
│   ├── deployment.yaml
│   ├── route.yaml
│   ├── serviceaccount-verifier.yaml
│   └── templates/
│       ├── verify-job.yaml
│       └── ephemeral-namespace.yaml
├── eda-rulebooks/
│   ├── nexus-trigger.yml
│   └── gitlab-mr-trigger.yml
└── playbooks/
    ├── trigger-impact-analyzer.yml
    └── trigger-mr-verifier.yml
```

---

## 2. Infrastructure prerequisites

* **Red Hat TPA:** On OpenShift; OIDC for automation (`TPA__OIDC__WALKER_CLIENT_SECRET` or equivalent token flow in Ansible).
* **GitLab:** Self-hosted; PAT with `api`, `read_repository`, `write_repository` (or GitLab MCP OAuth where supported).
* **GitLab MCP:** Cluster service in namespace `sdlc-mcp-servers`, or stdio GitLab MCP in the OpenCode image.
* **OpenShift:** Optional `RuntimeClass` `kata` (or gVisor) for verify Jobs; namespace `sdlc-sandboxes` for isolated builds.
* **OpenCode:** Container image built from `container/Dockerfile`, published to Quay (§8); Route or internal Service `opencode.sdlc-control-plane.svc.cluster.local`.
* **LLM provider:** API credentials mounted as Secrets; model IDs configured per agent in `opencode.json`.
* **GitHub Actions:** Workflow pushes the image to `quay.io` on merges to `main` and on version tags.

---

## 3. Ingestion pipeline

### 3.1 Sonatype Nexus webhook

* **Target:** `http://<eda-route>:5000/nexus-upload`
* **Payload:** Nexus component webhook (`component.name`, `component.version`, `component.format`, `action`).

### 3.2 EDA rulebook (Nexus)

**File:** `eda-rulebooks/nexus-trigger.yml`

```yaml
---
- name: Nexus Artifact Ingestion and TPA Upload
  hosts: all
  sources:
    - ansible.eda.webhook:
        host: 0.0.0.0
        port: 5000
  rules:
    - name: Trigger impact analyzer on new component
      condition: event.payload.action == "CREATED"
      action:
        run_job_template:
          name: Upload-TPA-and-Invoke-Impact-Analyzer
          extra_vars:
            artifact_name: "{{ event.payload.component.name }}"
            artifact_version: "{{ event.payload.component.version }}"
```

### 3.3 Playbook: TPA upload and OpenCode (Agent 1)

**File:** `playbooks/trigger-impact-analyzer.yml`

Deterministic steps only; then invoke OpenCode.

```yaml
---
- name: Push SBOM to TPA and start impact-analyzer session
  hosts: localhost
  vars:
    opencode_base_url: "http://opencode.sdlc-control-plane.svc.cluster.local:4096"
    opencode_agent: impact-analyzer
  tasks:
    - name: Upload SBOM to TPA (BOMbastic API)
      uri:
        url: "{{ tpa_api_url }}/api/v1/sbom"
        method: POST
        headers:
          Authorization: "Bearer {{ tpa_oidc_token }}"
          Content-Type: application/json
        body: "{{ lookup('file', '/tmp/sbom.json') }}"
        status_code: 201

    - name: Create OpenCode session
      uri:
        url: "{{ opencode_base_url }}/session"
        method: POST
        headers:
          Authorization: "Basic {{ opencode_basic_auth_b64 }}"
        body_format: json
        body: {}
        status_code: 200
      register: oc_session

    - name: Start impact-analyzer asynchronously
      uri:
        url: "{{ opencode_base_url }}/session/{{ oc_session.json.id }}/prompt_async"
        method: POST
        headers:
          Authorization: "Basic {{ opencode_basic_auth_b64 }}"
        body_format: json
        body:
          agent: "{{ opencode_agent }}"
          parts:
            - type: text
              text: |
                Load skill dependency-impact-remediation and execute it.

                Input JSON:
                {
                  "artifact_id": "{{ artifact_name }}",
                  "new_version": "{{ artifact_version }}"
                }
        status_code: 204
```

**Compatibility alias (optional):** A thin HTTP adapter MAY expose `POST /api/v1/agents/impact-analyzer` with the legacy body from the deprecated spec and translate it to the OpenCode calls above. New implementations SHOULD call OpenCode directly.

**Legacy request body (for adapters):**

```json
{
  "artifact_id": "org.apache.logging.log4j:log4j-core",
  "new_version": "2.17.1"
}
```

### 3.4 EDA rulebook (GitLab MR)

**File:** `eda-rulebooks/gitlab-mr-trigger.yml`

GitLab webhooks SHOULD hit EDA first so filtering stays deterministic.

* **Target:** `http://<eda-route>:5000/gitlab-merge-request`
* **Condition:** `object_kind == "merge_request"` AND `object_attributes.state == "opened"` AND `object_attributes.source_branch` matches `update-artifact-*`.

**File:** `playbooks/trigger-mr-verifier.yml` — same pattern as §3.3 with agent `mr-verifier`, skill `mr-verify-ephemeral`, and payload fields `merge_request_iid`, `project_id`, `source_branch`, `repository_git_url`.

---

## 4. Agent: impact-analyzer

### 4.1 OpenCode agent definition

**File:** `.opencode/agents/impact-analyzer.md` (or `agents` block in `opencode.json`)

* **mode:** `primary`
* **Permissions:** allow `read`, `edit`, `grep`, `glob`, `skill`, GitLab MCP tools; deny `shell` except allowlisted package-manager invocations if required.
* **system:** Short pointer to load `dependency-impact-remediation` at session start.

### 4.2 Skill: dependency-impact-remediation

**File:** `.opencode/skills/dependency-impact-remediation/SKILL.md`

Workflow steps (replaces LangGraph nodes):

1. **Locate impact** — Query TPA / SBOM graph (HTTP from skill instructions) for internal repos that depend on `artifact_id`.
2. **Branch and modify** — GitLab MCP: `create_branch` with pattern `update-artifact-<version-sanitized>`. Bump dependency via documented command (`mvn versions:use-dep-version`, `npm install`, etc.).
3. **Analyze code** — Read release notes; search repo for deprecated APIs; summarize in MR body.
4. **Create MR** — GitLab MCP `create_merge_request`; title `chore(deps): update <artifact_id> to <new_version>`.

The skill MUST require loading GitLab MCP for all GitLab mutations.

### 4.3 Human-readable MR template

```markdown
## Dependency Update
Artifact: `<artifact_id>`
New Version: `<new_version>`

## Impact Analysis
<free text>
```

### 4.4 Machine handoff block (required)

The MR description MUST end with an HTML comment marker `<!-- agent-handoff: do not edit below -->` followed by a fenced JSON block for `mr-verifier` and optional Ansible validation:

```json
{
  "artifact_id": "org.apache.logging.log4j:log4j-core",
  "new_version": "2.17.1",
  "source_branch": "update-artifact-2.17.1",
  "target_branch": "main",
  "project_id": 12345,
  "merge_request_iid": 67
}
```

Ansible MAY reject the webhook if this block is missing when `strict_handoff: true`.

---

## 5. Agent: mr-verifier

### 5.1 OpenCode agent definition

**File:** `.opencode/agents/mr-verifier.md`

* **mode:** `primary`
* **Permissions:** allow `skill`, `shell` limited to `oc`/`kubectl` with verifier ServiceAccount; deny in-repo `edit` on control-plane workspace.
* **ServiceAccount:** `mr-verifier` with RBAC to create namespaces matching `pr-test-mr-*`, Jobs in `sdlc-sandboxes`, and Routes in those namespaces.

### 5.2 Skill: mr-verify-ephemeral

**File:** `.opencode/skills/mr-verify-ephemeral/SKILL.md`

Workflow steps:

1. **Parse handoff** — Extract `agent-handoff` JSON from MR description (GitLab MCP).
2. **Compile and unit test** — Apply `openshift/templates/verify-job.yaml` with `runtimeClassName: kata` when available; image includes JDK + Maven; clone `source_branch`; run `mvn clean verify`. Poll Job logs; fail closed on non-zero exit.
3. **Deploy ephemeral app** — Create namespace `pr-test-mr-<merge_request_iid>`; apply Deployment and Route from `openshift/templates/ephemeral-namespace.yaml` (or equivalent Helm/Kustomize path documented in the skill).
4. **Smoke tests** — Run Playwright or Postman collection against the Route URL (Job or short-lived Pod in the ephemeral namespace).
5. **Summarize** — GitLab MCP `create_merge_request_note` with build status, test summary, Route URL, and namespace TTL.

**Forbidden:** Running `mvn clean verify` on the OpenCode Deployment pod filesystem.

### 5.3 Verify Job template

**File:** `openshift/templates/verify-job.yaml`

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  generateName: verify-mr-
  namespace: sdlc-sandboxes
spec:
  ttlSecondsAfterFinished: 3600
  template:
    spec:
      runtimeClassName: kata
      restartPolicy: Never
      containers:
        - name: verify
          image: registry.example/sdlc/maven-verify:latest
          env:
            - name: GIT_URL
              value: "REPLACE_REPOSITORY_GIT_URL"
            - name: GIT_BRANCH
              value: "REPLACE_SOURCE_BRANCH"
            - name: BUILD_COMMAND
              value: "mvn clean verify"
```

The skill instructs the agent to substitute env values and `oc apply -f`.

### 5.4 Ephemeral deploy (illustrative)

Namespace: `pr-test-mr-<merge_request_iid>`. Deployment name: `ephemeral-app`. Image: project pipeline output or prebuilt smoke image documented per demo app. Route: `ephemeral-app-pr-test-mr-<iid>.apps.<cluster>`.

Implement via `oc apply` and templates in-repo; do not embed Fabric8 or Java clients.

---

## 6. MCP and OpenCode configuration

### 6.1 `opencode.json` (project root)

```json
{
  "$schema": "https://opencode.ai/config.json",
  "default_agent": "impact-analyzer",
  "agent": {
    "impact-analyzer": {
      "mode": "primary",
      "description": "TPA-aware dependency bump and MR creation",
      "permission": {
        "skill": { "*": "allow", "mr-verify-ephemeral": "deny" }
      }
    },
    "mr-verifier": {
      "mode": "primary",
      "description": "Isolated verify, ephemeral deploy, MR feedback",
      "permission": {
        "skill": { "dependency-impact-remediation": "deny", "mr-verify-ephemeral": "allow" },
        "bash": "ask"
      }
    }
  },
  "mcp": {
    "gitlab": {
      "type": "http",
      "url": "http://gitlab-mcp.sdlc-mcp-servers.svc.cluster.local/mcp",
      "headers": {
        "PRIVATE-TOKEN": "${GITLAB_PAT}"
      }
    }
  }
}
```

For large GitLab tool surfaces, prefer [lazy-mcp](https://gitlab.com/gitlab-org/ai/lazy-mcp) as a single aggregated MCP endpoint.

Environment variables (`GITLAB_PAT`, `GITLAB_URL`, LLM keys) come from OpenShift Secrets; reference them in the Deployment manifest, not in git.

### 6.2 Server security

* Run `opencode serve --hostname 0.0.0.0 --port 4096` in the container entrypoint.
* Set `OPENCODE_SERVER_PASSWORD` (and optional `OPENCODE_SERVER_USERNAME`); EDA uses HTTP Basic auth.
* OpenAPI spec: `GET /doc` on the same base URL.

### 6.3 Session lifecycle

* **Async prompts:** `POST /session/{id}/prompt_async` returns `204`; monitor via `GET /event` (SSE) or session message APIs.
* **Idempotency:** EDA SHOULD pass `merge_request_iid` in the verifier prompt so repeated webhooks do not duplicate namespaces (skill: check existing `pr-test-mr-*`).

---

## 7. OpenShift deployment (OpenCode)

**Namespace:** `sdlc-control-plane`

| Resource | Purpose |
|----------|---------|
| `Deployment` | OpenCode server + optional lazy-mcp sidecar |
| `Route` / `Service` | EDA and operators reach `:4096` |
| `Secret` | `OPENCODE_SERVER_PASSWORD`, LLM API key, `GITLAB_PAT` |
| `ConfigMap` or image bake | `opencode.json`, `.opencode/skills`, `.opencode/agents` |
| `ServiceAccount` + `RoleBinding` | `mr-verifier` agent credentials (mounted only when running verifier sessions via projected token or `oc` login) |

Resource requests: sized for LLM orchestration, not for Maven builds.

**Image reference:** OpenShift `Deployment` SHOULD use the Quay image produced by CI, for example `quay.io/sshaaf/sdlc-opencode:latest` or an immutable `sha-<git-sha>` tag.

---

## 8. Continuous integration (GitHub Actions → Quay.io)

The OpenCode control-plane image is built in GitHub Actions and pushed to Quay.io. Ansible, EDA, and OpenShift consume the published tag; they do not build the image on-cluster.

### 8.1 Workflow

**File:** `.github/workflows/ci-opencode-image.yml`

| Job / event | Behavior |
|-------------|----------|
| `pull_request` to `main` | `build` → `test` (smoke); **no** `publish` |
| `push` to `main` | `build` → `test` → `publish` to Quay (`latest`, `sha-<short-sha>`) |
| `push` tag `v*` | Same pipeline; semver tags via `docker/metadata-action`; `release` job creates GitHub Release |
| `workflow_dispatch` | Full pipeline except PR skip rules |

Smoke test: `container/scripts/smoke-test.sh` (health API + baked config). See [README.md](README.md#container-image-ci).

Build context is the repository root; Dockerfile path is `container/Dockerfile`. The image bakes in `opencode.json` and `.opencode/` (agents and skills). Runtime secrets are **not** baked into the image.

### 8.2 Quay repository setup

1. Repository on [Quay.io](https://quay.io): **`sshaaf/sdlc-opencode`** (`quay.io/sshaaf/sdlc-opencode`).
2. Create a **robot account** or use a user with push access; grant **Write** on that repository.
3. Configure the GitHub repository:

| Name | Type | Value |
|------|------|--------|
| `QUAY_IMAGE_NAME` | Variable (optional) | Full name without tag; default in CI is `quay.io/sshaaf/sdlc-opencode` |
| `QUAY_USERNAME` | Secret | Robot or user name |
| `QUAY_PASSWORD` | Secret | Robot token or password |

If `QUAY_IMAGE_NAME` is unset, CI uses `quay.io/sshaaf/sdlc-opencode`.

### 8.3 Dockerfile contract

**File:** `container/Dockerfile`

* Base: `ghcr.io/anomalyco/opencode:latest`
* Adds `git` and `openssh-client` (Alpine `apk`) for agent workflows
* `WORKDIR /app` with `COPY opencode.json` and `COPY .opencode`
* `ENTRYPOINT`: `opencode serve --hostname 0.0.0.0 --port 4096`
* `EXPOSE 4096`

### 8.4 Supply-chain alignment

This pipeline is the **trusted build** for the same remediation loop Nexus triggers: dependency updates flow through TPA and GitLab, while the agent runtime image is versioned on Quay and referenced immutably in OpenShift when policy requires it (prefer `sha-<short-sha>` over floating `latest` in production).

---

## 9. Non-goals (this specification)

* Quarkus, LangGraph4j, PostgreSQL agent state store.
* Custom GitLab REST SDKs in Java or Python services.
* `SandboxClaim` CRD (`agents.k8s.io/v1alpha1`) unless the cluster already provides it; use `Job` / `PipelineRun` instead.
* In-pod compilation on the OpenCode control plane.

---

## 10. Migration note

Implementations started from the deprecated Quarkus specification should remap:

| Deprecated | Current |
|------------|---------|
| `POST .../api/v1/agents/impact-analyzer` | OpenCode session + `impact-analyzer` + skill §4.2 |
| `POST .../api/v1/agents/verify-mr` | EDA GitLab rulebook + OpenCode `mr-verifier` §5 |
| `application.properties` MCP | `opencode.json` §6 |
| Fabric8 deploy code | OpenShift templates + `oc` §5.3–5.4 |
| LangGraph nodes | Skill workflow steps §4.2, §5.2 |
