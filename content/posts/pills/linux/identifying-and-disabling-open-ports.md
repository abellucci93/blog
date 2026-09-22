---
date: '2026-10-05T14:00:00Z'
title: 'Identifying and Disabling Open Ports on Linux'
category: ['linux']
---

## Problem

A freshly provisioned node starts dozens of services, and each one that answers on the network is a listener an attacker can reach. On a Kubernetes control-plane node the surface is wide: `22` for SSH, `2379` for etcd, `6443` for the API server, plus anything else that happened to be installed. If a port you never intended to expose is listening, you cannot reduce the attack surface until you can see every open listener and tell which is required.

## Context

When a process starts, it binds to a **port** — an addressable location that routes network traffic between applications. Port numbers follow conventions: `22` is dedicated to an SSH server, `53` to DNS. On Ubuntu-based systems, `/etc/services` maps service names, protocols, and port numbers, so you can confirm what a port belongs to before touching it.

Not every listener is junk. etcd on `2379`, the kubelet on `10250`, and the API server on `6443` are essential on cluster nodes. Consult the official documentation for the software you run (for example, kubeadm's required-port list) and decide which ports must stay open — then disable the rest.

## Solution

List every socket in `LISTEN` state:

```
netstat -an | grep -w LISTEN
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN
tcp        0      0 127.0.0.1:2379          0.0.0.0:*               LISTEN
tcp6       0      0 :::6443                 :::*                    LISTEN
tcp6       0      0 :::8080                 :::*                    LISTEN
```

Take each unrecognised port and cross-check it:

```
grep -w 8080 /etc/services
```

If the port does not map to a service the node requires, stop and disable the owning unit:

```
systemctl stop proxy
systemctl disable proxy
```

If no unit owns it, block the port instead with UFW or iptables.

**Verify it directly** — re-list listeners and confirm the port is gone:

```
netstat -an | grep -w LISTEN | grep 8080
```

Empty output means the listener is closed. Keep the listing as the baseline you re-run after every install.

## When to use

* Auditing a node before or right after a cluster install.
* Confirming which services a control-plane or worker node genuinely needs.
* Preparing a baseline you can compare against future changes.
* Reducing the listening surface before a hardening review.