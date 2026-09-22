---
date: '2026-10-14T14:00:00Z'
title: 'Feature Flags vs Feature Branches: Safer Releases'
category: ['devops']
---

## Problem

You build a new UI on a long-lived branch. Meanwhile `main` races ahead, the branch needs constant merging, and the one person who knows it is away while production waits. Shipping is coupled to *merging*, and every merge is where all the risk concentrates.

## Context

A **feature branch** isolates code until merge: development and the deploy happen at the same moment, and the merge is where all the risk concentrates. A **feature flag** decouples deploy from release: the code ships to production behind a toggle that defaults to off, so merging is boring and can happen constantly. Trunk-based development with flags means any commit is potentially deployable, and the release is flipping a switch — reversible in seconds, no rollback needed.

## Solution

Ship the new code behind a flag read at runtime, defaulting to the old behavior:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-flags
data:
  FEATURE_NEW_UI: "false"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
        - name: app
          image: app:2.4.1
          envFrom:
            - configMapRef:
                name: feature-flags
```

Production now runs release `2.4.1` with the new UI dormant. Roll it out to a pilot set, widen it, and flip it off instantly if anything misbehaves:

```
kubectl set env deploy/app FEATURE_NEW_UI=true
```

**Verify it directly** — confirm the toggle is live before routing real traffic:

```
kubectl get configmap feature-flags -o jsonpath='{.data.FEATURE_NEW_UI}{"\n"}'
```

Flags carry a cleanup cost: once the feature is fully on, delete the flag and its conditional branches. Branches remain the right tool for long, isolated experiments that will not ship in pieces.

## When to use

* Deploys you want to make reversible in seconds without a rollback.
* Trunk-based development with many small merges.
* Gradual exposure: canary by flag percentage, not by branch.
* When merging is the bottleneck and deploy is not the same as release.