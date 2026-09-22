---
date: '2026-09-30T14:00:00Z'
title: 'UFW Firewall Basics: A Quick Ruleset for Any Server'
category: ['linux']
---

## Problem

An application server listens on ports `22` (SSH), `80` (HTTP), and `8080` — and by default everyone on the network can reach all of them. The desired posture is specific: SSH reachable only from the admin jump server, HTTP also reachable from internal clients, and `8080` closed to everyone. Expressing exactly that in raw iptables chains is where firewalling gets complicated.

## Context

Under the hood, filtering happens in **Netfilter**, the kernel's packet-filtering system, normally driven through iptables. **UFW** (Uncomplicated Firewall) is a front-end that translates plain-english rules into the same iptables chains. Its value is expressiveness: default policies plus a handful of allow/deny rules describe this posture exactly, and `ufw status` prints the resulting ruleset back readably.

## Solution

Install UFW, then set the default posture — allow outbound, deny inbound:

```
apt-get update && apt-get install -y ufw
ufw default allow outgoing
ufw default deny incoming
```

Add rules for the jump server and the internal client range:

```
ufw allow from 172.16.238.5 to any port 22 proto tcp
ufw allow from 172.16.238.5 to any port 80 proto tcp
ufw allow from 172.16.100.0/28 to any port 80 proto tcp
ufw deny 8080
```

The default policy already denies `8080`; the explicit rule documents the intent. Review the ruleset once before activating, because enabling the firewall can drop the very SSH session you are connected through:

```
ufw enable
```

**Verify it directly** — status reports the firewall active and the rules in order:

```
ufw status
Status: active
22/tcp      ALLOW    172.16.238.5
80/tcp      ALLOW    172.16.238.5
80/tcp      ALLOW    172.16.100.0/28
8080        DENY     Anywhere
```

## When to use

* A server with a small, known set of allowed clients.
* Segregating admin traffic (jump host) from client traffic.
* Replacing hand-written iptables scripts with something auditable.
* A quick default-deny baseline on Ubuntu hosts before application installs.