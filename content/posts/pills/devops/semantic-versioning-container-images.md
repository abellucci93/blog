---
date: '2026-09-22T09:00:00Z'
title: 'Why latest Is Bad: Versioning Container Images'
category: ['devops']
---

## Problem

Your Deployment says `image: nginx` and another says `image: your-app:latest`. Today `nginx` pulls 1.25, next week `latest` pulls a freshly pushed 1.26. The same YAML that was blessed by QA now runs a different binary in production, and you cannot say which one.

## Context

An image name expands to `registry/repository:tag`. The default registry is Docker Hub (`docker.io`), and a bare `nginx` means `docker.io/library/nginx`. A tag — including `latest` — is a **mutable pointer** that a registry can move at any time. The digest (`sha256:...`) is bound to the exact image content and cannot move. For supply-chain safety each manifest should reference content you actually scanned and approved, stored in a registry you control.

## Solution

Build and push once with a real version, then capture its immutable identifier:

```
docker build -t your-registry.io/apps/api:2.4.1 .
docker push your-registry.io/apps/api:2.4.1
docker inspect your-registry.io/apps/api:2.4.1 --format '{{index .RepoDigests 0}}'
```

Pin the pod to the exact digest:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: api
spec:
  containers:
    - name: api
      image: your-registry.io/apps/api@sha256:2fcaf026b8acb7a...
  imagePullSecrets:
    - name: regcred
```

Private registries are a prerequisite: keep internal images out of the public Hub. `latest` and mutable tags make rollback and auditing guesswork; a digest makes the deployed byte string reproducible forever. If you keep a moving tag for convenience, keep it alongside the digest pin, never instead of it.

**Verify it directly** — confirm the exact image reference the pod actually runs:

```
kubectl get pod api -o jsonpath='{.spec.containers[0].image}{"\n"}'
```

`your-registry.io/apps/api@sha256:...` proves there is no `latest` anywhere in the path.

## When to use

* Any manifest that must be reproducible: production, signed images, audit trails.
* Pull-through caches and private registries where moving tags defeat their purpose.
* Supply-chain scanning: you can only attest to a build you can identify precisely.
* CI/CD that promotes the same digest through staging into production.