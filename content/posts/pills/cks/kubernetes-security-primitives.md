---
date: '2026-10-09T19:00:00Z'
title: 'Kubernetes Security Primitives: An Overview'
category: ['cks']
---

## Problem

`kubectl get pods` succeeds, and so does every other call against the API server that ships any valid token: nothing verifies who the caller is, what they may do, how the control plane talks, or which pods may talk to which. You harden individual workloads all day, and the cluster still falls because the primitives at the entry points were never locked down.

## Context

Kubernetes security is layered, and each layer guards a different surface:

* **Hosts** — nodes run the control plane and workloads; a compromised OS means a compromised cluster.
* **API server** — every cluster operation flows through it, raising two questions: *who* can access it (**authentication**) and *what* they may do (**authorization**).
* **Component traffic** — etcd, kubelet, kube-proxy, scheduler, and controller manager exchange data; those channels are TLS-encrypted.
* **Pod network** — pods reach each other freely by default; restricting that takes an explicit policy.

## Solution

Work the layers from the infrastructure outward.

**Secure the hosts** — disable root login and password-based SSH, force key-based authentication. If the host is compromised, every other control is moot.

**Authentication** decides who can reach the API server. Supported methods: static password files and bearer tokens, X.509 client certificates, external providers such as LDAP, and service accounts for machine-to-machine calls.

**Authorization** decides what an authenticated caller may do. **RBAC** is the primary model; modules such as **ABAC**, **Node authorization**, and **webhook** cover the remaining cases.

**TLS** encrypts component-to-component traffic: kubelet, kube-proxy, scheduler, controller manager, and etcd all connect to the API server over TLS.

**Network policies** close the default allow-all between pods. Restrict a database pod to accept traffic only from the API pod:

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-policy
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          name: api-pod
    ports:
    - protocol: TCP
      port: 3306
```

**Verify it** — confirm the API server's authorization mode and the running policy:

```
kubectl get pod -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}{"\n"}' | tr ' ' '\n' | grep -- --authorization-mode
kubectl get networkpolicy db-policy
```

## When to use

* Securing a cluster from the ground up before workloads are admitted.
* Auditing an inherited cluster you do not trust yet.
* Prioritizing hardening investments: primitives first, admission and policy on top.