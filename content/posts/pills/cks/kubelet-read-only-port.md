---
date: '2026-10-01T09:00:00Z'
title: 'The Kubelet Read-Only Port: Why to Disable It'
category: ['cks']
---

## Problem

The kubelet listens on **port 10255**, a read-only API that serves metrics and node data with **no authentication** at all. On a node reachable from the internal network, anyone — a compromised pod, a network scanner, a misconfigured firewall — can curl it and read cluster information without presenting any credential.

## Context

The kubelet exposes two ports:

* **10250** — the full kubelet API (health checks, metrics, port forwarding, command execution). Protected once you configure authentication and authorization.
* **10255** — a read-only endpoint (`/metrics`, node data) that historically required no authentication.

```
curl -sk http://localhost:10255/metrics
```

The read-only port exists so monitoring agents can scrape data without credentials, but the same channel leaks sensitive node information to anyone with network access to the node.

## Solution

Disable the read-only port by setting it to `0`, in the kubelet config file:

```
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
readOnlyPort: 0
```

Or on the command line in `kubelet.service`:

```
ExecStart=/usr/local/bin/kubelet \
  ...
  --read-only-port=0
```

`readOnlyPort: 0` means the kubelet stops binding the unauthenticated port entirely. Monitoring agents that need node metrics should scrape the authenticated kubelet API on 10250 instead, using a CA-verified certificate.

**Verify it here** — on the node, confirm nothing listens on 10255 anymore:

```
sudo ss -tlnp | grep 10255
```

An empty result — and `curl -sk http://localhost:10255/metrics` failing to connect — confirms the read-only port is off.

## When to use

* Every kubelet that has no legacy unauthenticated scraper depending on 10255.
* After auditing where node metrics come from, so disabling the port does not silently break monitoring.
* As part of cluster hardening: the read-only port is disabled in CIS benchmarks and secure installation defaults.