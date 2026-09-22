---
date: '2026-10-02T09:00:00Z'
title: 'Network Policies: Default Deny and Selective Allow'
category: ['cks']
---

## Problem

Inside the cluster, every pod can reach every pod — the **default allow-all** rule. A frontend pod can dial the database directly on port 3306, skipping the API tier entirely. One compromised pod becomes a bridge to every other workload.

## Context

Traffic is described by direction: **ingress** is traffic arriving at a pod, **egress** is traffic leaving it; the response traffic does not count. A **NetworkPolicy** is a namespaced object that selects pods by labels and declares what they may send or receive.

Two facts shape how you write them:

* A direction is isolated **only if it is named in `policyTypes`** — list `Ingress`, and only ingress is restricted; egress stays open.
* Enforcement is the CNI's job: **Calico, Weave Net, Romana**, and **Kube-router** support policies; **Flannel does not**, and a policy on Flannel is silently ignored.

## Solution

Label the database pod and allow only the API pod to reach it on 3306:

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

Apply it with:

```
kubectl create -f db-policy.yaml
```

From now on the database accepts traffic **only** from pods labeled `name: api-pod` on TCP 3306; every other ingress is dropped.

**Verify it** — the policy is live and selecting the db pods:

```
kubectl get networkpolicy db-policy -o wide
# NAME       POD-SELECTOR   AGE
# db-policy  role=db        12s
```

## When to use

* Zero-trust pod segmentation: a service speaks only to the services it actually needs.
* Enclosing stateful services like databases behind the API tier.
* Reducing blast radius so a compromised pod cannot reach the whole cluster.