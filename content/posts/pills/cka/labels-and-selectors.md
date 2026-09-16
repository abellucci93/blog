---
date: '2026-09-20T19:00:00Z'
title: 'Labels and Selectors: The Glue of Kubernetes'
category: ['cka']
---

## Problem

You have a cluster with dozens of pods and need to find the exact group you care about — say, all front-ends of one app. `kubectl get pods` returns everything, and grepping output by name breaks the moment names turn into hashes. You also need other objects (Services, ReplicaSets) to *attach* to the right pods automatically, without hardcoding names.

## Context

**Labels** are key-value pairs attached under `metadata` that identify a resource — e.g. `app: App1`, `function: Front-end`. They are tags, nothing more; the object does not behave differently because of them.

**Selectors** filter objects by their labels. Two families exist:

* **Equality** — `--selector app=App1` (or `app!=App2`).
* **Set-based** — `--selector 'app in (App1, App2)'`, `'env notin (test)'`.

Labels are the glue: a ReplicaSet's `spec.selector.matchLabels` must match the labels it puts on the pods in its `template`, and a Service's `selector` must match pod labels. If the selector and the labels disagree, the controller ignores the pods.

Tags like build version or owner are **annotations** — arbitrary metadata *not* usable for selection.

## Solution

Tag the pod in the manifest:

```
apiVersion: v1
kind: Pod
metadata:
  name: simple-webapp
  labels:
    app: App1
    function: Front-end
spec:
  containers:
  - name: simple-webapp
    image: simple-webapp
```

Filter with a selector:

```
kubectl get pods --selector app=App1
# NAME            READY   STATUS     RESTARTS   AGE
# simple-webapp   0/1     Completed  0          1d

kubectl get pods -l 'app in (App1, App2)'
```

Wire a ReplicaSet to its pods by matching template labels in the selector:

```
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: simple-webapp
  labels:
    app: App1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: App1
  template:
    metadata:
      labels:
        app: App1
        function: Front-end
    spec:
      containers:
      - name: simple-webapp
        image: simple-webapp
```

The ReplicaSet scans for pods carrying `app=App1` and owns exactly those — no name-based coupling. Services use the same mechanism: the Service `selector` picks the pod labels to route traffic to.

**Verify it** — confirm the selection and that the controller claims the pod:

```
kubectl get pods -l app=App1 --show-labels
kubectl get replicasets -l app=App1
kubectl describe replicaset simple-webapp   # owner references on the pods
```

A pod whose labels don't match the ReplicaSet selector stays unmanaged and unowned.

## When to use

* Filtering and grouping pods (or any object) in large clusters.
* Connecting controllers (ReplicaSet, Deployment, Service) to their pods.
* Rolling out multiple releases or tiers of the same app in parallel.
* Storing non-selective metadata via annotations (build info, contact, tool versions).
