---
date: '2026-09-29T19:00:00Z'
title: 'Minimize Base Image Footprint: Alpine vs Distroless'
category: ['cks']
---

## Problem

Your image is a full OS: package manager, shell, curl, compilers — and every installed package is a potential CVE. Two HTTP servers that behave identically expose very different surfaces:

```
trivy image httpd
# httpd (debian 10.8)  Total: 124 (88 LOW, 25 HIGH, 2 CRITICAL)

trivy image httpd:alpine
# httpd:alpine (alpine 3.12.4)  Total: 0
```

## Context

The image you push builds on **base images**: `FROM httpd`, which itself is `FROM debian:buster-slim`, which is `FROM scratch` plus a rootfs. Every inherited layer is **executable attack surface** that ends up on every node that pulls the image. Larger images are also slower to pull and start.

Image hygiene rules:

* **Modular images** — one task per container with its own dependencies; no web server plus database in one image.
* **No state in containers** — write to volumes or a cache, never into the image layer.
* **Remove what production does not need** — temporary files, debugging tools like `curl` and `wget`, and package managers (`apt`, `yum`) once the image is built.
* **Separate dev and prod images** — debug tooling lives in dev only.

## Solution

Choose a minimal base deliberately:

* **Alpine** — a few MB, musl-based, keeps a shell and package manager. Small and still malleable.
* **Distroless** — application and runtime dependencies only; **no shell, no package manager, no network tools**. Nothing for an attacker to call, little to poke around in.

A minimal Alpine web image:

```
FROM alpine:3.12.4
COPY index.html htdocs/index.html
```

**Verify it** — scan a candidate image before pushing it and fail the build on findings:

```
trivy image httpd:alpine
# Total: 0 (UNKNOWN: 0, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
```

## When to use

* **Alpine** when the image still needs a shell or package manager — debugging layers, tooling sidecars.
* **Distroless** for production artifacts where dependencies are fixed and the surface should be minimal.
* Always pull from official or verified-publisher images that are patched regularly — a small image that is never updated is still a risk.