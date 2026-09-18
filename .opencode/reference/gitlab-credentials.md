# GitLab credentials (username / password / PAT)

| Variable | Source |
|----------|--------|
| `GITLAB_URL` | GitLab base URL (e.g. `https://gitlab.example.com`) |
| `GITLAB_USERNAME` | Service account or bot user (optional for API if PAT set) |
| `GITLAB_PASSWORD` | Password (platform secret) |
| `GITLAB_PAT` / `GITLAB_TOKEN` | **Required for** `scripts/gitlab_api.py` (`PRIVATE-TOKEN`) |

## Token for the CLI

OpenCode agents use **`python3 /app/scripts/gitlab_api.py`**, not GitLab MCP. The CLI needs a PAT (or root token) in **`GITLAB_PAT`**.

Resolution options:

1. **Bootstrap Job** creates/stores PAT in Secret `gitlab-credentials` key `token` (tenant chart already mounts this as `GITLAB_PAT` when present).
2. **External Secrets** injects `token` into the same Secret.
3. Workshop shortcut: seed `token` from GitLab root PAT into `gitlab-credentials` for the tenant.

Username/password alone are **not** enough for the CLI (no session cookie login).

## GitOps

- Commit only Secret **references** (`secretKeyRef`).
- Never commit PAT values to git.

## Skills

On HTTP `401` from the CLI, stop and check that `GITLAB_PAT` is set and matches `GITLAB_URL`. Do not invent credentials.
