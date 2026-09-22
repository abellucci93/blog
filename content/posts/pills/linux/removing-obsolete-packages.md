---
date: '2026-10-12T19:00:00Z'
title: 'Removing Obsolete Packages and Services'
category: ['linux']
---

## Problem

Image templates and snapshots ship with software you never asked for — an Apache server running on a Kubernetes node that nobody knowingly installed. Every extra service is more software to patch, more ports listening, and another component that can be attacked. The node is unmaintainable until you know what is installed and can remove what is not required.

## Context

Modern distributions manage services with **systemd**, driven through `systemctl`. Most packages install their service unit automatically, and some services are added by hand, so the installed set is not always intentional. The goal is a lean node: only the packages a role needs (for example `kubelet`, `kubeadm`, and a container runtime) — everything else is noise, to be removed carefully without breaking dependencies.

## Solution

Check why a suspect service is running before touching it:

```
systemctl status apache2
```

Confirm it is active and note its unit file under `/lib/systemd/system/`. Then take stock of every loaded service:

```
systemctl list-units --type service
```

Stop, disable, and remove only what is not required:

```
systemctl stop apache2
systemctl disable apache2
apt remove apache2
```

Stopping alone only lasts until the next boot; `disable` removes the boot-time link, and `apt remove` deletes the package so it cannot come back as part of the normal install set. If the removal lists "no longer required" dependencies, follow up with `apt autoremove`. Before purging anything, confirm nothing else depends on it — removing essential software breaks the system.

**Verify it directly** — re-list services and confirm the unit is gone:

```
systemctl list-units --type service | grep apache2
```

Empty output means the service no longer exists, let alone runs.

## When to use

* Auditing a node cloned from a template or cloud image.
* Slimming a node down to its actual role before signing off.
* Recurring hygiene: compare installed services against a known-good list.
* Removing leftovers after a failed or abandoned install.