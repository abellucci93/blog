---
date: '2026-10-10T14:00:00Z'
title: 'kubesec: Static Analysis for Kubernetes Manifests'
category: ['cks']
---

## Problem

You run `kubectl create -f pod.yaml`, and only after the object exists do the checks start — or never run at all. A manifest that executes as root with `privileged: true`, an added `CAP_SYS_BOOT`, and a `hostPath` volume sails straight into the cluster.

## Context

A pod request passes through admission controllers only **after** you submit it. By that point the file is written and applied, and nothing has inspected it earlier. Static analysis moves the check **before** deployment: the manifest is scanned while it is still a file on disk, in a code review, or in CI.

This is the kind of manifest that reaches clusters today:

```
apiVersion: v1
kind: Pod
metadata:
  name: sample-pod
spec:
  containers:
    - name: ubuntu
      image: ubuntu
      command: ["sleep", "3600"]
      securityContext:
        privileged: true
        runAsUser: 0
        capabilities:
          add: ["CAP_SYS_BOOT"]
  volumes:
    - name: data-volume
      hostPath:
        path: /data
        type: Directory
```

## Solution

**kubesec** scans Kubernetes resource files and returns a **score** with structured findings. On the manifest above it reports `score: -30` with a critical finding: `Privileged` — "Privileged containers can allow almost complete system access." It also suggests hardening such as a `serviceAccountName` and AppArmor annotations.

Run it three ways:

* Local binary against the manifest:
```
kubesec scan pod.yaml
```
* Remote HTTP service, no install:
```
curl -sSX POST --data-binary @"pod.yaml" https://v2.kubesec.io/scan
```
* Local HTTP server:
```
kubesec http 8080 &
```

The JSON output can gate a release in CI:

```
{
  "object": "Pod/sample-pod.default",
  "valid": true,
  "score": -30,
  "scoring": {
    "critical": [
      {
        "id": "Privileged",
        "reason": "Privileged containers can allow almost complete system access."
      }
    ]
  }
}
```

**Verify it** — the scan is the verification; fail the pipeline on a negative score:

```
kubesec scan pod.yaml
```

## When to use

* As a CI gate on every merged manifest, catching privilege and `hostPath` mistakes before apply.
* During design review, to get a concrete score for a proposed workload.
* To complement — not replace — admission controllers that still check at submit time.
