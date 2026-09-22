---
date: '2026-10-02T14:00:00Z'
title: 'ArgoCD Sync Waves: Ordering Resource Deployment'
category: ['devops']
---

## Problem

An Application deploys a Namespace, a Secret, a database Deployment, and an app Deployment that depends on both. ArgoCD syncs them in one pass and the ordering is not what you need: the app pod can start before the Secret and the database exist, crash-looping and making the sync report failed health checks.

## Context

Within one sync, ArgoCD applies resources in a default order based on resource kind, not on dependency. To control ordering you annotate each resource with **sync waves**. ArgoCD groups resources by wave; lower numbers run first and negative waves are allowed. A wave is applied only after every resource in the previous wave is healthy, so a database wave finishes before the app wave even starts.

## Solution

Tag the dependencies with a low or negative wave and the consumer with a higher one:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: blog
  annotations:
    argocd.argoproj.io/sync-wave: "-5"
---
apiVersion: v1
kind: Secret
metadata:
  name: db-creds
  namespace: blog
  annotations:
    argocd.argoproj.io/sync-wave: "-3"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blog-db
  namespace: blog
  annotations:
    argocd.argoproj.io/sync-wave: "-2"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blog-app
  namespace: blog
  annotations:
    argocd.argoproj.io/sync-wave: "0"
```

Sync order becomes: Namespace first, then the Secret, then the database, and only after the database is healthy the app Deployment. A common convention is `-5` for namespaces and CRDs, `-3` for secrets and configmaps, and `0` for workloads.

**Verify it directly** — confirm the wave annotation reached the deployed resource:

```
kubectl get deploy blog-db -n blog -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}{"\n"}'
```

## When to use

* Resources with real dependencies: secrets, configmaps, databases, CRDs.
* Syncs that race to create controllers before the custom resources they manage.
* Any Application whose first sync is flaky and needs deterministic ordering.
* Where a wave must fully succeed before the next group is even touched.