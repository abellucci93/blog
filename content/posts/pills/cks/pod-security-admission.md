---
date: '2026-10-11T09:00:00Z'
title: 'Pod Security Admission: Replacing PodSecurityPolicies'
category: ['cks']
---

## Problem

You are upgrading a cluster that relies on **PodSecurityPolicy (PSP)** to keep containers from running privileged or as root. PSP was deprecated in Kubernetes 1.21 and removed in 1.25, so it stops working. Recreating the same gates is painful even where PSP still runs: a pod is denied only when an RBAC `use` binding grants the policy, there is no audit or dry-run mode, and a misconfigured setup silently blocks every pod creation request.

## Context

PSP was itself an admission controller, but the indirection made it brittle: you could not tell which policy applied to a pod, changing pod defaults was only partially supported, and there was no safe way to assess impact before enforcing. That usability is what drove KEP-2579.

**Pod Security Admission (PSA)** is the built-in replacement. It is enabled by default, needs no extra components, and enforces a **Pod Security Standard (PSS)** — one of `privileged`, `baseline`, `restricted` — at **namespace** level. It is not mutating: it never rewrites pod fields, it only accepts, warns, or rejects.

Three modes, each a namespace label:

* `enforce` — reject non-compliant pods.
* `audit` — allow, record violations in the audit log.
* `warn` — allow, return a warning to the user.

A namespace can carry one label per mode with a different level each. Escalating a level later can leave already-running pods non-compliant, so roll out lowest impact first. Rules PSA cannot express belong to a policy-as-code tool such as **Kyverno** or **OPA Gatekeeper**.

## Solution

Label each namespace with a mode and a level:

```
kubectl label ns payroll pod-security.kubernetes.io/enforce=restricted
kubectl label ns hr pod-security.kubernetes.io/enforce=baseline
kubectl label ns dev pod-security.kubernetes.io/warn=restricted
```

Daily policy lives entirely in these labels: no policy objects, no RBAC bindings. Confirm the built-in controller is actually running first:

```
kubectl exec -n kube-system kube-apiserver-controlplane -- kube-apiserver -h | grep enable-admission-plugins
```

**Verify it directly** — try to run a pod that violates `restricted` in the enforced namespace:

```
kubectl run nginx --image=nginx -n payroll
```

It fails with `pods "nginx" is forbidden: violates PodSecurity "restricted"`. Repeat in `dev` and the pod is created with a warning instead, proving that `warn` mode is active. To roll a namespace from legacy policy to PSA, go `audit` first, review the logs, then `warn`, then `enforce`.

## When to use

* Replacing PSP before upgrading past Kubernetes 1.25.
* Rolling out standards gradually: `audit`, then `warn`, then `enforce` per namespace.
* Enforcing baseline security cluster-wide with zero add-on installs.