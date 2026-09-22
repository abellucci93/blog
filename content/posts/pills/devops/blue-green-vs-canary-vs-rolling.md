---
date: '2026-10-11T19:00:00Z'
title: 'Blue-Green vs Canary vs Rolling: Deployment Strategies'
category: ['devops']
---

## Problem

You update `myapp-deployment` from `nginx:1.7.1` to `nginx:1.9.1`. Scale everything down first, release the new version, scale up: the site is unreachable during the switch. With five replicas and a live audience, that downtime is the whole problem.

## Context

A **Deployment** creates a **ReplicaSet** per version, and each rollout records a **revision** you can return to. The `strategy` field decides how old and new pods overlap. Three strategies solve the same problem differently:

* **Recreate** — kill all old pods, then start new ones. Simple, but a hard outage window.
* **Rolling update** — replace pods one by one, keeping capacity up. This is the Kubernetes default, tuned with `maxUnavailable` and `maxSurge` (by default `25%` each).
* **Blue-green** — run the new version alongside the old, then switch traffic at the router; rollback is switching back.
* **Canary** — route a small percentage of traffic to the new version and widen it as confidence grows.

## Solution

A manifest showing the Kubernetes-native end of the spectrum:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-deployment
spec:
  replicas: 5
  selector:
    matchLabels:
      app: myapp
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: nginx-container
          image: nginx:1.7.1
```

Change `type: Recreate` to `type: RollingUpdate` and Kubernetes replaces five pods gradually instead of dropping them all. Trigger the rollout and watch it:

```
kubectl set image deployment/myapp-deployment nginx-container=nginx:1.9.1
kubectl rollout status deployment/myapp-deployment
kubectl rollout history deployment/myapp-deployment
```

A bad release is forgiven with one command:

```
kubectl rollout undo deployment/myapp-deployment
```

The choice leaks into the output: a Recreate deployment shows events `Scaled down old ReplicaSet to 0` then `Scaled up new to 5`; a rolling update interleaves small scale-ups and scale-downs between the two ReplicaSets.

**Verify it directly** — the rollout finishes only when the new pods are ready:

```
kubectl rollout status deployment/myapp-deployment --watch
```

## When to use

* **Rolling** — the default for most services that can run two versions side by side; zero config.
* **Recreate** — batch jobs or apps that cannot run two versions at once, and downtime is acceptable.
* **Blue-green** — you want instant rollback and identical, pre-warmed infrastructure.
* **Canary** — risky changes where you want traffic-based confidence before the full rollout.