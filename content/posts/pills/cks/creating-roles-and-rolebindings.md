---
date: '2026-10-08T14:00:00Z'
title: 'Creating Roles and RoleBindings: Step by Step'
category: ['cks']
---

## Problem

Default cluster access is all-or-nothing: hand `dev-user` the kubeconfig and they can `delete nodes` as easily as `get pods`. The requirement is narrow — manage pods and create ConfigMaps, nothing else.

## Context

RBAC attaches a **Role** (a set of allowed actions) to a **subject** (user, group, or service account) through a **RoleBinding**. Three facts determine everything else:

* Both objects use `apiVersion: rbac.authorization.k8s.io/v1`.
* **Role** and **RoleBinding** are namespaced, so a grant in `default` reaches only that namespace.
* **rules** list `apiGroups`, `resources`, and `verbs`; `resourceNames` narrows verbs to specific named objects.
* **subjects** name the recipient: a `User`, `Group`, or `ServiceAccount`.

## Solution

Create the role in the `default` namespace:

```
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list", "get", "create", "update", "delete"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["create"]
```

Bind it to `dev-user`:

```
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: devuser-developer-binding
subjects:
- kind: User
  name: dev-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

Apply and inspect:

```
kubectl create -f developer-role.yaml
kubectl create -f devuser-developer-binding.yaml
kubectl get roles,rolebindings
```

**Verify it directly** — impersonate the user to confirm exactly what they can do:

```
kubectl auth can-i create pods --as=dev-user
```

It prints `yes`; `kubectl auth can-i delete nodes --as=dev-user` prints `no`.

To restrict further, add `resourceNames: ["blue", "orange"]` to the pods rule so the verbs apply only to those two named pods.

## When to use

* Granting least-privilege access to a user, group, or service account in one namespace.
* Confirming effective permissions without switching accounts.
* Reaching cluster-wide scope only through `ClusterRole` and `ClusterRoleBinding`.