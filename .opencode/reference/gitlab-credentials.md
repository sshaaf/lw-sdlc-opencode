# GitLab credentials (username / password)

This project does **not** assume operators hand out a GitLab Personal Access Token (PAT). The **source of truth** is:

| Variable | Source |
|----------|--------|
| `GITLAB_URL` | GitLab base URL (e.g. `https://gitlab.example.com`) |
| `GITLAB_USERNAME` | Service account or bot user |
| `GITLAB_PASSWORD` | Password (or deploy token secret, if policy allows) |

## When a token is required

GitLab MCP and the GitLab REST API typically expect a **`PRIVATE-TOKEN`** (PAT) or OAuth bearer token. If no PAT is stored in the cluster:

1. **Resolve at runtime** using `GITLAB_USERNAME` and `GITLAB_PASSWORD` before OpenCode or the MCP server starts, **or**
2. **Resolve inside the GitLab MCP Deployment** (sidecar/init) and expose MCP with token already configured.

The OpenCode container consumes **`GITLAB_PAT`** only as a **derived** runtime variable (never committed to git).

## Resolution options (pick one per environment)

### A. GitLab MCP server holds username/password

Deploy GitLab MCP configured with user/password; MCP performs GitLab auth internally. OpenCode `opencode.json` points at MCP **without** `PRIVATE-TOKEN` on the OpenCode pod if the MCP Service does not require it.

### B. Init job / initContainer before OpenCode

A bootstrap script (GitOps-managed Job or pod `initContainer`) uses username/password to obtain a PAT, then:

- Writes `token` into a Kubernetes Secret (e.g. `gitlab-credentials` / key `token`), or
- Mounts a file read by the entrypoint that exports `GITLAB_PAT`.

### C. External Secrets / SealedSecrets

Store username/password in External Secrets; an optional **template** or companion Job refreshes `GITLAB_PAT` into the same Secret on a schedule.

## OpenCode and `opencode.json`

MCP HTTP config may still reference:

```json
"headers": {
  "PRIVATE-TOKEN": "${GITLAB_PAT}"
}
```

`GITLAB_PAT` MUST be injected by the platform (init, MCP proxy, or ESO)—not checked into the repository.

## GitOps (Argo CD)

- Commit only Secret **references** (`secretKeyRef`) and bootstrap Application manifests.
- Store `gitlab-credentials` (username/password) via cluster secret management; PAT material is **derived** and may live in the same Secret under key `token` after resolution.

## Skills

Agent skills MUST NOT ask the LLM to invent credentials. If MCP calls fail with `401`, the skill directs checking that PAT resolution ran and that `GITLAB_URL` matches the GitLab instance.
