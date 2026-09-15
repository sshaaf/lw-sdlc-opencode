# EDA rulebooks (AAP SCM layout)

AAP **EDA project** SCM must point at this repository **root** so both directories are on the activation worker:

```
eda-rulebooks/sdlc-remediation.yml   # activation rulebook
playbooks/                           # run_playbook targets
```

After project sync, the activation should use rulebook file **`sdlc-remediation.yml`** (API name may match the filename).

GitOps bootstrap: [`gitops/sdlc-eda/`](../gitops/sdlc-eda/README.md).
