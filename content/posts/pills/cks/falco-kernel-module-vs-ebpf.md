---
date: '2026-10-15T09:00:00Z'
title: 'Falco Kernel Module vs eBPF: Choosing the Driver'
category: ['cks']
---

## Problem

Falco must attach to the kernel to see syscalls, and how it attaches is not always your call. On managed Kubernetes (GKE, EKS, AKS) providers often **block kernel modules**, so a Falco install that defaults to the module fails to run or is denied outright.

## Context

Falco reaches the kernel through two drivers:

* **Kernel module** — extra code inserted into the kernel. Effective but intrusive, and rejected on many managed providers.
* **eBPF** — a less invasive probe that runs inside the kernel's virtual machine without modifying it; generally the preferred, provider-friendly choice.

With either driver, captured syscalls flow through user-space libraries into Falco's **policy engine**, which matches them against rules and alerts via syslog, stdout, Slack, or email.

## Solution

Installing the package on a node pulls the kernel module by default:

```
curl -s https://falco.org/repo/falcosecurity-3672BA8F.asc | apt-key add -
echo "deb https://download.falco.org/packages/deb stable main" | tee /etc/apt/sources.list.d/falcosecurity.list
sudo apt update -y
sudo apt-get install -y linux-headers-$(uname -r)
sudo apt install -y falco
sudo systemctl start falco
```

On restricted nodes, switch to the eBPF probe by setting `FALCO_BPF_PROBE=""` in Falco's environment before it starts. For cluster-wide coverage, deploy Falco as a **DaemonSet** — one agent per node — via the official Helm chart.

Install Falco directly on the node as a service rather than inside a pod: it stays isolated from the Kubernetes environment, so it keeps detecting even when a container on that node is compromised.

**Verify it directly** — after deployment, one agent must be running per node:

```
kubectl get pods
```

Every `falco-*` pod at `1/1 Running` means the chosen driver is capturing syscalls and feeding the policy engine.

## When to use

* Managed Kubernetes that rejects kernel modules — force eBPF.
* Self-managed nodes where the module's intrusion is acceptable.
* Auditing runtime-scanning posture with one agent per node.