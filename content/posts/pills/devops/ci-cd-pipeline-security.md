---
date: '2026-09-26T09:00:00Z'
title: 'CI/CD Pipeline Security: Scanning Secrets and Images'
category: ['devops']
---

## Problem

Your pipeline builds an image and ships it. Nothing checks the image content before it reaches the cluster, and the build machine holds credentials in plaintext. One critical CVE or one leaked token is all it takes: the vulnerable image is deployed, the secret is used, and production is compromised before anyone notices.

## Context

Software moves through a **supply chain**: source, build, test, deploy. Each stage can be skipped or tampered with. The common failure points are **known-vulnerability images** (an unpatched component exploited for a data breach), **credentials stored insecurely** (a `Dockerfile` with `ENV AWS_SECRET=...`), and **overly permissive runtime** (missing RBAC and network policies letting a compromised pod reach the host). Scanning is not optional hygiene on top of the chain; it is the gate that keeps a bad artifact out of the registry and the cluster.

## Solution

Fail the build on findings at each stage:

```
trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed your-registry.io/apps/api:2.4.1
```

Keep the scan result as an artifact record for audits:

```
trivy image --format json your-registry.io/apps/api:2.4.1 > trivy-report.json
```

Scan for credentials before they reach the registry:

```
gitleaks detect --source . --redact --exit-code 1
```

Treat findings as merge blockers, not advisories. Never bake secrets into images: hold them as Kubernetes Secrets and never let them appear in build logs or env vars. On the runtime side, pair scanning with **least-privilege RBAC** and **network policies** so a container that does get compromised cannot pivot across the cluster.

**Verify it directly** — confirm the gate actually fires on a known-bad image:

```
trivy image --exit-code 1 --severity CRITICAL alpine:3.14; echo $?
```

Exit code `1` means the scanner would block the build; `0` means it passed.

## When to use

* Any pipeline that produces deployable images or packages.
* Clusters that pull images from public or shared registries.
* CI/CD systems that hold credentials and must keep them out of images and logs.
* Compliance and audits: the scan report is the artifact record.