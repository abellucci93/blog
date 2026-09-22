---
date: '2026-10-04T09:00:00Z'
title: 'Multiple Schedulers: Running Custom Scheduling Logic'
category: ['cka']
---

## Problem

A workload needs placement logic the default scheduler does not have, for example an extra verification before its pods land on specific nodes. Those pods stay `Pending` because nothing in the cluster is configured to run that logic.

## Context

Kubernetes places pods through the scheduler's phases: **filter**, **score**, then **bind**. The default scheduler filters on resources, taints, and node affinity, scores the remaining nodes, and binds to the winner. When that behavior is not enough, you run **additional schedulers** alongside it instead of modifying the built-in one.

Two constraints matter:

* Every scheduler has a **unique name**; the built-in one is conventionally `default-scheduler`.
* A pod chooses its scheduler via the `schedulerName` field in its spec. Leave it unset and the default scheduler handles the pod.

Since Kubernetes 1.18 a single scheduler binary can expose several schedulers by listing **multiple profiles** in one configuration file, which avoids running separate processes and the race conditions of two schedulers binding pods on the same node.

## Solution

Declare each scheduler in a `KubeSchedulerConfiguration`. Several profiles in one file behave like independent schedulers:

```
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
  - schedulerName: my-scheduler-2
  - schedulerName: my-scheduler-3
```

Each profile can enable or disable plugins per extension point (`score`, `preScore`, and so on), so `my-scheduler-2` may run a custom scoring plugin while the default profile stays untouched.

Point the workload at the scheduler by name:

```
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
    - name: nginx
      image: nginx
  schedulerName: my-scheduler-2
```

If the scheduler configuration is wrong, the pod stays `Pending`; when it works, it reaches `Running`.

**Verify which scheduler placed the pod** by checking the `SOURCE` column of the events:

```
kubectl get events -o wide
```

A `Normal Scheduled` event whose `SOURCE` is `my-custom-scheduler` with the message `Successfully assigned nginx to node01` confirms your scheduler, not the default one, did the binding.

## When to use

* A workload needs placement rules the default scheduler cannot express.
* You want a custom algorithm for one class of pods without affecting everything else.
* You need several scheduling behaviors from one binary through profiles rather than separate processes.