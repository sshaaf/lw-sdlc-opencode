---
name: mr-verify-ephemeral
description: Parse MR handoff, run isolated verify Job, deploy ephemeral environment, smoke test, and post GitLab MR note.
---

# MR verify ephemeral

Automates **Agent 2** behavior (`spec.md` §5). GitLab reads/notes via **GitLab MCP** only—see `.opencode/reference/gitlab-mcp.md`.

## Inputs

Session JSON (from EDA / GitLab webhook normalization):

```json
{
  "merge_request_iid": 67,
  "project_id": 12345,
  "source_branch": "update-artifact-2.17.1",
  "repository_git_url": "git@gitlab.example.com:group/repo.git"
}
```

## Preconditions

1. Load only this skill—not `dependency-impact-remediation`.
2. GitLab MCP available; on `401` stop and reference `.opencode/reference/gitlab-credentials.md`.
3. `oc` / `kubectl` available and authenticated as verifier ServiceAccount.

## Step 1 — Parse handoff (fail closed)

1. Use GitLab MCP to fetch merge request `project_id` + `merge_request_iid` description.
2. Locate `<!-- agent-handoff: do not edit below -->` and parse the following fenced `json` block.
3. Validate required keys: `artifact_id`, `new_version`, `source_branch`, `target_branch`, `project_id`, `merge_request_iid`.
4. If missing or invalid JSON:
   - Post MR note via MCP: “Verifier blocked: missing or invalid agent-handoff JSON.”
   - **Stop**—do not create Jobs or namespaces.

Prefer handoff JSON over webhook fields when both exist; they must agree on `merge_request_iid` and `source_branch`.

## Step 2 — Compile and unit test (isolated Job)

**Forbidden:** Running `mvn clean verify`, `gradle test`, or `npm test` inside the OpenCode control-plane container.

Demo depth **A** (`lw-demo-help-app`): use **`mvn clean verify`** unless handoff specifies otherwise.

1. **Idempotency:** `oc get job -n sdlc-sandboxes -l mr-iid=<merge_request_iid>` — if a running/succeeded Job exists, reuse logs or skip recreate per operator policy.
2. Apply verify Job from repo template `openshift/templates/verify-job.yaml` (GitOps may sync this path; substitute env):
   - `GIT_URL` = `repository_git_url`
   - `GIT_BRANCH` = `source_branch`
   - `BUILD_COMMAND` = `mvn clean verify` (or from handoff if extended later)
   - Label: `mr-iid=<merge_request_iid>`
   - `runtimeClassName: kata` when cluster provides it3. Poll Job to completion; stream logs with `oc logs job/<name> -n sdlc-sandboxes`.
4. Non-zero exit → post MR note with log excerpt; **stop** (no ephemeral deploy).

## Step 3 — Ephemeral deploy

Namespace: `pr-test-mr-<merge_request_iid>`.

1. **Idempotency:** if namespace exists, inspect existing Deployment/Route before creating duplicates.
2. `oc create namespace pr-test-mr-<merge_request_iid>` (or apply from `openshift/templates/ephemeral-namespace.yaml` when present).
3. Deploy application image documented for the demo app (GitOps default or handoff extension).
4. Expose Route; record URL for smoke tests.

Platform namespaces for OpenCode and MCP are managed by **Argo CD**—do not modify `sdlc-control-plane` or `sdlc-mcp-servers` in this skill.

## Step 4 — Smoke tests

1. Run smoke suite against Route URL (Playwright/Postman Job in ephemeral namespace, or documented `curl` checks).
2. Capture pass/fail and response snippets (no secrets).

## Step 5 — Summarize on MR

Post GitLab MCP **merge request note** including:

- Verify Job name and pass/fail
- Ephemeral namespace and Route URL
- Smoke test result
- TTL reminder (namespaces Jobs should be garbage-collected per cluster policy)

## Failure handling

| Condition | Action |
|-----------|--------|
| Invalid handoff | MR note; stop |
| Job failed | MR note with logs; stop |
| `oc` forbidden | MR note; stop |
| Duplicate webhook | Prefer idempotent Job/NS checks before create |

## Completion

Return: MR URL, verify status, Route URL (if deployed), and note id if available.
