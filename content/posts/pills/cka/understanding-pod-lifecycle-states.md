---
date: '2026-09-20T09:00:00Z'
title: 'Understanding Pod Lifecycle States'
category: ['cka']
---

## Problem

You deploy a pod and `kubectl get pods` shows something other than `Running`:

```
kubectl run nginx --image nginx
kubectl get pods
# NAME    READY   STATUS              RESTARTS   AGE
# nginx   0/1     ContainerCreating   0          2s
```

Seconds later the status may stay stuck, flip to `Pending`, or show `1/1 Running` for the `STATUS` while `READY` is still `0/1`. Without knowing what each state means, you cannot tell whether the pod is healthy, still starting, or actually broken.

## Context

A pod is the smallest deployable unit, and it moves through **phases** and **container states** managed by the Kubelet:

* **Pending** — the pod is accepted by the API server but not yet running. This covers scheduling and image pulling. `ContainerCreating` is what you see during this phase.
* **Running** — the pod is bound to a node and at least one container is running or starting.
* **Succeeded** — all containers terminated with exit code `0`. Normal for Jobs.
* **Failed** — at least one container terminated with a non-zero exit code.
* **Unknown** — the node hosting the pod is unreachable.

Within a running pod, each container has its own state: **Waiting** (pulling image, restarting), **Running**, or **Terminated** (with a reason and exit code).

The `STATUS` column reflects the pod phase; the `READY` column reflects how many containers passed their readiness probe.

## Solution

Track the pod in order, from scheduling to readiness:

```
kubectl get pod nginx -w        # watch state transitions live
kubectl describe pod nginx      # phases, container states, and event history
```

In the `describe` output, read `Status`, `Conditions`, and the `Events` section:

```
Status:       Running
Containers:
  nginx:
    State:          Running
      Started:      Sat, 03 Mar 2018 14:26:21 +0800
    Ready:          True
    Restart Count:  0
Conditions:
  Type              Status
  Initialized       True
  Ready             True
  PodScheduled      True
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  27s   default-scheduler  Successfully assigned nginx to minikube
  Normal  Pulled     27s   minikube           Successfully pulled image "nginx"
  Normal  Started    27s   minikube           Started container
```

A healthy pod shows `PodScheduled: True`, `Ready: True`, and container `State: Running` with `Ready: True`.

**Verify it directly** — the pod reaching `Running` is not enough; confirm the container answers:

```
kubectl wait --for=condition=Ready pod/nginx --timeout=60s
kubectl get pod nginx -o jsonpath='{.status.phase}{"\n"}'   # -> Running
```

If the phase is stuck, the events tell you why: `ImagePullBackOff` (bad image), `0/1 nodes available` (unschedulable), or `CrashLoopBackOff` (container exits and Kubelet restarts it with backoff).

## When to use

* Debugging a pod that never reaches `Running` or `Ready`.
* Deciding whether a pod is still starting or genuinely broken.
* Reading `kubectl describe` events and container states without guessing.
* Building probes and restart policies: `Running` is the phase, readiness is the gate.
