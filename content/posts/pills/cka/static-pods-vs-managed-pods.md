---
date: '2026-10-01T14:00:00Z'
title: 'Static Pods vs Managed Pods: Where Kubelet Bypasses the API Server'
category: ['cka']
---

## Problem

A fresh node has containerd and kubelet installed but no API server, scheduler, or etcd. There is nobody to ask for pod specs — yet the node still needs to run pods, and the control plane itself must boot before the cluster exists.

## Context

A normal pod is a **managed pod**: the scheduler picks a node, records it in etcd, and the kube-apiserver hands the spec to the kubelet over its HTTP endpoint. A **static pod** bypasses all of that — the kubelet alone watches a directory on the host and creates a pod for every manifest file it finds there.

The kubelet restarts crashed containers, recreates the pod when the manifest changes, and deletes it when the file is removed. Only pod-level manifests work: Deployments, ReplicaSets, and Services need controllers that do not exist on a standalone node.

Point kubelet at the directory at startup:

```
ExecStart=/usr/local/bin/kubelet \
  --pod-manifest-path=/etc/kubernetes/manifests \
  --register-node=true
```

Or set `staticPodPath` in the kubelet's `--config` file. kubeadm clusters use `/etc/kubernetes/manifests` for control plane components.

## Solution

Place a pod manifest in that directory:

```
apiVersion: v1
kind: Pod
metadata:
  name: static-web
spec:
  containers:
  - name: web
    image: nginx
```

Save it as `/etc/kubernetes/manifests/static-web.yaml` and the kubelet picks it up on its next scan. On a standalone node, verify with the container runtime — there is no API server to ask:

```
docker ps
# k8s_web_static-web-node01_default_..._0
```

Inside a cluster the kubelet also posts a read-only **mirror pod** to the API server, so the static pod shows up in `kubectl get pods`, named with its node (`static-web-node01`). You cannot delete or modify that object through the API; editing the manifest file on the node is the only update path.

## When to use

* Bootstrapping control plane components (API server, controller-manager) before a cluster exists.
* Kubeadm-configured clusters, where the control plane runs as static pods.
* Standalone nodes or embedded platforms with no cluster.
* DaemonSet replacement when there is no API server — but in a cluster prefer DaemonSets, which a controller keeps reconciled.