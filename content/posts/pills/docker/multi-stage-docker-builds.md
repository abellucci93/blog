---
date: '2026-09-26T14:00:00Z'
title: 'Multi-Stage Docker Builds: Smaller Images, Smaller Attack Surface'
category: ['docker']
---

## Problem

You compile a binary, run static checks, then ship the image — and the image still carries the compiler, package manager, and every build-time tool. The result is a bloated image whose extra packages each add attack surface and CVEs, and every push and pull becomes slower.

## Context

An image built with a single `FROM` contains everything from that base image plus what every `RUN` and `COPY` added. The packages that exist only to build the application have no job at runtime, yet they ship anyway.

A small base image pays off directly in vulnerabilities: scanners commonly report 100+ findings on a standard `httpd` image and zero on its `alpine` variant, because fewer installed packages means fewer things to exploit.

## Solution

Split the build into stages: a **builder** stage with the toolchain, and a **final** stage with a minimal runtime that receives only the built artifact via `COPY --from`:

```
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /bin/app .

FROM alpine:3.20
RUN adduser -D appuser
COPY --from=builder /bin/app /usr/local/bin/app
USER appuser
ENTRYPOINT ["app"]
```

Only the final stage's instructions are persisted. The builder stage — Go toolchain, source, `go build` — never leaves the build host, so it never reaches the registry.

Keep the final stage lean:

* One application per image, so each image owns its dependencies and scales independently.
* No package manager, shell, or network tools unless the app truly needs them; `distroless` images ship only the runtime.
* No runtime data inside the container — keep state in volumes.

**Verify it directly** — build the image and check how small the final artifact is:

```
docker build -t myapp . && docker image inspect --format '{{.Size}}' myapp
```

## When to use

* Any language with a build step: Go, Java, Node, Rust, C/C++.
* Production images that want the smallest footprint and the fewest vulnerabilities.
* Scanning with tools like `trivy image` and watching the final stage drop to zero findings.