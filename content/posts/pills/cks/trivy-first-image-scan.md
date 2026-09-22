---
date: '2026-10-06T19:00:00Z'
title: 'Trivy: Your First Image Scan'
category: ['cks']
---

## Problem

You deploy an image and weeks later discover it ships Nginx `1.14.2`, a version with a published vulnerability nobody noticed because the artifact was never checked. You need a one-command way to know, before the image runs, which installed packages are exposed.

## Context

A **CVE** (Common Vulnerabilities and Exposures) is a published, uniquely identified weakness in a piece of software. Each one carries a severity from low to critical and a score, typically 0-10 — a 9.x or "critical" needs immediate remediation. An image bundles dozens of system packages, so tracking exposure by hand is not viable; a scanner matches each installed version against the CVE database at scan time. Trivy (Aqua Security) runs as a single CLI call and slots straight into a CI/CD pipeline.

## Solution

Install Trivy on Debian or Ubuntu:

```
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy
```

Name the image exactly as you would `docker run` it — the tag pins what gets fingerprinted:

```
trivy image nginx:1.18.0
```

Each row names the library, the vulnerability ID, severity, installed version, and a short title:

```
+------------------+---------------------+----------+-----------------+-----------------------------------------+
|      LIBRARY     |    VULNERABILITY ID | SEVERITY | INSTALLED VERSION|                  TITLE                 |
+------------------+---------------------+----------+-----------------+-----------------------------------------+
| curl             | CVE-2020-8169       | HIGH     | 7.64.0-4+deb10u1 | libcurl: Partial password disclosure     |
+------------------+---------------------+----------+-----------------+-----------------------------------------+
```

Remediate by upgrading the package to a patched release, removing it, or adding compensating controls. Fewer packages in the image means smaller attack surface.

**Verify it directly** — compare a minimal base against the same tag:

```
trivy image nginx:1.18.0-alpine
```

The leaner base usually reports zero findings against the distro's 155; that contrast is the vulnerability you control before you ever deploy.

## When to use

* Before any image reaches a cluster — scan in CI/CD on every build.
* Choosing base images: the scorecard decides which distro ships with your app.
* Repeat scans on a cadence — a clean report today can be a critical CVE tomorrow.