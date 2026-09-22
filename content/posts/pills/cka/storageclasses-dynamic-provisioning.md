---
date: '2026-10-14T19:00:00Z'
title: 'StorageClasses: Dynamic Provisioning Explained'
category: ['cka']
---

## Problem

Static provisioning means a human creates cloud storage, writes a PersistentVolume pointing at that disk, then a PVC requests it. Every new app repeats the manual steps, and a misnamed disk or wrong size leaves the claim waiting on a PV that never comes.

## Context

Kubernetes can **dynamically provision** storage: a **StorageClass** names a `provisioner` that understands a cloud provider, and when a PVC with that `storageClassName` is created, the provisioner creates the underlying disk and a matching PV automatically. The PVC binds immediately instead of waiting for a human.

The class is a cluster-scoped object whose optional `parameters` block tunes the storage:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: google-storage
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-standard
  replication-type: none
```

## Solution

Reference the class from the PVC:

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myclaim
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: google-storage
  resources:
    requests:
      storage: 500Mi
```

When `myclaim` is created, the provisioner makes a 500Mi disk and binds a PV to the claim; the pod mounts it with a claim reference as usual:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: random-number-generator
spec:
  containers:
    - name: alpine
      image: alpine
  volumes:
    - name: data-volume
      persistentVolumeClaim:
        claimName: myclaim
```

Verify the claim is bound and which provisioner produced the PV:

```
kubectl get pvc
# myclaim  Bound  pvc-abc123  500Mi  RWO  google-storage
kubectl get storageclass
```

Tune classes by tier: a `silver` class on standard disks, a `gold` class on SSDs, a `platinum` class with regional replication — a PVC then picks the tier by name, not by admin effort.

## When to use

* Any cluster backed by a cloud provider with a provisioner (GCP, AWS, Azure).
* When PVCs should not block on a manual PV step.
* Multi-tier storage: choose class by name in the PVC for performance or availability needs.