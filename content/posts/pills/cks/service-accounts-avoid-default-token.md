---
date: '2026-09-26T19:00:00Z'
title: 'Service Accounts: Avoiding the Default Token'
category: ['cks']
---

## Problem

You deploy a pod and it silently mounts the **default service account token** at `/var/run/secrets/kubernetes.io/serviceaccount/token`. The container never calls the Kubernetes API, yet any process inside it can read a valid credential and use it against the API server. Every pod in the namespace carries this token unless you explicitly switch it off.

## Context

Kubernetes has **user accounts** for humans and **service accounts** for machines and apps. Each namespace contains a `default` service account, and a pod created without a `serviceAccountName` gets that account's token mounted automatically. Before v1.22 the token was a non-expiring secret; since then it is an audience- and time-bound projected token issued by the token request API, and since v1.24 no secret is auto-created at all. In every version, an unused credential mounted inside a container is needless attack surface against the API server.

## Solution

Disable automatic mounting on pods that need no API access:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-kubernetes-dashboard
spec:
  automountServiceAccountToken: false
  containers:
    - name: my-kubernetes-dashboard
      image: my-kubernetes-dashboard
```

For pods that do authenticate, create a dedicated service account, bind only the RBAC permissions it needs, and reference it with `serviceAccountName: dashboard-sa`:

```
kubectl create serviceaccount dashboard-sa
```

Request a short-lived token explicitly instead of depending on an auto-created secret:

```
kubectl create token dashboard-sa
```

Changing the service account of a running pod requires deleting and recreating it; a Deployment rolls out automatically when its spec changes.

**Verify it directly** — the token volume is gone:

```
kubectl get pod my-kubernetes-dashboard -o jsonpath='{range .spec.volumes[*]}{.name}{"\n"}{end}'
```

Empty output means no `default-token-*` volume, so the pod carries no API credential.

## When to use

* Pods that never talk to the Kubernetes API — keep `automountServiceAccountToken: false` set.
* Workloads that do authenticate — assign a least-privilege service account, never the `default`.
* Auditing which pods hold API credentials at rest.
* v1.24+ clusters where long-lived token secrets no longer exist — verify nothing assumes them.