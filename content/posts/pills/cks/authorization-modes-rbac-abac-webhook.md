---
date: '2026-10-01T19:00:00Z'
title: 'Authorization Modes: RBAC vs ABAC vs Webhook'
category: ['cks']
---

## Problem

A developer gets `Forbidden`:

```
Error from server (Forbidden): nodes "worker-2" is forbidden: User "developer" cannot delete resource "nodes"
```

Authentication passed — the user exists — but nothing decides what they may do. You must choose an authorization mode (or several) that maps identities to permissions.

## Context

**Authorization** runs after authentication and decides which operations are permitted. Kubernetes offers four real modes plus two trivial ones:

* **Node** — built for kubelets; authenticates identities named `system:node:*` in the `system:nodes` group.
* **ABAC** — binds permissions to users or groups directly via JSON policies; every change means editing a policy file and restarting the API server.
* **RBAC** — grants permissions through **roles** bound to users or groups; a role change propagates to every bound user.
* **Webhook** — the API server calls an external authorizer (e.g., Open Policy Agent) which returns allow or deny.
* **AlwaysAllow / AlwaysDeny** — every request is allowed or blocked; `AlwaysAllow` is the default when nothing is set.

Every resource lives in an API **group** (core group under `/api`, named groups like `apps` under `/apis`) and supports **verbs**: `get`, `list`, `create`, `update`, `delete`, `watch`.

## Solution

Enable modes as a comma-separated chain on `kube-apiserver`:

```
--authorization-mode=Node,RBAC,Webhook
```

Requests are evaluated mode by mode, left to right: if `Node` denies, try `RBAC`. The first mode that **allows** wins and remaining checks are skipped. ABAC stays viable as a single mode but becomes unwieldy as users and policies grow; RBAC is the scalable default.

**Verify it** — exercise the chain as the affected identity:

```
kubectl get nodes --as developer
```

With RBAC active and no role bound, the request returns `Forbidden`; bind a `ClusterRole` and the same call returns the node list, confirming the mode chain and binding work in order.

## When to use

* Choosing between RBAC (the recommended default) and ABAC for a small cluster.
* Delegating authorization decisions to an external policy engine with `Webhook`.
* Confirming request processing order when multiple modes are chained.