---
date: '2026-10-04T14:00:00Z'
title: 'ArgoCD Application CRD: Declarative GitOps Deployments'
category: ['devops']
---

## Problem

You deploy to a Kubernetes cluster, but "production" is whatever someone last applied with `kubectl apply -f` from their laptop. The manifests live in Git, yet the cluster drifts: a manual scale, a hand-edited image tag, a deleted configmap. Nobody can say which version of the repo matches the running stack.

## Context

**GitOps** makes the Git repository the single source of truth for a cluster. **ArgoCD** polls the repo and forces the cluster to match what it declares, undoing manual drift. The unit that connects repo to cluster is the **Application** custom resource, a CRD installed alongside ArgoCD. One Application declares which repository, which path, and which namespace to reconcile.

Because an Application is itself a Kubernetes object, the whole setup scales: put Applications in their own GitOps repo and every deployment decision becomes a reviewed, mergable change.

## Solution

Declare an Application that tracks the `deploy/` directory of the blog repo:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: blog-app
  namespace: argocd
spec:
  project: default
  destination:
    server: https://kubernetes.default.svc
    namespace: blog
  source:
    repoURL: https://github.com/you/blog.git
    targetRevision: main
    path: deploy
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Create it like any other manifest:

```
kubectl apply -f application.yaml
```

On the next reconciliation ArgoCD syncs every manifest under `deploy/` into the `blog` namespace. With `selfHeal: true` a manual `kubectl delete pod` or `kubectl scale` is reverted; `prune: true` removes resources that were deleted from Git. Rollback is a git revert, not a `kubectl` incantation.

**Verify it directly** — read the reconciled state:

```
kubectl get application blog-app -n argocd -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
```

`Synced Healthy` means the cluster matches Git and the app is passing its health checks.

## When to use

* A cluster whose desired state should come from Git and stay in Git.
* Homelab or production where every change must be reviewable and auditable.
* Multiple environments tracking different branches or tags of the same repo.
* You already run ArgoCD and want deployment config versioned like application code.