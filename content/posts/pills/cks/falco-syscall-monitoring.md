---
date: '2026-10-03T19:00:00Z'
title: 'What Falco Does: Syscall Monitoring and Policy Engine'
category: ['cks']
---

## Problem

Hundreds of pods generate thousands of syscalls a second. `strace` analyzes a single process, but you cannot stare at raw syscall streams across a fleet — and you will miss the one `cat /etc/shadow` that means a container is compromised and must be contained immediately.

## Context

Falco performs **behavioral analytics on syscall processes**: it captures syscalls from user-space applications into the kernel and runs them through a policy engine that filters events against rules. Two behaviors a compromised pod exhibits:

* Reading the password-hash file:

```
kubectl exec -it nginx-master -- bash
cat /etc/shadow > /opt/logs/audit.log
```

* Deleting audit logs to erase the attacker's trail.

A rule hit raises an alert over **syslog, standard output, Slack, or email** — the same instant-notification model as a bank flagging an odd card transaction immediately rather than in the end-of-month statement.

## Solution

Install Falco on each node, or deploy it as a DaemonSet across the cluster:

```
curl -s https://falco.org/repo/falcosecurity-3672BA8F.asc | apt-key add -
echo "deb https://download.falco.org/packages/deb stable main" | tee /etc/apt/sources.list.d/falcosecurity.list
sudo apt update -y
sudo apt-get install -y linux-headers-$(uname -r)
sudo apt install -y falco
sudo systemctl start falco
```

Running as a node service keeps Falco isolated from the Kubernetes environment, so it keeps detecting even when a container on that node is compromised. Early detection shrinks the blast radius: on an alert, replace the compromised pod and patch the exploited component.

**Verify it directly** — the agents must be up on every node:

```
kubectl get pods
```

When every `falco-*` pod is `1/1 Running`, syscall events are flowing into the policy engine continuously.

## When to use

* Detecting container compromise early, when prevention controls have already failed.
* Watching for `bash` shells in pods, `/etc/shadow` reads, and audit-log tampering.
* Feeding alerts into a channel security teams actually watch, in real time.