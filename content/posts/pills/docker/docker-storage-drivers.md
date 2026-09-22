---
date: '2026-09-23T14:00:00Z'
title: 'Docker Storage: Where Container Data Lives'
category: ['docker']
---

## Problem

You write a file inside a running container, remove the container, and the file is gone. Meanwhile every image on the box consumes many gigabytes of disk. Where data lives depends on the layer: image layers, the container's writable layer, and real volumes all behave differently and live in different places.

## Context

Docker stores everything under `/var/lib/docker`, split into subdirectories such as `containers`, `images`, `volumes`, and the driver directory (for example `overlay2`).

* **Images are layered.** Every Dockerfile instruction creates a layer holding only the changes from the previous one. Layers are shared and cached, so a second image using the same base and dependency layers reuses them.
* **Container writes are copy-on-write.** Image layers are read-only. Running a container adds a thin **writable layer** on top; the first write to a file copies it up from the image layer, leaving the image untouched. Removing the container deletes this writable layer and everything in it.
* **Volumes and bind mounts survive.** They bypass the writable layer entirely and live on the host filesystem.

Storage drivers such as `aufs`, `overlay2`, `zfs`, `btrfs`, and device mapper implement these layered read/write mechanics; Docker selects the right one for the host OS automatically.

## Solution

Keep ephemeral writes on the writable layer, but move anything that must survive across `docker rm` to a volume:

```
docker volume create data_volume
docker run -v data_volume:/var/lib/mysql mysql
```

A named volume is managed by Docker under `/var/lib/docker/volumes` and is created automatically if missing. For a host directory you control, use a bind mount with the explicit `--mount` form:

```
docker run --mount type=bind,source=/data/mysql,target=/var/lib/mysql mysql
```

Data written to `/var/lib/mysql` in the container then lands on the host and survives the container's removal.

**Verify it directly** — show the mount points attached to a running container:

```
docker inspect <container-id> --format '{{json .Mounts}}'
```

## When to use

* Any service with state that must survive `docker rm`.
* Databases and caches that write beneath their own writable layer.
* Telling ephemeral container data apart from persistent volume data.
* Choosing `--mount` when you want explicit, unambiguous source and target paths.