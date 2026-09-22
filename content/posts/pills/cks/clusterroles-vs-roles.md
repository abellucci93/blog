---
date: '2026-09-25T14:00:00Z'
title: 'ClusterRoles vs Roles: Scope Matters'
category: ['cks']
---

## Problem

You bind a `Role` so a team can manage nodes, and every request returns `Forbidden`:

```
Error from server (Forbidden): nodes is forbidden: User "storage-admin" cannot list resource "nodes"
```

A namespaced `Role` only grants access to resources that live inside a namespace — it cannot reach cluster-scoped objects at all.

## Context

Kubernetes resources fall into two classes:

* **Namespaced** — pods, deployments, services, secrets, roles.
* **Cluster-scoped** — nodes, persistent volumes, certificate signing requests, namespaces.

Namespaced permissions use `Role` + `RoleBinding` and apply within a single namespace. Cluster-scoped permissions require **`ClusterRole`** + `ClusterRoleBinding`, which apply across the whole cluster. A `ClusterRole` can also express permissions for namespaced resources — and in that case those permissions apply to **every namespace** at once.

Default cluster roles such as `cluster-admin` are created automatically during cluster setup.

## Solution

Define a `ClusterRole` that can manage nodes cluster-wide:

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-administrator
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list", "get", "create", "delete"]
```

Then bind a user to it with a `ClusterRoleBinding`:

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admin-role-binding
subjects:
- kind: User
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-administrator
  apiGroup: rbac.authorization.k8s.io
```

Apply both with `kubectl create -f`. The rule uses the **core API group** (`""`) because nodes live under `/api/v1`, not a named group.

**Verify it** — confirm which resources are cluster-scoped before writing the role:

```
kubectl api-resources --namespaced=false
```

The list shows `nodes`, `persistentvolumes`, `certificatesigningrequests`, and `namespaces` — every one needs a `ClusterRole`, not a `Role`, and the bound user can now `kubectl get nodes` without `Forbidden`.

## When to use

* Granting access to nodes, PVs, CSRs, or namespaces.
* Reusing one role definition across all namespaces for namespaced resources.
* Replacing a `RoleBinding` that fails because the target resource is not namespaced.