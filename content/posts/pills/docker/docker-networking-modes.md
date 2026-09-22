---
date: '2026-10-16T14:00:00Z'
title: 'Docker Networking Modes: Bridge, Host, None'
category: ['docker']
---

## Problem

You start `nginx` with `docker run` and the process runs, but nothing outside the host can reach it. The container's IP is on a private subnet and its port is not published. To expose it — or to lock it down completely — you must choose one of Docker's **networking modes**.

## Context

Installing Docker creates a default **bridge** network, visible as the `docker0` interface on the host, with the IP `172.17.0.1` on a private subnet (usually `172.17.0.0/16`). Each container gets its own network namespace with a unique IP from this subnet. The three modes attach the container to different namespaces:

* **bridge (default)** — a pair of virtual interfaces wires the container to `docker0`, one end held by the bridge, one end placed inside the container's namespace. Containers reach each other and the host; the outside world needs a published port to get in.
* **host** — the container shares the host's network stack, so it binds directly on host ports with no per-container IP and no isolation.
* **none** — no network at all; the container stays in a completely isolated namespace.

## Solution

Pick the mode with the `--network` flag:

```
docker run --network none nginx
docker run --network host nginx
docker run -p 8080:80 nginx
```

The third command runs the default bridge plus **port mapping**: Docker adds an iptables **NAT** rule that forwards traffic arriving on host port `8080` to container port `80`. Directly curling the container's private IP fails, but the published host port succeeds.

Two containers on `--network host` cannot both bind the same host port; two bridge containers can, because each has its own IP and namespace. Inspect the networks and the bridge yourself:

```
docker network ls        # shows bridge, host, and none networks
ip link show docker0     # the bridge interface behind the "bridge" network
```

**Verify it directly** — publish a container and confirm the mapping works end to end:

```
docker run -d -p 8080:80 nginx && curl -s http://localhost:8080
```

## When to use

* Default **bridge** for most services; add `-p` when external clients need access.
* **host** when a container must bind directly on host ports or needs the host's full interface list.
* **none** for batch or sensitive workloads that must stay off the network.