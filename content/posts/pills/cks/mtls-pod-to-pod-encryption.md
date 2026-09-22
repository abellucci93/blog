---
date: '2026-10-05T09:00:00Z'
title: 'mTLS for Pod-to-Pod Encryption'
category: ['cks']
---

## Problem

Pods on the pod network exchange traffic in plaintext by default. An attacker positioned on the network — a compromised neighbor pod — can sniff sensitive payloads (customer PII, credentials) moving between a web pod and its MySQL pod. A pod also cannot prove it is talking to the real service rather than an imposter.

## Context

**One-way SSL** authenticates only the server: the client verifies the server's certificate, shares a symmetric key, and the user's identity comes from separate credentials. Fine for a human at a browser, useless between machines with no humans.

**Mutual TLS (mTLS)** authenticates both ends:

* Pod A requests Pod B's certificate.
* Pod B sends its certificate and requests A's in return.
* Each pod verifies the other's certificate against its CA trust store.
* Both then switch to a shared symmetric key for the session.

Per-app encryption is inconsistent: MySQL ships its own TLS, other services have none, algorithms differ. A **service mesh** fixes this at the network layer: every pod gets a **sidecar** that encrypts on send and decrypts on receive, so the application code never touches TLS.

## Solution

Istio applies mTLS through a `PeerAuthentication` policy with two modes:

* **Permissive** — use mTLS when the peer supports it, fall back to plaintext; safe during rollout.
* **Strict** — reject any traffic not protected by mTLS.

```
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT
```

The web pod's sidecar encrypts outbound calls; the MySQL pod's sidecar decrypts before the app handles the request. Between the two sidecars, traffic is encrypted and mutually authenticated while the apps stay unchanged.

**Verify it** — confirm the mesh is enforcing strict mode:

```
kubectl get peerauthentication default -n default -o jsonpath='{.spec.mtls.mode}{"\n"}'
# STRICT
```

## When to use

* Clusters carrying regulated or sensitive data where in-transit encryption is required.
* Zero-trust service identities: every caller must prove who it is.
* Enable permissively first, flip to strict only once every workload has a sidecar injected — strict before full rollout breaks connectivity.