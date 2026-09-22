---
date: '2026-10-12T14:00:00Z'
title: 'Admission Controllers: The Request Lifecycle Gatekeeper'
category: ['cks']
---

## Problem

You want to block any pod that runs as root or carries risky capabilities, but RBAC lets it through:

```
apiVersion: v1
kind: Pod
metadata:
  name: web-pod
spec:
  containers:
    - name: ubuntu
      image: ubuntu:latest
      command: ["sleep", "3600"]
      securityContext:
        runAsUser: 0
        capabilities:
          add: ["MAC_ADMIN"]
```

RBAC only checks *who* may `create` pods. It cannot reject this manifest for using the `latest` tag or running as root.

## Context

Every request to the API server passes a pipeline before anything is persisted in `etcd`:

* **Authentication** — kubectl supplies certificates from the kubeconfig file.
* **Authorization** — RBAC decides if the user may perform the operation.
* **Admission controllers** — the final gate before the request is persisted.

Admission controllers are plugin components that **validate, mutate, or reject** requests. Built-ins include **AlwaysPullImages** (pull on every pod creation), **DefaultStorageClass**, and **NamespaceExists** (reject requests for non-existent namespaces). List the active defaults with `kube-apiserver -h | grep enable-admission-plugins`.

## Solution

Enable plugins on `kube-apiserver` with `--enable-admission-plugins`. In a kubeadm cluster, edit the static pod manifest in `kube-system`:

```
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
    - command:
        - kube-apiserver
        - --enable-admission-plugins=NodeRestriction,NamespaceAutoProvision
```

Disable plugins with `--disable-admission-plugins` in the same way.

The old namespace-exists and auto-provision controllers are deprecated; the **NamespaceLifecycle** controller replaced them, rejecting requests for non-existent namespaces and guarding `default`, `kube-system`, and `kube-public` from deletion.

**Verify it** — with auto-provision enabled, create a pod in a missing namespace and check that it now exists:

```
kubectl run nginx --image nginx --namespace blue
kubectl get namespaces
```

The output shows a new `blue` namespace in `Active` state alongside the defaults.

## When to use

* Enforcing registry, image-tag, or security-context policies RBAC cannot express.
* Understanding why a `kubectl create` is rejected before the object reaches `etcd`.
* Auditing which admission plugins your control plane runs.