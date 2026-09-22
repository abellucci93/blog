---
date: '2026-10-05T19:00:00Z'
title: 'Kubelet Authorization: Certificate-Based vs Webhook'
category: ['cks']
---

## Problem

By default the kubelet authorizes every request with **`AlwaysAllow`**: once a request reaches it, no check decides what it may do. Combined with settings that accept unauthenticated callers, anyone who can reach the kubelet ports can list `pods` or execute commands inside containers. Authentication alone is useless if authorization always says yes.

## Context

The kubelet registers the node, loads containers requested by the scheduler, and reports status back to the **kube-apiserver**. From the kubelet's point of view, the API server is just another client. Two separate controls apply:

* **Authentication** — proving who the caller is, via a CA-issued certificate (`--client-ca-file` / `x509.clientCAFile`). If no mechanism vouches for a request, it falls back to `system:anonymous`.
* **Authorization** — deciding what an authenticated caller may do. The default is `AlwaysAllow`.

Secure the kubelet by turning the permissive default off at both layers.

## Solution

Configure certificate-based authentication and webhook authorization together in the kubelet config:

```
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: false
  x509:
    clientCAFile: /path/to/ca.crt
authorization:
  mode: Webhook
```

* **`x509.clientCAFile`** — requests must present a certificate signed by the cluster CA. Patch kube-apiserver to send one: `--kubelet-client-certificate` and `--kubelet-client-key`.
* **`authorization.mode: Webhook`** — the kubelet forwards each request's identity and action to the API server's `SubjectAccessReview` endpoint and honors its allow/deny decision instead of allowing everything.
* Keep `anonymous.enabled: false` so unauthenticated requests are rejected rather than downgraded.

The result: the kubelet accepts only CA-verified clients and only the actions the API server approves — node-scoped pod reads for the scheduler, no anonymous command execution.

**Verify it here** — inspect the running kubelet:

```
ps -aux | grep kubelet
```

Confirm the process references the config file with `--config` and that inside it `authorization.mode` is `Webhook` and `anonymous.enabled` is `false`.

## When to use

* Enforcing least privilege on node-level API access beyond just authentication.
* Locking down the kubelet so the scheduler and API server remain the only callers that matter.
* CIS-style node hardening, where `AlwaysAllow` is counted as a failure.