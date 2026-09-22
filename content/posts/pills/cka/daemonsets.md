---
date: '2026-10-06T14:00:00Z'
title: 'DaemonSets: Running a Pod on Every Node'
category: ['cka']
---

## Problem

You want an agent on every node — kube-proxy most obviously. A Deployment with three replicas can schedule all of them onto one node and leave the rest uncovered, and nobody wants to hand-place pods on every node join and drain.

## Context

A **DaemonSet** is the controller that guarantees exactly one pod per node. It reacts to the cluster topology: a node is added, a pod appears on it; a node is removed, the pod goes with it. Since v1.12 it schedules with the default scheduler plus node affinity; before that it pinned `nodeName` directly. The spec is a ReplicaSet without `replicas` — the desired count is the node count.

## Solution

A DaemonSet is nearly a ReplicaSet manifest: pod template plus a selector, with `apps/v1` and kind `DaemonSet`:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: monitoring-daemon
spec:
  selector:
    matchLabels:
      app: monitoring-agent
  template:
    metadata:
      labels:
        app: monitoring-agent
    spec:
      containers:
      - name: monitoring-agent
        image: monitoring-agent
```

Selector labels must match the template labels or the controller cannot adopt the pods. Create it:

```
kubectl create -f daemon-set-definition.yaml
```

**Verify with one list command — `DESIRED` is the node count:**

```
kubectl get daemonsets
NAME               DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   AGE
monitoring-daemon  3         3         3       3            3           41
```

Add a fourth node and, with no action from you, `DESIRED` moves to 4 and a new pod gets scheduled; `kubectl describe daemonset monitoring-daemon` shows scheduling and event history.

## When to use

* Cluster-wide agents: log collectors and monitoring exporters.
* Core networking pods such as `kube-proxy` and weave-net.
* Exactly one pod per node is the requirement — favor a Deployment when different nodes should run different numbers of replicas.