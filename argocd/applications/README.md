# ArgoCD Applications — Single Delivery Authority

> **Gap closed:** *Push / pull duality — "The pipeline runs `kubectl apply` while
> ArgoCD also reconciles the same manifests."* (PDF slide 22)

## The problem

Two writers were mutating the same cluster state:

1. **CI push** — each `devsecops-*` workflow ran `kubectl apply` in its `deploy` job.
2. **GitOps pull** — ArgoCD (present in `argocd/`) reconciled the same manifests.

When both act, they fight: ArgoCD sees the pipeline's live changes as *drift* and
either reverts them or flaps the resource. Rollback semantics become ambiguous.

## The resolution — ArgoCD wins

These `Application` manifests make ArgoCD the **sole** delivery authority with
`selfHeal: true` and `prune: true`. The CI pipeline's responsibility shrinks to:

```
build → scan → sign (cosign) → SBOM → push image → bump image tag in Git
```

ArgoCD then detects the Git change and reconciles. One writer, drift
self-corrects, and a rollback is a `git revert`.

The `deploy` job in each workflow no longer runs `kubectl apply`. It updates the
image tag (e.g. via `kustomize edit set image` or a commit to the manifest) and
hands off to ArgoCD. The post-deploy **DAST** job waits on ArgoCD reporting
`Synced/Healthy` rather than on a pipeline-side rollout.

## Install

```bash
kubectl apply -f argocd/applications/fastapi-user-eks.yaml
kubectl apply -f argocd/applications/fastapi-admin-eks.yaml
argocd app sync fastapi-user-eks fastapi-admin-eks
```

GKE/AKS equivalents follow the same shape — only `source.path` and
`destination.namespace` change.
