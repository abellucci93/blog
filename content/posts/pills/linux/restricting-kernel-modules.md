---
date: '2026-10-16T19:00:00Z'
title: 'Restricting Kernel Modules: A Hardening Step'
category: ['linux']
---

## Problem

Linux loads kernel modules automatically — on plugging in hardware, on opening a network socket, even from an unprivileged process. That convenience is also a vector: a protocol module such as SCTP or DCCP that your workloads never use can be pulled into memory by socket creation inside a container, widening the kernel interface an attacker can reach. On a cluster node the default should be: don't load what we don't use.

## Context

The kernel is **modular** by design; drivers and protocol stacks load on demand via `modprobe` or `insmod`, and `lsmod` shows what is currently active. Modules that ship but are never needed on a node are pure liability. Restriction works at the loader level: a **blacklist** entry under `/etc/modprobe.d/` tells `modprobe` a module is off-limits even when something triggers its load. A reboot is required so modules already resident are unloaded rather than just blocked from future loads.

## Solution

Create a `.conf` file under `/etc/modprobe.d/` with one `blacklist` line per module:

```
cat /etc/modprobe.d/blacklist.conf
blacklist sctp
blacklist dccp
```

Any filename ending in `.conf` in that directory is read by `modprobe`, so the filename itself carries no meaning. The file grows one `blacklist` line per unwanted module — audit `lsmod` first and add everything not required.

Then reboot so the running kernel drops them:

```
shutdown -r now
```

After the node returns to a shell, confirm neither module is resident.

**Verify it directly** — after reboot, both greps produce no output:

```
lsmod | grep dccp
lsmod | grep sctp
```

## When to use

* Hardening cluster nodes where SCTP, DCCP, and similar protocols are never used.
* Disabling unused drivers to shrink the kernel's attack surface.
* Applying the same blacklist across every node so one `lsmod` audit suffices.
* Verifying after a reboot that the blacklist took effect rather than trusting the file exists.