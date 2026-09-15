> **DEPRECATED** — Do not implement. Superseded by the canonical specification at [`spec.md`](../../spec.md) (OpenCode + Agent Skills on OpenShift). Retained for historical reference only.

---

Here is the comprehensive, highly detailed technical specification. It is written precisely so an autonomous agent (or human engineer) can parse the exact integration boundaries, API schemas, tool configurations, and Kubernetes manifest requirements needed to implement this Autonomous Software Supply Chain Remediation Loop.

---

# Technical Specification: Autonomous Software Supply Chain Remediation System

## 1. System Overview

This system automates the ingestion, security analysis, codebase remediation, and ephemeral testing of new software dependencies. The architecture spans from a Nexus artifact repository down to an OpenShift environment, utilizing Event-Driven Ansible (EDA), Red Hat Trusted Profile Analyzer (RHTPA), and a multi-agent framework built with Quarkus, LangGraph4j, and the Model Context Protocol (MCP).

### 1.1 Trigger & Flow Diagram

1. **Nexus (Webhook)** ➔ **Ansible EDA** (Listens on `:5000/endpoint`)
2. **Ansible EDA** ➔ **Red Hat TPA** (Uploads SBOM via `BOMbastic` API)
3. **Ansible EDA** ➔ **Agent 1 Ingress** (Quarkus REST API)
4. **Agent 1 (LangGraph4j)** ➔ **GitLab MCP** (Branches, commits, opens Merge Request)
5. **GitLab Webhook** ➔ **Agent 2 Ingress** (Quarkus REST API)
6. **Agent 2 (LangGraph4j)** ➔ **K8s Sandbox** (Compiles, unit tests)
7. **Agent 2 (Fabric8 K8s Client)** ➔ **OpenShift** (Deploys ephemeral app)
8. **Agent 2 (GitLab MCP)** ➔ **GitLab MR** (Posts test results for human approval)

---

## 2. Infrastructure Prerequisites

* **Red Hat TPA:** Running on OpenShift, authenticated via OIDC (`TPA__OIDC__WALKER_CLIENT_SECRET`).
* **GitLab:** Self-hosted, with an active Personal Access Token (PAT) configured with `api`, `read_repository`, and `write_repository` scopes.
* **GitLab MCP Server:** Deployed in the `sdlc-mcp-servers` namespace.
* **Kubernetes (OpenShift):** `Kata Containers` configured as a RuntimeClass (or `gVisor` if preferred) for isolated agent execution.

---

## 3. Ingestion Pipeline Specification

### 3.1 Sonatype Nexus Webhook

Nexus is configured to fire a webhook when a new component is published.

* **Target:** `http://<eda-server-route>:5000/nexus-upload`
* **Format:** Standard Nexus Component webhook (contains `component.name`, `component.version`, `component.format`).

### 3.2 Event-Driven Ansible (EDA) Rulebook

The EDA Rulebook maps the Nexus JSON payload into a strict execution action.

**File:** `eda-rulebooks/nexus-trigger.yml`

```yaml
---
- name: Nexus Artifact Ingestion & TPA Upload
  hosts: all
  sources:
    - ansible.eda.webhook:
        host: 0.0.0.0
        port: 5000
  rules:
    - name: Trigger Agent on New Component
      condition: event.payload.action == "CREATED"
      action:
        run_job_template:
          name: "Upload-TPA-and-Invoke-Agent"
          extra_vars:
            artifact_name: "{{ event.payload.component.name }}"
            artifact_version: "{{ event.payload.component.version }}"

```

### 3.3 Ansible Playbook (Upload to TPA & Trigger Agent 1)

This playbook handles the strict deterministic REST calls before the AI takes over.

**File:** `playbooks/trigger-agent.yml`

```yaml
---
- name: Push SBOM to TPA and Invoke Agent 1
  hosts: localhost
  tasks:
    - name: Upload SBOM to Red Hat Trusted Profile Analyzer (BOMbastic API)
      uri:
        url: "{{ tpa_api_url }}/api/v1/sbom"
        method: POST
        headers:
          Authorization: "Bearer {{ tpa_oidc_token }}"
          Content-Type: "application/json"
        body: "{{ lookup('file', '/tmp/sbom.json') }}"
        status_code: 201

    - name: Trigger Quarkus Agent 1 Ingress
      uri:
        url: "http://harness-ingress.sdlc-control-plane.svc.cluster.local/api/v1/agents/impact-analyzer"
        method: POST
        body_format: json
        body:
          artifact_id: "{{ artifact_name }}"
          new_version: "{{ artifact_version }}"

```

---

## 4. Agent 1: Impact Analyzer (Quarkus & LangGraph4j)

### 4.1 Ingress Schema (FastAPI / Quarkus REST)

The payload from Ansible EDA triggers Agent 1.

**Endpoint:** `POST /api/v1/agents/impact-analyzer`

```json
{
  "artifact_id": "org.apache.logging.log4j:log4j-core",
  "new_version": "2.17.1"
}

```

### 4.2 Agent 1 State Machine (LangGraph4j)

* **Node 1 (`Locate_Impact`):** Queries the TPA API / SBOM graph to find internal project repositories that list `artifact_id` as a dependency.
* **Node 2 (`Branch_and_Modify`):** For a matched repo, uses the GitLab MCP Server to invoke the `create_branch` tool. Uses Bash/File MCP to run `sed` or package managers (e.g., `mvn versions:use-dep-version`) to bump the version.
* **Node 3 (`Analyze_Code`):** Prompts the LLM to read the release notes of the new artifact and perform semantic searches via GitLab MCP on the repository code to find deprecated usages.
* **Node 4 (`Create_MR`):** Uses the `create_merge_request` tool on the GitLab MCP server.

### 4.3 Pydantic / Java Record Enforced Output

When Agent 1 creates the MR, the LLM must generate the description using this strict schema to ensure Agent 2 can parse it later:

```json
{
  "title": "chore(deps): update org.apache.logging.log4j:log4j-core to 2.17.1",
  "description": "## Dependency Update\nArtifact: `org.apache.logging.log4j:log4j-core`\nNew Version: `2.17.1`\n\n## Impact Analysis\nNo deprecated methods identified. TPA Risk profile indicates this patches CVE-2021-44228.",
  "target_branch": "main",
  "source_branch": "update-artifact-2.17.1"
}

```

---

## 5. Agent 2: Verification & Deployer

### 5.1 GitLab MR Webhook

GitLab sends a webhook when Agent 1 creates the MR.

* **Target:** `http://harness-ingress.sdlc-control-plane.svc.cluster.local/api/v1/agents/verify-mr`
* **Condition:** Payload `object_attributes.state` == `opened` AND `object_attributes.source_branch` matches `update-artifact-*`.

### 5.2 Agent 2 State Machine (LangGraph4j)

* **Node 1 (`Compile_and_Unit_Test`):** Requests a Kubernetes Sandbox (Kata Container) via `SandboxClaim`. The sandbox clones the MR branch, runs `mvn clean verify`, and streams logs back via Server-Sent Events (SSE) to the Harness webhook.
* **Node 2 (`Deploy_to_OpenShift`):** Uses the Fabric8 `KubernetesClient` within the Quarkus app to create the ephemeral deployment.

**Fabric8 Implementation Detail (`Agent2Deployer.java`):**

```java
// Agent 2 creates a namespace derived from the MR ID
String namespace = "pr-test-mr-" + mergeRequestId;

Namespace ns = new NamespaceBuilder().withNewMetadata().withName(namespace).endMetadata().build();
kubernetesClient.namespaces().resource(ns).create();

// Deploy application
Deployment deployment = new DeploymentBuilder()
    .withNewMetadata().withName("ephemeral-app").endMetadata()
    .withNewSpec()
        .withReplicas(1)
        .withNewSelector().addToMatchLabels("app", "ephemeral").endSelector()
        .withNewTemplate()
            .withNewMetadata().addToLabels("app", "ephemeral").endMetadata()
            .withNewSpec()
                .addNewContainer()
                    .withName("app")
                    .withImage("image-registry.openshift-image-registry.svc:5000/" + namespace + "/app:latest")
                .endContainer()
            .endSpec()
        .endTemplate()
    .endSpec()
.build();

kubernetesClient.apps().deployments().inNamespace(namespace).resource(deployment).create();

```

* **Node 3 (`Run_Smoke_Tests`):** Triggers a containerized Postman / Playwright suite against the newly created OpenShift Route.
* **Node 4 (`Summarize_and_Comment`):** Uses GitLab MCP tool `create_merge_request_note` to append the final report to the MR.

---

## 6. MCP Integration Details (application.properties)

The Quarkus LangChain4j application acts as the client for the MCP servers. Do not write custom API clients; rely strictly on these properties.

**File:** `src/main/resources/application.properties`

```properties
# Quarkus configuration for LangGraph4j state memory
quarkus.datasource.db-kind=postgresql
quarkus.datasource.jdbc.url=jdbc:postgresql://postgres-svc:5432/agents
quarkus.virtual-threads.enabled=true

# GitLab MCP Server Configuration (Sidecar / Subprocess)
quarkus.langchain4j.mcp.gitlab.transport-type=stdio
quarkus.langchain4j.mcp.gitlab.command=npx
quarkus.langchain4j.mcp.gitlab.args=-y,@gitlab/mcp-server

# Pass credentials securely from Kubernetes Secrets
quarkus.langchain4j.mcp.gitlab.env.GITLAB_PERSONAL_ACCESS_TOKEN=${GITLAB_PAT}
quarkus.langchain4j.mcp.gitlab.env.GITLAB_API_URL=${GITLAB_URL}/api/v4

```

## 7. Kubernetes Sandbox Manifest (CRD)

When Agent 2 compiles code, it MUST NOT do so inside the Quarkus control-plane pod. It emits this CRD to spawn an isolated Kata Container.

**File:** `sandbox-claim.yaml` (Dynamically generated by `Fabric8`)

```yaml
apiVersion: agents.k8s.io/v1alpha1
kind: SandboxClaim
metadata:
  generateName: "agent-verifier-sandbox-"
  namespace: "sdlc-sandboxes"
spec:
  runtimeClassName: kata  # Enforces microVM isolation for untrusted CI runs
  agentPayload:
    task: "execute unit tests"
    repository: "git@gitlab.company.com:project/repo.git"
    branch: "update-artifact-2.17.1"
    command: "mvn clean verify"
  callbackWebhook: "http://harness-ingress.sdlc-control-plane.svc.cluster.local/api/v1/sandbox/callback/12345"

```
