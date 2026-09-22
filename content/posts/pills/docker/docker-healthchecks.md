---
date: '2026-10-07T19:00:00Z'
title: 'Docker Healthchecks: Keeping Containers Honest'
category: ['docker']
---

## Problem

A container's main process is running, so Docker reports it as `Up`, but the application inside is still starting, overloaded, or hung. Swarm, Compose, and other orchestrators treat a running process as a healthy service, so they keep routing traffic to a container that cannot actually answer.

## Context

Docker separates "the process is alive" from "the application works" through the **HEALTHCHECK** instruction, which runs a command inside the container on a schedule. The container's **health status** reflects only the last checks:

* `starting` — during the `start-period`, failures are ignored so slow startups do not count.
* `healthy` — the scheduled checks passed.
* `unhealthy` — the check failed more than `retries` times in a row.

The health state is a container property, independent of the `Up`/`Exited` process state shown by `docker ps`.

## Solution

Declare the healthcheck in the `Dockerfile` so every image built from it carries the probe:

```
FROM nginx:alpine
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O - http://localhost/healthz || exit 1
```

Or attach it at runtime without changing the image:

```
docker run -d --name myapp \
  --health-cmd "curl -f http://localhost/healthz" \
  --health-interval 30s \
  --health-retries 3 nginx:alpine
```

Probe an application endpoint instead of a process check: `curl`/`wget` against `/healthz` proves the app answers, while `pidof` only proves a PID exists. Keep the probe minimal so the check itself does not drag extra tools into the image.

**Verify it directly** — read the container's live health state:

```
docker inspect --format '{{.State.Health.Status}}' myapp
```

## When to use

* Long-running services that should leave the rotation once they cannot serve.
* Slow-starting apps that need a `start-period` so the first checks do not count.
* Swarm/Compose setups where health state drives routing and updates.