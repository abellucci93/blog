---
date: '2026-10-13T19:00:00Z'
title: 'Dockerfile Best Practices: Layer Caching and COPY vs ADD'
category: ['docker']
---

## Problem

Rebuilding your image re-downloads and reinstalls every dependency even when you changed one source file. Worse, the image keeps getting larger because tarballs and remote files are fetched inside `RUN` calls. Both symptoms trace back to how **layer caching** works and to choosing `COPY` over `ADD`.

## Context

Each instruction in a Dockerfile becomes a **layer**, and layers are cached. On a rebuild, Docker reuses a cached layer only if the instruction and its inputs are unchanged. When an instruction changes, every layer below it is rebuilt — so **order** is the biggest lever on build speed.

The `image:` reference follows registry naming: `nginx` is shorthand for `docker.io/library/nginx`. Choosing a small, trusted base image is not just about size — fewer installed packages means a smaller **attack surface** and fewer known vulnerabilities.

## Solution

Put rarely-changing instructions first and frequently-changing ones last, so the cache survives code edits:

```
FROM node:lts-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
CMD ["node", "index.js"]
```

Because `COPY package*.json` runs before `RUN npm install`, dependencies are reinstalled only when the manifest changes, never on an unrelated source edit. `COPY` copies exactly what you list from the build context, and nothing else.

Prefer **`COPY` over `ADD`**:

* `COPY` is precise and predictable: it copies only the listed files and directories.
* `ADD` additionally fetches remote URLs and auto-extracts local tarballs, behavior that is rarely wanted during a build and hard to reason about.
* If a download is required, do it in `RUN` with `curl` or `wget`, and clean up afterward.

**Verify it directly** — build twice and watch the second run reuse layers:

```
docker build -t myapp .
docker build -t myapp .
```

## When to use

* Any Dockerfile where dependency installation precedes your own code.
* Keeping production images small by choosing minimal, trusted base images.
* Reviewing how `COPY` versus `ADD` affects cache reuse and image size.