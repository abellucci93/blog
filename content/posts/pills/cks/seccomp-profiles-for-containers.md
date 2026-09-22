---
date: '2026-10-15T19:00:00Z'
title: 'Seccomp Profiles: Restricting Syscalls in Containers'
category: ['cks']
---

## Problem

A container shares the node kernel, and that kernel exposes over 400 system calls to every process inside it. Most are never needed by an application — yet if one of them is vulnerable it becomes the escape hatch. Dirty COW (CVE-2016-5195) hit a race in the kernel let a process escalate to root by writing to read-only files; a kernel bug is exactly as reachable as your container's syscalls permit. Even `touch` fires off ~32 syscalls, so you must scope what a container may call instead of trusting every process to behave.

## Context

A **syscall** — `open`, `close`, `execve`, ... — is the only way a process in user space asks the kernel for anything. **Seccomp** (Linux >= 2.6.12) filters those calls with a profile:

* Mode 0: seccomp off.
* Mode 1: strict — only `read`, `write`, `exit`, `sigreturn`.
* Mode 2: filter — a BPF-like profile decides per syscall.

Docker ships a default **Mode 2** profile that blocks ~60 syscalls (mount, module loading, clock setup) — that is why `date -s` fails inside a stock container. Kubernetes does **not** apply it, so without a profile a pod's `Seccomp` is disabled and far fewer calls are blocked. When you write a profile, prefer a **whitelist**: `defaultAction: SCMP_ACT_ERRNO` denies everything not explicitly allowed, whereas a blacklist that allows by default can miss the one dangerous syscall.

## Solution

Opt a pod in with the built-in runtime profile:

```
apiVersion: v1
kind: Pod
metadata:
  name: amicontained
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - image: r.j3ss.co/amicontained
    name: amicontained
```

For your own profile, drop a JSON file on each node under `/var/lib/kubelet/seccomp` and reference it via `Localhost`:

```
apiVersion: v1
kind: Pod
metadata:
  name: test-custom
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/custom.json
  containers:
  - image: ubuntu
    name: ubuntu
```

`profiles/custom.json` resolves relative to the kubelet directory. A log-everything whitelist reveals what the app actually calls before you tighten it:

```
{
  "defaultAction": "SCMP_ACT_LOG"
}
```

**Verify it directly** — deploy the amicontained pod and read its own report:

```
kubectl logs amicontained
```

With `RuntimeDefault` it reports `Seccomp: filtering` and ~64 blocked syscalls; without any profile it reports `Seccomp: disabled`. Push too far — a profile whose `defaultAction` is `SCMP_ACT_ERRNO` and nothing allowed — and the pod lands on `ContainerCannotRun`, which is the profile telling you it works.

## When to use

* Any pod running untrusted or internet-facing code on a shared node.
* Hardening against kernel CVE exploitation once you have traced the real syscalls.
* Enforcing `RuntimeDefault` at scale via the `restricted` standard or a policy engine.