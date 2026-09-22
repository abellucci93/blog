---
date: '2026-10-09T09:00:00Z'
title: 'Validating vs Mutating Admission Controllers'
category: ['cks']
---

## Problem

You submit a PersistentVolumeClaim with no `storageClassName`, an object is created in a namespace that does not exist, or a user names a resource after themselves. Whether the request succeeds is decided by the admission chain — but you cannot tell who modified the request, who merely allowed or denied it, and where your own policy is supposed to hook in.

## Context

Every API request crosses **authentication**, then **authorization**, then the **admission controllers** before the object is persisted. Admission controllers are plugins that either check a request against policy (**validating**) or change it before it is stored (**mutating**). Order is deliberate: mutating controllers run **before** validating ones so that what was modified is what gets validated; if any controller in the chain rejects the request, the whole operation fails. Built-in examples are the namespace-lifecycle validator and `DefaultStorageClass`, which mutes a PVC claim to add the cluster default class.

## Solution

The mutating side is easy to observe — submit a PVC without a storage class:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myclaim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

`DefaultStorageClass` injects `storageClassName` into the stored object; a validating controller would only have allowed or denied it. For custom policy, deploy your own webhook server and register it:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: pod-policy.example.com
webhooks:
  - name: pod-policy.example.com
    clientConfig:
      service:
        namespace: webhook-namespace
        name: webhook-service
      caBundle: CiOtLS0tQk...
    rules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE"]
        resources: ["pods"]
```

A `MutatingWebhookConfiguration` is the same shape; a mutating webhook returns a base64-encoded JSON patch, a validating one only returns `allowed`. If `allowed` is false, the API server rejects the request before anything is persisted.

**Verify it directly** — check what the mutator wrote:

```
kubectl describe pvc myclaim
```

`StorageClass: default` in the output is the mutation, persisted, while a validating webhook would have blocked the request entirely.

## When to use

* Explaining why a request came back modified or denied — trace the mutators and validators in play.
* Adding cluster policy: validating webhooks for deny rules, mutating webhooks for defaults, sidecars, and labels.
* Understanding order failures — a validating controller that runs first can reject requests a mutator would have fixed.