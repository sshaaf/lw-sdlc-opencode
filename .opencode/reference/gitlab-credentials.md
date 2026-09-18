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

1. **Bootstrap Job** `sync-gitlab-pat` copies the GitLab root PAT (`secret/gitlab/root-user-personal-token`) into Secret `gitlab-root-pat` key `token` in the tenant SDLC namespace. The OpenCode Deployment mounts that key as `GITLAB_PAT` (required, not optional).
2. **External Secrets** can replace that Job if it writes the same Secret and key.
3. Do not rely on `GITLAB_USERNAME` / `GITLAB_PASSWORD` — the CLI does not do session login.

## GitOps

- Commit only Secret **references** (`secretKeyRef`).
- Never commit PAT values to git.

## Skills

On HTTP `401` from the CLI, stop and check that `GITLAB_PAT` is set and matches `GITLAB_URL`. Do not invent credentials.
