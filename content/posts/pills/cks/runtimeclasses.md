---
date: '2026-10-14T09:00:00Z'
title: 'RuntimeClasses: Switching Container Runtimes per Pod'
category: ['cks']
---

## Problem

A running workload calls the kernel of the node it landed on. The default runtime **runc** isolates each container with namespaces and cgroups, but every container on the node still shares that single host kernel — so a kernel bug or a container-escape is the difference between one container and the whole machine. Sandboxing every workload costs performance, so you need to pick the runtime per pod.

## Context

A container goes from image to process like this: the runtime unwraps the image into an **OCI bundle**, a **containerd shim** launches the actual **container runtime**, and by default that runtime is **runc**, which builds the namespace/cgroup isolation on the host kernel. Alternative OCI runtimes replace runc with something stricter:

* **gVisor** — a user-space kernel; runtime handler `runsc`.
* **Kata Containers** — a lightweight VM; runtime handler `kata`.

Standalone Docker lets you pick at launch with `docker run --runtime runsc -d nginx`. Kubernetes exposes no such flag on the pod spec — instead a pod references a **RuntimeClass**, a cluster object that binds a runtime *handler* to a name. The **handler** must match a runtime installed on every node where the pod can land, so `runsc` or `kata` must actually be deployed on the nodes first.

## Solution

Create the RuntimeClass, naming the handler for the installed runtime:

```
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
```

```
kubectl apply -f gvisor.yaml
```

Opt a pod into it with a single `runtimeClassName` field:

```
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  runtimeClassName: gvisor
  containers:
  - image: nginx
    name: nginx
```

`kubectl apply -f nginx.yaml` runs this pod through gVisor's `runsc` instead of runc. Scheduling works as usual; the name is arbitrary, but the handler must match the runtime on the node.

**Verify it directly** — a gVisor container runs on its own kernel, so its processes are invisible on the host. From the node, confirm nothing named nginx appears:

```
pgrep -a nginx
```

No output means the processes are inside the sandbox rather than the host kernel — instead you will see a `runsc` process on the node.

## When to use

* Running untrusted or multi-tenant workloads alongside trusted ones.
* Keeping a baseline runtime for most apps and sandboxing only the risky few.
* Adopting a new runtime in one namespace without touching global configuration.