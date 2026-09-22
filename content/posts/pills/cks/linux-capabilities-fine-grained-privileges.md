---
date: '2026-09-27T19:00:00Z'
title: 'Linux Capabilities: Fine-Grained Privilege Control'
category: ['cks']
---

## Problem

You open a shell in a pod as root and try to sync the clock:

```
kubectl run --rm -it ubuntu-sleeper --image=ubuntu -- bash
# (root@ubuntu-sleeper) date -s '19 APR 2012 22:00:00'
# date: cannot set date: Operation not permitted
```

Root is supposed to mean full power, yet the write is refused even with seccomp unconfined. The runtime hides part of root's authority — and that is a feature, not a bug.

## Context

Before kernel 2.2 a process was either privileged (root, `UID 0`) or not. Kernel 2.2 split the superuser's powers into small units called **capabilities**:

* `CAP_CHOWN` — change file ownership.
* `CAP_NET_ADMIN` — configure network interfaces and routing.
* `CAP_SYS_BOOT` — reboot the system.
* `CAP_SYS_TIME` — set the system clock.

Container runtimes start containers with **only a default set of about 14 capabilities** — for example `CAP_CHOWN`, `CAP_SETUID`, `CAP_NET_BIND_SERVICE`, `CAP_KILL`. `CAP_SYS_TIME` is not among them, so changing the date fails even as `UID 0`.

You can inspect capability requirements on a host:

```
getcap /usr/bin/ping
# /usr/bin/ping = cap_net_raw+ep
getpcaps <pid>
```

## Solution

Adjust the set per container in its `securityContext`:

```
apiVersion: v1
kind: Pod
metadata:
  name: time-syncer
spec:
  containers:
  - name: ubuntu
    image: ubuntu
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        add: ["CAP_SYS_TIME"]
        drop: ["CAP_CHOWN"]
```

* `add` grants a capability the default set lacks — here the container may change the clock.
* `drop` removes one — after dropping `CAP_CHOWN`, `chown` stops working.

**Verify it** — rerun the date command inside the pod:

```
kubectl exec -ti time-syncer -- bash -c "date -s '19 APR 2012 22:00:00'"
# Thu Apr 19 22:00:00 UTC 2012
```

Without `CAP_SYS_TIME` the same command returns `Operation not permitted`.

## When to use

* Least privilege: start from the default set, `drop` what the workload does not need, `add` a missing capability only when the failure demands it.
* Debugging `Operation not permitted` in a root container: first suspect is a missing capability, not a permissions misconfiguration.
* System hardening — a widened capability set is as dangerous as root itself.