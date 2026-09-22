---
date: '2026-10-15T14:00:00Z'
title: 'Node Affinity vs Taints and Tolerations: Decision Guide'
category: ['cka']
---

## Problem

You must keep specific pods on specific nodes, and every other pod off them. On their own, **taints and tolerations** repel and **node affinity** attracts: each mechanism covers only half the goal.

## Context

Taints and tolerations keep pods off a node unless the pod tolerates the taint; node affinity runs a pod only on nodes whose labels match its `matchExpressions`. The gaps:

* Taints do not stop a pod from landing on an **untainted** node, so a pod that ignores taints can still reach a node you wanted only for another workload.
* Affinity does not stop other pods from reaching a node you dedicated, because affinity constrains only the pod that declares it.

Neither is a security boundary; both only steer scheduling. `NoSchedule` repels new pods at scheduling time, while `NoExecute` also evicts pods already running on the node.

## Solution

For exclusive node usage, combine both. Taint the node, tolerate that taint in the intended pod, and add a required affinity rule so that pod can only be scheduled on a node with the matching label:

```
apiVersion: v1
kind: Pod
metadata:
  name: blue-app
spec:
  containers:
    - name: nginx
      image: nginx
  tolerations:
    - key: app
      operator: Equal
      value: blue
      effect: NoSchedule
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: color
                operator: In
                values:
                  - blue
```

Create the taint first, remembering it must match the label the affinity expects:

```
kubectl taint nodes node1 app=blue:NoSchedule
```

The taint keeps everyone else off, the toleration admits this pod, and the affinity forces this pod onto a node labeled `color=blue`.

**Verify the split** by inspecting labels and taints side by side:

```
kubectl get nodes -L color && kubectl describe node node1 | grep Taint
```

Only the pod with the toleration should be `Running` on the tainted node; any other pod stays `Pending` or is placed on an untainted node.

## When to use

* Taints alone when you only need to repel general workloads, like the master-node taint.
* Affinity alone when you only need to pull pods toward labeled nodes.
* Both together whenever a node must host one workload and nothing else.