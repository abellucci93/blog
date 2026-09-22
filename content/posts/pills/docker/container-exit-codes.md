---
date: '2026-10-10T09:00:00Z'
title: 'Container Exit Codes: Reading the Signals'
category: ['docker']
---

## Problem

A container keeps restarting but `kubectl get pods` only reports `CrashLoopBackOff`. The phase tells you a restart is happening; it does not tell you why the main process died. That reason is encoded in the **exit code** the container's primary process returned, and you have to read it explicitly.

## Context

Every container process ends by returning an **exit code** to the container runtime. Kubernetes stores it in the container's state so you can inspect it after the fact:

* `0` — clean exit; the process finished intentionally.
* **1–127** — the application itself failed: bad config, missing file, unhandled exception.
* **128 + N** — the process was killed by signal `N`. `137` is `128 + 9` (SIGKILL, typical of an OOM kill), `143` is `128 + 15` (SIGTERM, a graceful shutdown that did not complete in time).

Exit codes are part of the **container state**, not the pod phase. A pod can stay `Running` while a container is silently restarting, or go `Failed` because one container exited non-zero.

## Solution

The exit code and the reason for termination are both in the container's state, under the last terminated state:

```
kubectl describe pod myapp-pod
...
Last State:             Terminated
  Reason:               OOMKilled
  Exit Code:            137
  Finished At:          2027-05-02T09:00:00Z
```

Read the pair **exit code + reason** together:

* **137 + OOMKilled** — the kernel killed the process for exceeding its memory limit. Fix the leak or raise the limit.
* **137 without OOMKilled** — the process received SIGKILL from another source, such as node eviction.
* **1–127** — the application crashed on its own; the exit code points at the failure path. Read `kubectl logs myapp-pod --previous` for the last output.
* **0** — the process exited cleanly; a restart loop here is the **restart policy** retrying a finished task, not a crash.

**Verify it directly** — read the recorded exit code from a running or terminated pod:

```
kubectl get pod myapp-pod -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}{"\n"}'
```

## When to use

* Debugging a `CrashLoopBackOff` to separate "app crashed" from "runtime killed it".
* Confirming an OOM kill before tuning memory limits.
* Deciding whether a `0` exit means success or a restart-policy problem.
* Scripting checks over `kubectl get` fields instead of parsing `describe` prose.