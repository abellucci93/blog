---
date: '2026-10-17T14:00:00Z'
title: 'Rolling Updates vs Recreate: Choosing a Deployment Strategy'
category: ['cka']
---

## Problem

You bump the image from `nginx:1.7.0` to `nginx:1.7.1` in a deployment running five replicas, apply it, and the app goes dark: requests fail until the rollout finishes. The deployment's `strategy` field decides whether that outage window exists.

## Context

A change to the pod template starts a new **rollout** and a new **revision**. Two strategies control how the old and new ReplicaSets swap:

* **Recreate** — scales the old ReplicaSet down to `0` first, then scales the new one up. The application is fully unavailable during the transition.
* **RollingUpdate** — scales up new pods and scales down old ones gradually, keeping replicas available at all times. This is the **default** when no `strategy` is set.

Track any rollout with:

```
kubectl rollout status deployment/myapp-deployment
kubectl rollout history deployment/myapp-deployment
```

## Solution

Declare the strategy in the deployment spec:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-deployment
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: nginx-container
        image: nginx:1.7.1
```

Update from the manifest, or hot-set the image:

```
kubectl apply -f deployment-definition.yml
kubectl set image deployment/myapp-deployment nginx-container=nginx:1.9.1
```

`kubectl set image` does not touch the manifest file, so edit the YAML too or the next `apply` reverts the image.

Verify the strategy by watching ReplicaSet events — RollingUpdate interleaves scale-up and scale-down; Recreate shows "scaled down to 0" before the new set scales up:

```
kubectl describe deployment myapp-deployment
kubectl get replicasets
```

A bad release rolls back to the previous revision:

```
kubectl rollout undo deployment/myapp-deployment
```

## When to use

* **RollingUpdate** — anything serving live traffic; zero-downtime replaces matter.
* **Recreate** — one-off or batch workloads where two versions must never run together.
* **Rollout undo** — whichever strategy you chose, when the shipped revision misbehaves.