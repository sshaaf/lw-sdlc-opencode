# GitLab MCP (OpenCode)

Credentials: [gitlab-credentials.md](./gitlab-credentials.md) (`GITLAB_USERNAME` / `GITLAB_PASSWORD`, derived `GITLAB_PAT`).

## In-cluster (production)

Configured in `opencode.json`:

| Setting | Value |
|---------|--------|
| Transport | HTTP |
| URL | `http://gitlab-mcp.sdlc-mcp-servers.svc.cluster.local/mcp` |
| Header | `PRIVATE-TOKEN: ${GITLAB_PAT}` when PAT is derived for the OpenCode → MCP hop |

If GitLab MCP authenticates to GitLab with username/password internally, the OpenCode pod may omit `PRIVATE-TOKEN` toward MCP (adjust GitOps overlay only—do not commit secrets).

## Before using tools

1. List available MCP tools for server `gitlab` (tool names vary by MCP version).
2. Map workflow steps to discovered tools for: get project, create branch, commit/push, create merge request, get merge request, create merge request note, repository file read/search.

Do not hard-code deprecated tool names without verifying the list.

## Local development

**HTTP (legacy token header)** — point at a reachable MCP or GitLab MCP route; ensure `GITLAB_PAT` is set after resolving from username/password.

**Stdio** — example pattern (paths and package vary by install):

```json
"mcp": {
  "gitlab": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-gitlab"],
    "env": {
      "GITLAB_PERSONAL_ACCESS_TOKEN": "${GITLAB_PAT}",
      "GITLAB_API_URL": "${GITLAB_URL}/api/v4"
    }
  }
}
```

Resolve `GITLAB_PAT` from username/password before starting OpenCode locally.

## lazy-mcp (optional)

For large tool catalogs, front GitLab MCP with [lazy-mcp](https://gitlab.com/gitlab-org/ai/lazy-mcp) and point OpenCode at the lazy-mcp HTTP endpoint instead of GitLab MCP directly.

## Skills

- `dependency-impact-remediation` — branch, bump, MR
- `mr-verify-ephemeral` — read MR, post note

Both MUST use MCP for GitLab—no direct GitLab REST `curl` from the agent.
