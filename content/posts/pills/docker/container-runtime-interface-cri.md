---
date: '2026-09-30T09:00:00Z'
title: 'Container Runtime Interface (CRI): How Kubernetes Talks to Runtimes'
category: ['docker']
---

## Problem

You look at a node and Docker is gone: Kubernetes 1.24 removed `dockershim`, so the Kubelet now talks straight to a CRI-compatible runtime. You need to know which runtime is actually behind the socket and how to inspect it, because `docker` commands no longer show the containers Kubernetes runs.

## Context

Docker was built before Kubernetes standardized runtimes. To decouple the Kubelet from any single product, Kubernetes defined the **Container Runtime Interface (CRI)**: a plugin API any runtime can implement as long as it conforms to the **Open Container Initiative (OCI)** image and runtime specifications.

* **containerd** is the mature CRI-compatible runtime. It began as Docker's internal runtime and is now a standalone CNCF project you can install without Docker.
* Docker itself was bridged to the Kubelet through the **dockershim**, which Kubernetes 1.24 removed.
* Docker images stay **OCI-compliant**, so they run on containerd without conversion.

The Kubelet reaches the runtime over a socket endpoint such as `unix:///run/containerd/containerd.sock`, `unix:///run/crio/crio.sock`, or `unix:///var/run/cri-dockerd.sock`.

## Solution

With the runtime behind the CRI, inspect it with **crictl**, the Kubernetes-community CLI that works against any CRI-compatible runtime. Point it at the same endpoint the Kubelet uses:

```
crictl --runtime-endpoint unix:///run/containerd/containerd.sock images
crictl ps -a
crictl logs <container-id>
```

`crictl` can also list **pods** (`crictl pods`), something `docker` cannot, because the pod abstraction exists only at the CRI level. Keep `ctr` — containerd's own debug CLI — for one-off pull/run checks:

```
ctr images pull docker.io/library/redis:alpine
```

Export the endpoint once so every `crictl` call works without the flag:

```
export CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock
```

**Verify it directly** — confirm which runtime the endpoint exposes:

```
crictl info | grep runtimeName
```

## When to use

* Auditing a node to learn which runtime the Kubelet is actually using.
* Debugging containers on a node where `docker ps` finds nothing.
* Verifying images, pods, and logs through the CRI rather than the Docker CLI.
* Understanding why `ctr` and `crictl` both exist and when each one applies.