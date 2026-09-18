---
name: dependency-impact-remediation
description: Consume blast-radius handoff, bump dependencies via GitLab MCP for one app (demo A), and open a merge request with agent-handoff JSON.
---

# Dependency impact remediation

Automates **Agent 1** behavior (`spec.md` §4). All GitLab actions go through **GitLab MCP**—see `.opencode/reference/gitlab-mcp.md`.

Demo depth **A**: remediate **one** application from EDA blast radius (`affected_repos[0]`), typically `lw-demo-help-app` / `help-im-vulnerable`.

## Inputs

Session JSON (from EDA `trigger-impact-analyzer`):

```json
{
  "artifact_id": "com.fasterxml.woodstox:woodstox-core",
  "new_version": "6.0.3.rhlw-00001",
  "gitlab_path": "lightwell/lw-demo-help-app-GUID",
  "repo_url": "https://gitlab.../lightwell/lw-demo-help-app-GUID.git",
  "affected_repos": [
    {
      "gitlab_path": "lightwell/lw-demo-help-app-GUID",
      "repo_url": "https://gitlab.../lightwell/lw-demo-help-app-GUID.git",
      "match_reason": "sbom_label_and_dependency_coordinate",
      "sbom_label": "sdlc-demo-GUID"
    }
  ],
  "blast_radius": { "mode": "single_app_demo_a", "count": 1 }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `artifact_id` | yes | Maven coordinate `group:artifact` or Nexus component name |
| `new_version` | yes | Target version to adopt |
| `gitlab_path` or `affected_repos[0].gitlab_path` | yes (demo A) | GitLab project path to remediate |
| `repo_url` | recommended | HTTPS clone URL for the same project |

Environment: `GITLAB_URL`, credentials per `.opencode/reference/gitlab-credentials.md`. TPA re-query is **optional** when blast radius was already computed by EDA.

## Preconditions

1. GitLab MCP is connected; list tools and confirm GitLab operations are available.
2. If MCP returns `401`, stop—check PAT resolution (`.opencode/reference/gitlab-credentials.md`).
3. Do not load skill `mr-verify-ephemeral`.
4. If `blast_radius.count` is `0` or `affected_repos` is empty: **stop**—do not open an MR (EDA should not have started this session).

## Step 1 — Resolve target repo (blast radius)

1. Prefer **`gitlab_path`** / **`repo_url`** from input, else `affected_repos[0]`.
2. Resolve GitLab **project id** via MCP for that path.
3. Do **not** invent additional repos in demo A. Process **only** that one project.
4. If path/project cannot be resolved: stop with a short report—no MR.

## Step 2 — Branch and modify

1. **Branch name:** `update-artifact-<sanitized-version>`  
   - Example: version `6.0.3.rhlw-00001` → `update-artifact-6.0.3.rhlw-00001`  
   - Replace `/` and unsafe characters with `-`.
2. Use GitLab MCP to **create branch** from `target_branch` (usually `main`).
3. Bump dependency (help-app is **Maven**):
   - Prefer MCP file edit on `pom.xml` for `artifact_id` → `new_version`.
   - Or `mvn versions:use-dep-version` only if shell is allowed for package-manager commands.
4. Commit with message: `chore(deps): update <artifact_id> to <new_version>`.

## Step 3 — Analyze code

1. Fetch release notes / changelog for `new_version` when available.
2. Use GitLab MCP to search repository for deprecated APIs or symbols if relevant.
3. Draft **Impact Analysis** paragraph for the MR (include `match_reason` / SBOM label when present).

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
GitLab path: `<gitlab_path>`
Blast radius: demo A (single app)

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
  "merge_request_iid": 67,
  "gitlab_path": "<gitlab_path>"
}
```

Fill `project_id` and `merge_request_iid` from MCP merge request response after creation.

## Failure handling

| Condition | Action |
|-----------|--------|
| Empty blast radius | Stop; no MR |
| Project not found | Stop; report path |
| Branch already exists | Continue bump on that branch or report |
| MCP error on push/MR | Stop; include MCP error text; retry at most 2 times |
| Bump / pom conflict | Report files; stop |

## Completion

Return summary: GitLab project, MR URL, `merge_request_iid`, and confirmation that agent-handoff JSON is present in the description.
