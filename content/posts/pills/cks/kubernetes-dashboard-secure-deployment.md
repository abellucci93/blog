---
date: '2026-09-28T19:00:00Z'
title: 'Kubernetes Dashboard: Secure Deployment Checklist'
category: ['cks']
---

## Problem

The dashboard renders cluster state — including **secrets** — in the browser. Deployed with its default permissive posture and exposed externally, it becomes a standing exploit target: unsecured dashboards were used in real cryptojacking incidents (for example the Tesla attack reported by RedLock). You want the UI without handing cluster-admin powers to anyone who reaches it.

## Context

`kubectl apply -f .../recommended.yaml` creates the `kubernetes-dashboard` namespace with a Deployment, a ClusterIP Service, ConfigMaps, and Secrets. The default service is **ClusterIP**, so it is internal-only — good. Two decisions set your security posture:

* **How the dashboard is reached** — tunnel it, do not expose it.
* **What identity logs in and with which permissions** — least privilege, never the default examples that grant cluster-admin.

## Solution

Follow this checklist for a dashboard that shows cluster state without weakening the cluster:

1. Deploy from the maintained manifest:

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

2. Access via **`kubectl proxy`**, not a NodePort or LoadBalancer:

```
kubectl proxy
```

Reach the dashboard only at `http://127.0.0.1:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/`. Altering the Service to `NodePort` or `LoadBalancer` re-opens the external attack surface — avoid it. Keeping the ClusterIP default, an authentication proxy such as OAuth2 Proxy is the only acceptable alternative for team-wide access.

3. Create a **dedicated ServiceAccount** and bind only the permissions the user needs — namespace-scoped, not `cluster-admin`:

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dashboard-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dashboard-user
  namespace: web
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: view
subjects:
- kind: ServiceAccount
  name: dashboard-user
  namespace: kubernetes-dashboard
```

**Verify it here** — mint the login token and scope-check the binding:

```
kubectl -n kubernetes-dashboard create token dashboard-user
kubectl -n web get rolebindings dashboard-user -o jsonpath='{.roleRef.name}'
```

The printed token signs you into the dashboard; the output confirms it is a namespace-scoped `view` role, not cluster-admin.

## When to use

* Any cluster where a web UI is wanted but the cluster-admin habit has not been adopted.
* Teams that must inspect resources without granting write or cross-namespace rights.
* Environments where the dashboard must stay reachable only through the developer's tunnel and an authenticated session.