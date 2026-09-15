# GitLab CI → OpenCode (future option)

> **Not in use for this project.** Merge request agents are triggered via **GitLab webhook → Ansible EDA** ([`spec.md` §3.4](../spec.md)). This folder is reference material if you later want the same `mr-verifier` session started from a **`.gitlab-ci.yml`** in an application repository instead of EDA.

## When this might make sense (future)

- Runners already reach `OPENCODE_BASE_URL` and you want triggers colocated with app repos.
- You prefer `merge_request_event` pipelines over instance-level webhooks to EDA.
- Same end state as EDA: `POST /session` → `POST /session/{id}/prompt_async` with agent `mr-verifier` and skill `mr-verify-ephemeral`.

## Chain comparison

| Trigger | Path | Status here |
|---------|------|-------------|
| New Nexus artifact | Nexus → **EDA** → TPA + **impact-analyzer** | **In use** |
| Merge request opened | GitLab webhook → **EDA** → **mr-verifier** | **In use** |
| Merge request opened | **GitLab CI** → OpenCode **mr-verifier** | **Future** (this folder) |

## If you enable it later

1. Copy [`.gitlab-ci.yml.example`](.gitlab-ci.yml.example) or `include` [`ci/opencode-mr-verifier.yml`](ci/opencode-mr-verifier.yml).
2. Set CI variables: `OPENCODE_BASE_URL`, `OPENCODE_SERVER_PASSWORD`.
3. Disable or filter the EDA GitLab webhook path for the same projects to avoid duplicate verifier runs.
4. Optionally restrict to `update-artifact-*` branches (uncomment filter in the CI file).

## Local / manual test

```bash
export OPENCODE_BASE_URL=http://localhost:4096
export OPENCODE_SERVER_PASSWORD=...
./gitlab/scripts/trigger-opencode-agent.sh mr-verifier payload.json
```
