---
date: '2026-09-22T19:00:00Z'
title: 'Resource Requests vs Limits: What Happens When You Exceed Them'
category: ['cka']
---

## Problem

Pods behave differently under the same load: one gets throttled, another gets killed, a third never runs at all. Without knowing what each `resources` field controls, you cannot predict which outcome to expect.

## Context

`requests` are the **guaranteed minimum** a node must reserve; the scheduler only places a pod on nodes that can provide them. `limits` are the **cap** on what a container may consume. The failure modes differ by resource:

* **CPU** is compressible — a container over its limit is **throttled** and keeps running, just slower.
* **Memory** is not compressible — a container over its limit is **terminated** with an OOM (out of memory) kill.
* If no node can satisfy the **requests**, the pod stays `Pending`; `kubectl describe` shows events like `Insufficient cpu`.

Asymmetries matter too:

* **Limits without requests** — Kubernetes assumes the request equals the limit.
* **No limits** — the container may consume everything on the node and starve neighbours.

## Solution

Declare both fields explicitly:

```
apiVersion: v1
kind: Pod
metadata:
  name: simple-webapp-color
spec:
  containers:
    - name: simple-webapp-color
      image: simple-webapp-color
      resources:
        requests:
          memory: "1Gi"
          cpu: 1
        limits:
          memory: "2Gi"
          cpu: 2
```

The pod is guaranteed 1 CPU and 1Gi, can burst up to 2 CPU before being throttled, and is killed if memory exceeds 2Gi.

**Verify actual usage and termination reason**:

```
kubectl describe pod simple-webapp-color
```

The output's `Requests` and `Limits` mirror the manifest; a `State: Terminated` with `Reason: OOMKilled` proves a memory-limit breach, while a CPU breach throttles without producing any event.

## When to use

* Setting a memory **limit** whenever a runaway process must not take down the node.
* Setting **requests** so the scheduler reserves capacity up front.
* Adding a namespace **LimitRange** so containers without explicit values get sane defaults instead of running unrestricted.