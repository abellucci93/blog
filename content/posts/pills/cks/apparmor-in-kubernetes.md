---
date: '2026-10-13T09:00:00Z'
title: 'AppArmor in Kubernetes: Profiles and Enforcement'
category: ['cks']
---

## Problem

An application that only needs to print a message and sleep can still write files anywhere the filesystem allows. A **Seccomp** profile limits syscalls, so it can block `mkdir`, but it cannot say "no writes under `/`" — file access is outside Seccomp's scope.

## Context

**AppArmor** is a Linux security module (LSM) that confines an application to a defined set of resources: file and directory permissions, network settings, and Linux capabilities. It is enabled by default on most distributions.

Profiles run in one of three modes:

* **Enforce** — rules are strictly applied.
* **Complain** — violations are logged but allowed.
* **Unconfined** — no restrictions applied.

A profile is a plain text file under `/etc/apparmor.d`. This one grants read access but denies all writes:

```
profile apparmor-deny-write flags=(attach_disconnected) {
    file,
    deny /** w,
}
```

For Kubernetes to use it, every worker node must have the AppArmor kernel module enabled and the profile loaded into the kernel.

## Solution

Load the profile on each worker node with the AppArmor parser:

```
apparmor_parser /etc/apparmor.d/apparmor-deny-write
```

Then reference it from the pod's `securityContext`:

```
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu-sleeper
spec:
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: apparmor-deny-write
  containers:
    - name: ubuntu-sleeper
      image: ubuntu
      command: ["sh", "-c", "echo 'Sleeping for an hour!' && sleep 1h"]
```

The legacy beta annotation `container.apparmor.security.beta.kubernetes.io/<container>` is replaced by `spec.securityContext.appArmorProfile`; `type: Localhost` with `localhostProfile` maps to the old `localhost/<profile-name>` value.

**Verify it** — a write inside the container must fail:

```
kubectl exec -ti ubuntu-sleeper -- touch /tmp/test
```

The profile denies the write with `Permission denied`, confirming enforcement; `aa-status` lists the profile and the container under enforce mode.

## When to use

* Read-only workloads that should never touch the filesystem.
* Layering on top of Seccomp when you need resource-level, not syscall-level, restrictions.
* Pods that must not silently run without their security profile.