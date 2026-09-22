---
date: '2026-09-25T19:00:00Z'
title: 'Rolling Back a Failed Deployment with kubectl rollout undo'
category: ['cka']
---

## Problem

You rolled out `nginx:1.9.1` and the app misbehaves. The new version is running everywhere and you need the last known-good revision back, fast, without hand-editing manifests.

## Context

Every change to a Deployment starts a **rollout** and creates a new **revision**. The default **rolling update** strategy brings up the new ReplicaSet gradually while the old one still serves traffic. Kubernetes keeps the previous ReplicaSets around precisely so you can fall back: `kubectl rollout undo` scales the new ReplicaSet down and scales the old one back up.

Review what is recorded before rolling back:

```
kubectl rollout history deployment/myapp-deployment
```

Each revision maps to a ReplicaSet; `kubectl get replicasets` shows the current release at the desired count and the previous version at zero.

## Solution

Roll back without touching any manifest:

```
kubectl rollout undo deployment/myapp-deployment
```

The Deployment controller restores pods from the previous ReplicaSet. Confirm the switch by listing ReplicaSets after the undo — the previously retired one is scaled back to full `READY` while the broken one drops to zero.

If the last revision is also bad, target an older one directly:

```
kubectl rollout undo deployment/myapp-deployment --to-revision=1
```

**Verify the restore finished and pods are healthy**:

```
kubectl rollout status deployment/myapp-deployment
```

A successful output reports the deployment rolled out; `kubectl get deployment myapp-deployment -o yaml` shows the restored image tag line. Recall that `kubectl set image` never rewrites your manifest file, so fix the file to match after the undo.

## When to use

* A Deployment rolled out cleanly but the new image is broken.
* You need to fall back to a specific older revision.
* Any time the rolling update is marked `Progressing: False` in `kubectl describe deployment` and you want the previous state restored.