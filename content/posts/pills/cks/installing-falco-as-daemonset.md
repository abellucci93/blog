---
date: '2026-10-04T19:00:00Z'
title: 'Installing Falco as a DaemonSet with Helm'
category: ['cks']
---

## Problem

A node-level audit tool installed once as a package or service only watches the host it runs on. On a multi-node cluster, events from pods on other nodes — a shell spawned in a container, a read of `/etc/shadow` — are never seen, so anomalous behavior on one worker goes undetected.

## Context

**Falco** monitors Linux system calls and runs them through a policy engine with predefined rules, alerting on suspicious activity. It talks to the kernel either through a **kernel module** or through **eBPF**, which is less invasive and preferred by managed providers.

Installing Falco as a package on a node keeps it isolated from the Kubernetes environment even if the cluster is compromised, but that means one install per node. The cluster-native way to run it on every node is a **DaemonSet** that schedules one pod per node.

## Solution

Deploy Falco from the official Helm chart into every node:

```
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco
```

Trigger events so you can watch Falco work. Deploy a workload, find its node, and stream the Falco log on that node:

```
kubectl run nginx --image=nginx
kubectl get pods -o wide
ssh <node> "journalctl -fu falco"
```

Open a shell in the nginx container and read a sensitive file:

```
kubectl exec -ti nginx -- bash
cat /etc/shadow
```

Falco logs an alert for the spawned shell and for the access to `shadow`, both from its default rules. You can add your own rules — each combines a **rule**, **desc**, **condition**, **output**, and **priority**, and can reuse helper **lists** and **macros**:

```
- rule: Detect Shell inside a container
  desc: Alert if a shell such as bash is open inside a container
  condition: container and proc.name in (linux_shells)
  output: Bash Opened (user=%user.name container=%container.id)
  priority: WARNING

- list: linux_shells
  items: [bash, zsh, ksh, sh, csh]

- macro: container
  condition: container.id != host
```

**Verify it here** — confirm a Falco pod is running on every node:

```
kubectl get pods -l app.kubernetes.io/name=falco
```

One `falco-*` pod per node, all `1/1 Running`, means the DaemonSet is monitoring the whole cluster. If the provider forbids kernel modules, install Falco with the eBPF driver instead.

## When to use

* Runtime threat detection on every node without logging into each host to install packages.
* Managed clusters that restrict kernel modules — switch the driver to eBPF.
* Keeping Falco isolated from the control plane so it keeps detecting even during an incident.