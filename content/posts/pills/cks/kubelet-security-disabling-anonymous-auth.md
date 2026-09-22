---
date: '2026-09-25T09:00:00Z'
title: 'Kubelet Security: Disabling Anonymous Authentication'
category: ['cks']
---

## Problem

Point a browser or curl at a worker node's kubelet API and it answers: by default unauthenticated requests are treated as **`system:anonymous`** and granted access to endpoints such as `/pods` and `/logs`. A pod that escaped containment, or any host on the network, can query node state without credentials.

## Context

The kubelet exposes its API on **port 10250** for full access and **10255** for read-only metrics. Its default posture is permissive: unauthenticated callers become the `system:anonymous` user in the `system:unauthenticated` group, and unless another method explicitly accepts the request it falls back to anonymous.

```
curl -sk https://localhost:10250/pods
```

An anonymous client getting a pod list means the node reveals data with zero authentication. Disabling anonymous access is best practice, but it is only half the job — you must enable a real authentication mechanism afterwards, or every legitimate request is simply rejected.

## Solution

Turn off anonymous authentication in the kubelet config file:

```
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: false
```

Equivalent flag in `kubelet.service`:

```
ExecStart=/usr/local/bin/kubelet \
  ...
  --anonymous-auth=false
```

Now supply a supported mechanism — the standard one is certificate-based authentication with `x509.clientCAFile`, so kube-apiserver talks to the kubelet using a CA-signed client certificate (`--kubelet-client-certificate` / `--kubelet-client-key`).

**Verify it here** — repeat the anonymous probe; it must be denied:

```
curl -sk -o /dev/null -w '%{http_code}\n' https://localhost:10250/pods
```

With anonymous disabled and no certificate presented, this returns `401 Unauthorized` instead of a pod list.

## When to use

* Default hardening step for every worker node, before anything else is exposed.
* Environments where cluster and node networks are not fully trusted — which is most of them.
* Paired with certificate (or token) auth and webhook authorization; never disable anonymous auth in isolation and leave legitimate requests rejected.