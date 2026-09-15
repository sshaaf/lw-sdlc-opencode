---
name: dependency-impact-remediation
description: Locate TPA impact, bump dependencies via GitLab MCP, analyze release notes, and open a merge request with agent-handoff JSON.
---

# Dependency impact remediation

Automates **Agent 1** behavior (`spec.md` §4). All GitLab actions go through **GitLab MCP**—see `.opencode/reference/gitlab-mcp.md`.

## Inputs

Session JSON (from EDA or operator):

```json
{
  "artifact_id": "org.apache.logging.log4j:log4j-core",
  "new_version": "2.17.1"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `artifact_id` | yes | Maven/npm style coordinate or Nexus component name |
| `new_version` | yes | Target version to adopt |

Environment: `GITLAB_URL`, `TPA_API_URL`, `TPA_OIDC_TOKEN` or `TPA_BEARER_TOKEN` (read-only TPA query).

## Preconditions

1. GitLab MCP is connected; list tools and confirm GitLab operations are available.
2. If MCP returns `401`, stop—check PAT resolution (`.opencode/reference/gitlab-credentials.md`).
3. Do not load skill `mr-verify-ephemeral`.

## Step 1 — Locate impact

1. Query TPA / SBOM graph for projects that depend on `artifact_id`:
   - `GET ${TPA_API_URL}/...` (use deployment-specific path from TPA docs) with `Authorization: Bearer ${TPA_OIDC_TOKEN}`.
2. Map TPA project records to **GitLab project id** and default branch (`main` unless documented otherwise).
3. If **no** dependent repository is found: stop and return a short report listing `artifact_id` / `new_version` and “no impacted GitLab project”—do not open an MR.

## Step 2 — Branch and modify

For each impacted GitLab project (process one project per session unless input specifies multiple):

1. **Branch name:** `update-artifact-<sanitized-version>`  
   - Example: version `2.17.1` → `update-artifact-2.17.1`  
   - Replace `/` and unsafe characters with `-`.
2. Use GitLab MCP to **create branch** from `target_branch` (usually `main`).
3. Bump dependency using repository type:
   - **Maven:** `mvn versions:use-dep-version -Dincludes=<artifact_id> -DnewVersion=<new_version> -DgenerateBackupPoms=false` (run only in a clone or via MCP file edit—prefer MCP file operations on `pom.xml` when shell is denied).
   - **npm:** update `package.json` / lockfile via MCP file edit.
4. Commit with message: `chore(deps): update <artifact_id> to <new_version>`.

## Step 3 — Analyze code

1. Fetch release notes / changelog for `new_version` (web search or vendor URL if allowed).
2. Use GitLab MCP to search repository for deprecated APIs or symbols mentioned in release notes.
3. Draft **Impact Analysis** paragraph for the MR (plain language, CVE mentions if TPA flagged any).

## Step 4 — Create merge request

Use GitLab MCP **create merge request** with:

- **Title:** `chore(deps): update <artifact_id> to <new_version>`
- **Source branch:** `update-artifact-<sanitized-version>`
- **Target branch:** `main` (or project default)
- **Description:** human template + handoff block below

### MR description template (human-readable)

```markdown
## Dependency Update
Artifact: `<artifact_id>`
New Version: `<new_version>`

## Impact Analysis
<your analysis from Step 3>
```

### Agent handoff block (required)

Append the HTML comment `<!-- agent-handoff: do not edit below -->` then a fenced JSON block:

```json
{
  "artifact_id": "<artifact_id>",
  "new_version": "<new_version>",
  "source_branch": "update-artifact-<sanitized-version>",
  "target_branch": "main",
  "project_id": 12345,
  "merge_request_iid": 67
}
```

Fill `project_id` and `merge_request_iid` from MCP merge request response after creation.

## Failure handling

| Condition | Action |
|-----------|--------|
| TPA query fails | Stop; report HTTP status; do not mutate GitLab |
| No dependent repo | Stop; no MR |
| Branch already exists | Use MCP to inspect branch; continue bump on that branch or ask operator |
| MCP error on push/MR | Stop; include MCP error text; do not retry more than 2 times without new input |
| Bump / build file conflict | Report files; stop MR until resolved |

## Completion

Return summary: GitLab project, MR URL, `merge_request_iid`, and confirmation that agent-handoff JSON is present in the description.
