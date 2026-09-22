---
date: '2026-10-02T19:00:00Z'
title: 'Persistent Volumes: Retain vs Delete Reclaim Policies'
category: ['cka']
---

## Problem

A persistent volume keeps data beyond a pod's life, but you must also decide what happens to that storage when the workload no longer needs it. Reclaim it wrongly and you delete data you still wanted; skip it and the volume stays `Released` and unusable without manual cleanup.

## Context

An administrator creates a **persistent volume (PV)** as a cluster-wide storage resource, and users take a slice of it through a **persistent volume claim (PVC)**. When the claim is deleted, the PV is freed, and its `persistentVolumeReclaimPolicy` decides the fate of the underlying storage:

* **Retain** — the default. The data stays, the PV moves to `Released`, and an admin must manually reclaim the volume before it can be reused.
* **Delete** — the PV and the backing storage are removed automatically.

Because the default is **Retain**, no storage disappears on its own unless you opt into `Delete`. Note that `hostPath` in the example below is for testing and single-node setups only; production uses providers such as AWS EBS.

## Solution

Declare the policy in the PV manifest. `Retain` keeps both the volume and the data:

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-vol1
spec:
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 1Gi
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /tmp/data
```

For storage that should vanish with the claim, set `persistentVolumeReclaimPolicy: Delete` instead, which is the usual choice for dynamically provisioned volumes.

**Verify the behavior end to end** — delete the claim, then read the volume's policy and phase:

```
kubectl delete pvc my-claim
kubectl get pv pv-vol1 -o jsonpath='{.spec.persistentVolumeReclaimPolicy} {.status.phase}{"\n"}'
```

Under `Retain` you get `Retain Released` and the data survives for manual reclamation; under `Delete` the PV no longer exists.

## When to use

* **Retain** for anything you may need to inspect or reattach after its claim is gone.
* **Delete** for disposable, easily recreated data that should not keep costing storage once released.
* Check the few values that matter per volume: `accessModes` over `ReadWriteOnce`/`ReadWriteMany`, `capacity`, and the reclaim policy.