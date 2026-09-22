---
date: '2026-10-17T09:00:00Z'
title: 'Pod Security Standards: Privileged, Baseline, Restricted'
category: ['cks']
---

## Problem

A single namespace label decides what everything in that namespace may run. Set `restricted` for a workload that genuinely needs the host and you break it; set `privileged` and insecure pods sail through. The profiles are cumulative, so the choice is really about what the workload requires at runtime — and picking wrong is a silent outage or a silent hole.

## Context

**Pod Security Standards (PSS)** define three cumulative policies that **Pod Security Admission (PSA)** evaluates against every pod. The label value selects the level:

* **Privileged** — deliberately unrestricted: privileged containers, host namespaces, any volume or capability. Meant for system-level components (CNI, logging agents, storage drivers) that need direct host access.
* **Baseline** — prevents known privilege escalation while allowing the default pod configuration with minimal changes: no `privileged`, no `hostNetwork`/`hostPID`/`hostIPC`, no `hostPath` volumes or `hostPort`, and no added Linux capabilities. Fits most containerized applications.
* **Restricted** — hardening best practices on top of baseline: must run as a non-root user (`runAsNonRoot`), no added capabilities, seccomp `RuntimeDefault`, restricted volume types, read-only root filesystem recommended. Best for security-critical workloads; may break some apps.

A mode (`enforce`, `audit`, `warn`) sets the reaction to a violation, and a level describes what is forbidden. The two go together on the namespace:

```
kubectl label ns payroll pod-security.kubernetes.io/enforce=restricted
kubectl label ns hr pod-security.kubernetes.io/enforce=baseline
kubectl label ns dev pod-security.kubernetes.io/warn=restricted
```

## Solution

Read a pod spec to see what each level actually demands. Privileged runs anything:

```
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
spec:
  containers:
  - name: privileged-container
    image: nginx
    securityContext:
      privileged: true
```
Baseline accepts the default pod, but escalation must be off:
```
apiVersion: v1
kind: Pod
metadata:
  name: baseline-pod
spec:
  containers:
  - name: baseline-container
    image: nginx
    securityContext:
      allowPrivilegeEscalation: false
```
Restricted layers least-privilege settings on top — non-root, runtime seccomp, read-only filesystem:
```
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: restricted-container
    image: nginx
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      readOnlyRootFilesystem: true
```

**Verify it directly** — the same nginx pod against `payroll` (`restricted`) is refused, against `hr` (`baseline`) admitted, because it runs the process as root:

```
kubectl run nginx --image=nginx -n payroll --dry-run=server
```

## When to use

* Explaining why a pod fails admission: each profile names the exact field rejected.
* Auditing existing pods against `audit` or `warn` levels before tightening.