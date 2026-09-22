---
date: '2026-10-03T14:00:00Z'
title: 'Docker Resource Limits: Memory and CPU'
category: ['docker']
---

## Problem

A single container consumes every free byte of memory or every CPU cycle on the node, starving the other pods and the system processes. Or the pod is created and sits `Pending` forever because no node has room. Without explicit resource requests and limits, a container is allowed to take as much as the node has.

## Context

Two knobs exist per container, each with a different job:

* **requests** — the minimum the scheduler guarantees the container. The pod is only scheduled on a node that can satisfy the request; if none can, the pod stays `Pending` with an `Insufficient cpu` or `Insufficient memory` event.
* **limits** — a hard cap on usage. CPU over the limit gets **throttled** (slowed down); memory over the limit cannot be throttled, so the process is killed with an **OOM** error.

CPU is measured in cores, and `0.1` is written as `100m`. By default no requests or limits are set, so nothing stops a pod from using all available resources on its node.

## Solution

Declare requests and limits in the container spec — requests drive scheduling, limits drive enforcement:

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

The four configuration scenarios behave differently:

* **Neither set** — the container may consume all free node resources, starving neighbors.
* **Limits only** — Kubernetes assumes the request equals the limit (a `3` vCPU limit implies a `3` vCPU request), so the pod is hard to place.
* **Both set** — the request is guaranteed and the container can burst up to the limit.
* **Requests only** — the request is guaranteed and idle capacity is usable, but memory can still exceed and be OOM-killed.

CPU throttles when the limit is hit; memory does not — exceeding a memory limit terminates the container with an OOM error. To apply defaults namespace-wide, use a **LimitRange**; a **ResourceQuota** caps the namespace's aggregate consumption.

**Verify it directly** — check what enforcement actually did to the pod:

```
kubectl describe pod simple-webapp-color | grep -i 'oomkilled\|insufficient'
```

## When to use

* Any pod competing for shared node resources.
* Diagnosing `Pending` pods stuck on `Insufficient cpu` or `Insufficient memory`.
* Stopping one container from OOM-killing or starving its neighbors.
* Enforcing namespace-wide defaults with `LimitRange` and `ResourceQuota`.