---
date: '2026-09-24T09:00:00Z'
title: 'Why Your PVC Stays Pending: Understanding PVC Binding'
category: ['cka']
---

## Problem

You create a PVC and it sits in `Pending` forever:

```
kubectl get pvc
# NAME      STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS
# myclaim   Pending   <none>   <none>     <none>         <none>
```

The pod mounting it stays `ContainerCreating`. Nothing got created, nothing errored loudly — the claim is waiting on a binding that will not happen.

## Context

Admins create PVs; users create PVCs. When a PVC is created, the controller looks for a PV that satisfies every criterion at once:

* **capacity** — the PV must be at least as large as the request (a 500Mi claim can bind a 1Gi PV; the surplus stays unusable by other claims).
* **accessModes** — a `ReadWriteOnce` claim binds only PVs that allow `RWO`.
* **storageClassName** — must match; a claim naming a class binds only PVs in that class, a claim with no class binds only unclassed PVs.

If no PV matches, the PVC stays **Pending** until a suitable PV appears. One mismatch is enough to block the bind.

## Solution

Read why the claim has no volume:

```
kubectl describe pvc myclaim
# Events:
#   no persistent volumes available for this claim
```

Then inspect what exists to bind to:

```
kubectl get pv
kubectl get storageclass
```

See which criterion each candidate fails — dump the label, capacity, modes, and class of a candidate PV:

```
kubectl get pv pv-voll -o yaml | grep -E 'storage:|accessModes:|storageClassName:|persistentVolumeReclaimPolicy:'
```

Common fixes:

* no PV at all — create one, or point the PVC at a StorageClass for dynamic provisioning.
* `storageClassName` mismatch — align the names, or use `storageClassName: ""` to bind to an unclassed static PV.
* wrong access modes — match the PVC's `accessModes` to a PV that exists.

Verify the bind resolved:

```
kubectl get pvc
# myclaim   Bound   pv-voll   1Gi   RWO
```

## When to use

* Any PVC that never leaves `Pending`.
* Before creating PVs: inspect what a claim is waiting on first.
* When distinguishing "no storage exists" from "wrong storage exists" — both leave the same `Pending` status.