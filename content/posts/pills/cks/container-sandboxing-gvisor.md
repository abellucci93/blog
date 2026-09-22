---
date: '2026-10-07T09:00:00Z'
title: 'Container Sandboxing with gVisor'
category: ['cks']
---

## Problem

A container is a process on the host that shares one Linux kernel with every other container. A kernel exploit such as Dirty COW can compromise that shared kernel, and one breached container then exposes the host and every neighbor on it. Seccomp and AppArmor narrow what a container can do, but every syscall still lands on the same kernel.

## Context

A VM gets a dedicated kernel per guest, so a compromise stays inside that guest. Containers skip the VM isolation layer: application, libraries, and processes all sit above a single kernel. gVisor closes part of that gap by inserting an **isolation layer between the container and the Linux kernel**.

gVisor architecture:

* **Sentry** acts as an independent application-level kernel. It intercepts syscalls from container processes and handles them, so calls never touch the host kernel directly.
* **Gofer** is a dedicated process that proxies file access from the Sentry to the host filesystem.
* Network traffic flows through gVisor's **own network stack** instead of the host's.

Because Sentry implements a minimal, container-specific syscall surface, the exploitable attack surface is smaller than the full Linux kernel.

## Solution

Run the gVisor runtime (`runsc`) on the node and select it per pod via `RuntimeClass`, which ties the pod to the gVisor sandbox at schedule time:

```
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
---
apiVersion: v1
kind: Pod
metadata:
  name: gvisor-demo
spec:
  runtimeClassName: gvisor
  containers:
  - name: app
    image: nginx
```

Every syscall from `gvisor-demo` is now handled by the Sentry before it reaches the kernel, and file I/O is proxied through the Gofer.

**Verify it directly** — the pod must schedule and reach `Running`:

```
kubectl get pod gvisor-demo
```

Both `READY` and `STATUS` at `Running` confirm the gVisor sandbox started. If an application hits an unsupported syscall, the pod's `Events` describe what was denied.

## When to use

* **Multi-tenant clusters** where untrusted workloads run beside trusted ones.
* Workloads needing stronger isolation than seccomp and AppArmor profiles.
* Not for latency- or CPU-sensitive apps: syscall interception adds overhead, so test every image for compatibility.