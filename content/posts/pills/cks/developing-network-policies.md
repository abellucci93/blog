---
date: '2026-09-29T14:00:00Z'
title: 'Developing Network Policies: A Practical Walkthrough'
category: ['cks']
---

## Problem

By default Kubernetes lets every pod talk to every pod. Your database pod on port 3306 is reachable from any workload on any node, including untrusted ones. You must admit only the API pod to the DB — leaving web-pod traffic untouched — and prove the rule works.

## Context

A **NetworkPolicy** is a namespace-scoped, selector-driven firewall enforced by the CNI plugin. Applying a policy to selected pods flips them to **default-deny** for the declared directions:

* `podSelector` names the affected pods.
* `policyTypes` declares which directions are governed (`Ingress`, `Egress`, or both).
* `from`/`to` entries match on `podSelector`, `namespaceSelector`, or `ipBlock`.
* Allowed ingress traffic automatically permits its responses, so no egress rule is needed unless the pod itself initiates connections.

Selector placement matters: selectors in the **same `from` item are ANDed**; separate items are ORed.

## Solution

Target the db pod (label `role: db`) and admit only the api pod on TCP 3306:

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

Apply it, then extend the `from` item as the scenario grows:

* Cross-namespace: add a `namespaceSelector` so only the pod labeled `api-pod` in the `prod` namespace passes (AND).
* External backup server: use `ipBlock: cidr: 192.168.5.10/32`, since pod selectors cannot match what is outside the cluster.
* Outbound backups: add `Egress` to `policyTypes` and a `to:` block so the DB can reach the backup server on port 80.

**Verify it directly** — confirm the policy selects the right pods:

```
kubectl get networkpolicy db-policy
```

A policy `db-policy` present and selecting `role: db` means ingress is now limited to the api pod on 3306; the CNI drops everything else.

## When to use

* Isolating data-tier pods to specific frontends and ports.
* Combining pod, namespace, and IP selectors precisely (AND vs OR).
* Adding egress rules when pods must initiate outbound connections.