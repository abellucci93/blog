---
date: '2026-09-30T19:00:00Z'
title: 'Mutable vs Immutable Infrastructure: Why It Matters'
category: ['cks']
---

## Problem

Three web servers run Nginx 1.17. The 1.19 upgrade rolls onto servers 1 and 2, but server 3 is missing a dependency — network blip, out of disk, OS difference — and stops at 1.18. The pool now runs two versions. Every future update and every incident must account for a fleet that behaves differently per box: **configuration drift**.

## Context

**Mutable infrastructure** updates existing servers in place — release notes applied by scripts, config management (Ansible), or a human. Software and config change while the hardware stays.

**Immutable infrastructure** never touches a running server. A change means provisioning a new server with the new version and decommissioning the old one. Every instance starts from a standardized, unchanged state, so drift is impossible by construction.

Containers suit this model: they are generated from images, so an update is an **image change plus a rolling redeploy**, not an in-place patching session. Yet a running container can still be modified — copy a file in, open a shell. Immutability at runtime must be enforced.

## Solution

Freeze the root filesystem and mount writable volumes only where the app writes:

```
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    run: nginx
spec:
  containers:
  - image: nginx
    name: nginx
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: cache-volume
      mountPath: /var/cache/nginx
    - name: runtime-volume
      mountPath: /var/run
  volumes:
  - name: cache-volume
    emptyDir: {}
  - name: runtime-volume
    emptyDir: {}
```

Nginx needs `/var/run` (runtime data) and `/var/cache/nginx` (cache); without those volumes the pod lands in `Error`. With them it starts while the rest of the filesystem stays read-only.

**Verify it** — try to write into the container:

```
kubectl exec -ti nginx -- apt update
# E: List directory /var/lib/apt/lists/partial is missing. (30: Read-only file system)
```

Even a privileged container is refused — and privileged should be avoided regardless, because `/proc` writes can touch the host.

## When to use

* Rolling updates where every instance must be byte-identical to the image.
* Defense against tampering: an attacker who shells in cannot modify the filesystem.
* Enforce the pattern cluster-wide with a policy setting `privileged: false`, `readOnlyRootFilesystem: true`, and a non-root user.