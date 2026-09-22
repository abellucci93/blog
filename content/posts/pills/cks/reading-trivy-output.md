---
date: '2026-09-27T09:00:00Z'
title: 'Reading Trivy Output: Interpreting Vulnerability Findings'
category: ['cks']
---

## Problem

`trivy image nginx:1.18.0` reports 155 issues in one screen. Deciding which to fix first is the real skill: a LOW finding in a rarely hit code path is not the same as a remotely exploitable CRITICAL. Reading the output wrong means either chasing noise or shipping a real vulnerability.

## Context

Trivy matches the packages in an image against the **CVE database**, the central registry of Common Vulnerabilities and Exposures. Each CVE carries a **severity** — `LOW`, `MEDIUM`, `HIGH`, `CRITICAL`, plus `UNKNOWN` — derived from a numeric **CVSS** score (0-10). The detail you get per package correlates with the score: an NGINX installer that pulls packages over plain HTTP is rated HIGH with 7.3.

Each row maps one installed package to one issue:

* `LIBRARY` — the package, e.g. `bash` or `curl`.
* `VULNERABILITY ID` — the CVE or Debian tracker id.
* `SEVERITY` — the coarse risk class.
* `INSTALLED VERSION` — the version present in your image.
* `TITLE` — one line describing what is actually exploitable.

A package with several CVEs appears once per issue, and the severity column can be empty when no rating exists. The summary line counts everything up front.

## Solution

Scan, then triage — the numbers tell you where the risk concentrates:

```
$ trivy image nginx:1.18.0
nginx:1.18.0 (debian 10.8)
Total: 155 (UNKNOWN: 0, LOW: 110, MEDIUM: 9, HIGH: 33, CRITICAL: 3)
```

Here 3 CRITICAL matter far more than the 110 LOW rows. Narrow the view to what is actionable, dropping rows that have no fixed version yet:

```
trivy image --severity CRITICAL,HIGH nginx:1.18.0
trivy image --ignore-unfixed nginx:1.18.0
```

For every remaining row: read the `TITLE`, decide whether the exposed path is reachable from your workload, then act — upgrade the base image or package, or remove the component entirely. Fewer packages means a smaller attack surface, so a slimmer base image is often the fastest fix. A clean scan today means nothing next week, so rescan on every build and gate the pipeline on CRITICAL/HIGH.

**Verify it directly** — re-run the scan filtered to one class and confirm it matches the summary count:

```
trivy image --severity CRITICAL nginx:1.18.0
```

You should see exactly the 3 CRITICAL rows from the summary, each with a CVE id, the installed version, and a title. The same command against `nginx:1.18.0-alpine` typically returns nothing — concrete evidence that the image, not a patch, is the difference.

## When to use

* Triaging a scan before an image reaches production.
* Setting a CI/CD gate on CRITICAL/HIGH findings.
* Justifying a base-image or package upgrade with evidence.