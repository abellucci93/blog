---
date: '2026-09-24T14:00:00Z'
title: 'Kata Containers: VM-Level Isolation for Pods'
category: ['cks']
---

## Problem

Standard container isolation shares a single **host kernel** between all pods on a node. A pod that exploits a kernel vulnerability can compromise that shared kernel and, through it, every other workload on the same machine. Namespaces and cgroups confine processes, but they are not a security boundary — the kernel is still common.

## Context

**Kata Containers** is a container runtime that places each container inside a **lightweight virtual machine** with its own dedicated kernel, unlike gVisor, which intercepts syscalls in user space. A fault or attack inside one container stays inside its own VM and cannot destabilize the host or sibling pods.

The isolation has a cost: each VM consumes extra memory and compute. More importantly, Kata requires **hardware virtualization** support. On cloud instances that are already VMs, that means nested virtualization, which many providers do not support or only enable with manual configuration and degraded performance. Bare-metal nodes avoid that constraint.

## Solution

Kata installs its own runtime (`kata`) and is wired into Kubernetes through a **RuntimeClass** so pods opt into the VM-based runtime:

```
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata
handler: kata
```

A pod selects it with `runtimeClassName`; pods without the field keep the default runc runtime:

```
apiVersion: v1
kind: Pod
metadata:
  name: nginx-kata
spec:
  runtimeClassName: kata
  containers:
  - name: nginx
    image: nginx
```

This lets you adopt Kata selectively — workload by workload — rather than cluster-wide, so only untrusted or isolation-critical pods pay the overhead.

**Verify it here** — check the pod actually picked up the Kata runtime:

```
kubectl get pod nginx-kata -o jsonpath='{.spec.runtimeClassName}{"\n"}'
```

A `kata` result means the pod was handed to the kata runtime and runs inside its own VM with a dedicated kernel.

## When to use

* Workloads that must be isolated from the host kernel, such as untrusted or third-party containers.
* Multi-tenant nodes where a single compromised container must not reach the host or neighbours.
* Bare metal or providers that explicitly support nested virtualization.
* Security matters more than performance — expect a slight memory and compute overhead per pod.