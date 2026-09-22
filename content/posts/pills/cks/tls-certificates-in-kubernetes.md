---
date: '2026-10-11T14:00:00Z'
title: 'TLS Certificates in Kubernetes: Who Talks to Whom'
category: ['cks']
---

## Problem

A scheduler, controller-manager, kube-proxy, or `kubectl` cannot tell whom it is talking to, and the API server cannot tell who is asking. Every control-plane exchange needs the caller to present a signed client certificate and the server to present one. One missing Subject Alternative Name (SAN) or wrong common name and the handshake fails — or a client lands in the wrong group.

## Context

TLS builds on asymmetric encryption: a **private key** stays secret, the matching **public key** travels inside a signed certificate, and a **Certificate Authority (CA)** signs every certificate so all components share one root of trust. Cluster certificates split into two groups:

* **Server certificates** — `api-server.crt`, `etcd-server.crt`, and a per-node `kubelet.crt`.
* **Client certificates** — `admin.crt`, plus scheduler, controller-manager, and kube-proxy.

A component can play both roles — the API server authenticates to etcd as a client. Public certs use `.crt`/`.pem`; private keys use `.key`.

## Solution

Create the CA, then sign everything with it. The `CN` is the client, the `/O=` its group, so `system:masters` in the OU grants admin privileges:

```
openssl genrsa -out ca.key 2048
openssl req -new -key ca.key -subj "/CN=KUBERNETES-CA" -out ca.csr
openssl x509 -req -in ca.csr -signkey ca.key -out ca.crt
```

```
openssl req -new -key admin.key -subj "/CN=kube-admin/O=system:masters" -out admin.csr
openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -out admin.crt
```

Server certificates must list every hostname the API server is reached by — cluster DNS names and the cluster IP — which requires an `alt_names` block in an openssl config:

```
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc.cluster.local
IP.1 = 10.96.0.1
```

**Verify it directly** — call the API as admin with the three files:

```
curl https://kube-apiserver:6443/api/v1/pods --key admin.key --cert admin.crt --cacert ca.crt
```

A JSON `PodList` (even with an empty `items`) means the client cert, key, and CA trust chain all match. The same pattern signs the scheduler and kubelet; the API server keeps its own signed pair plus a `client-ca-file` to judge everyone else.

## When to use

* Auditing or rebuilding cluster PKI after a certificate expiry or a TLS handshake failure.
* Mapping the identity behind RBAC: `CN=kube-admin` names the user, `O=system:masters` the group.
* Debugging mutual-auth breakage between etcd, the API server, and kubelets — check which signed pair each side holds.