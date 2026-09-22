---
date: '2026-09-22T14:00:00Z'
title: 'Authentication Methods in Kubernetes: Certs, Tokens, OIDC'
category: ['cks']
---

## Problem

A new developer runs `kubectl get pods` and gets a certificate or token error. Who is allowed to talk to the API server, and how does it verify identity? Kubernetes does not manage local user accounts — you cannot create or list users with `kubectl`.

## Context

Every request, whether from `kubectl` or a direct API call, is processed by the `kube-apiserver`, which **authenticates** the caller before anything else happens. Kubernetes recognizes two kinds of principal:

* **Users** — humans and external services; managed outside the cluster.
* **Service Accounts** — bots and in-cluster processes; managed natively via the Kubernetes API.

Authentication methods include static password files, static token files, **X.509 certificates**, and third-party identity providers (LDAP, Kerberos, OIDC). Static files are the simplest to understand — and the least secure, so they suit testing rather than production.

## Solution

A static token file is a CSV of token, username, user ID, and groups:

```
KpjCVbI7cFAHYPkByTIzRb7gulcUc4B,user10,u0010,group1
rJjncHmvtXHc6MlWQddhtvNyvhgTdXSC,user11,u0011,group1
```

Pass it to `kube-apiserver` with:

```
kube-apiserver --token-auth-file=user-token-details.csv
```

The caller presents the token in the `Authorization` header on every request. Password files work identically via `--basic-auth-file`; certificates derive identity from the client certificate's subject presented through the kubeconfig, and OIDC delegates verification to an external identity provider.

**Verify it** — authenticate as that user against the API:

```
curl -k https://master-node-ip:6443/api/v1/pods --header "Authorization: Bearer KpjCVbI7cFAHYPkByTIzRb7gulcUc4B"
```

A valid token proceeds to authorization; a bad token is rejected before any permission check. For production, prefer certificates or an identity provider — token files store secrets in plain text and must be mounted and referenced with a flag on the API server.

## When to use

* Standing up a test cluster when you need quick, ad-hoc credentials.
* Understanding how the API server establishes identity before RBAC applies.
* Choosing between static files, certificates, and OIDC for a new user population.