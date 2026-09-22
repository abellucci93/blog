---
date: '2026-10-08T09:00:00Z'
title: 'kubectl auth can-i: Quick Permission Auditing'
category: ['cka']
---

## Problem

You bound a `developer` Role to user `dev-user`, and before rolling it out you want to know exactly what that user can touch. Reading Role YAML by eye is slow and lies when several Roles and ClusterRoles intersect. You need the **authorization decision** as it is actually computed.

## Context

RBAC pairs a namespace-scoped `Role` (rules of `apiGroups`, `resources`, `verbs`) with a `RoleBinding` (`subjects` + `roleRef`). The API server makes the allow/deny call; `kubectl auth can-i` asks it using your current context by default, and `--as dev-user` impersonates another user without switching kubeconfig. `-n` scopes the check to a namespace.

## Solution

Check your own rights, then impersonate to audit `dev-user`:

```
kubectl auth can-i create deployments
# yes
kubectl auth can-i delete nodes
# no
kubectl auth can-i create deployments --as dev-user
# no
kubectl auth can-i create pods --as dev-user
# yes
```

The answer reflects every binding the user accumulates across Roles and ClusterRoles — one command beats grepping YAML.

You can also narrow a Role to named objects only with `resourceNames`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "create", "update"]
  resourceNames: ["blue", "orange"]
```

**Verify the restriction with one impersonated check:**

```
kubectl auth can-i get pods/blue --as dev-user
```

## When to use

* Auditing what a user or ServiceAccount can do without switching contexts.
* Deciding whether a `permission denied` is an RBAC gap or an app bug.
* Sanity-checking a Role or ClusterRole right after creating its binding.