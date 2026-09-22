---
date: '2026-10-10T19:00:00Z'
title: 'CoreDNS in Kubernetes: How Service Discovery Works'
category: ['cka']
---

## Problem

Two pods get fresh IPs on every restart, so `/etc/hosts` entries you added last week now point at dead addresses. You want a pod to reach a backend with `curl http://web-service` and never edit a hosts file again.

## Context

The Kubelet writes each pod's `/etc/resolv.conf` to point at one **cluster DNS server**, sourced from its own config:

```
cat /etc/resolv.conf
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
```

That nameserver is the **kube-dns** Service at `10.96.0.10`, backed by a **CoreDNS** Deployment of two replicas in `kube-system`. CoreDNS reads its plugins from the ConfigMap at `/etc/coredns/Corefile` and watches the API server to register new Services and pods on the fly; the Kubelet fills in `clusterDNS` and `clusterDomain` in its own config.

Service names resolve to the full name `name.namespace.svc.cluster.local`. Pod records use the dotted IP, and unlike Services they need **the full FQDN** — short names are not expanded for pods:

```
host 10-244-2-5
Host 10-244-2-5 not found: 3(NXDOMAIN)
host 10-244-2-5.default.pod.cluster.local
10-244-2-5.default.pod.cluster.local has address 10.244.2.5
```

## Solution

Start from the Service that every pod resolves through:

```
kubectl get service -n kube-system
NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)           AGE
kube-dns     ClusterIP   10.96.0.10     <none>        53/UDP,53/TCP     1d
```

From any pod, all of these hit the same backend because the search list `default.svc.cluster.local svc.cluster.local cluster.local` appends the suffix:

```
curl http://web-service
curl http://web-service.default
curl http://web-service.default.svc
curl http://web-service.default.svc.cluster.local
```

The `kubernetes` plugin in the Corefile owns the `cluster.local` zone, forwards everything else to the upstream in `/etc/resolv.conf`, and caches replies; modify behavior through the ConfigMap in `kube-system`.

**Verify core DNS with one lookup:**

```
kubectl run dns-test --rm -it --image=busybox --restart=Never -- host web-service.default.svc.cluster.local
```

## When to use

* Reaching a Service by short name from another pod.
* Debugging `NXDOMAIN`: a short host name fails outside its namespace — use the FQDN.
* Any symptom that DNS records are stale or missing; the `kube-dns` Service and the CoreDNS ConfigMap are the first two places to look.