---
date: '2026-10-07T14:00:00Z'
title: 'Trivy Filter Flags and Scanning Tar Archives'
category: ['cks']
---

## Problem

`trivy image nginx:1.18.0` prints a wall of findings — 155 rows on a Debian base, most of them low severity. You need the criticals now and the rest is noise. Separately, images often arrive as `docker save` tarballs, and you do not want to re-pull just to scan the exact bytes you will deploy.

## Context

Trivy fingerprints the packages inside an image and matches each installed version against the CVE database. A normal shipping image legitimately contains low- and medium-severity findings in `apt`, `bash`, `coreutils`, and curl, so the unfiltered report is not an action plan. A tar archive produced by `docker save` holds the same layers as the registry image, so it can be scanned offline with the `--input` flag instead of an image name.

## Solution

Narrow the report to the severities that matter — the flag accepts a comma-separated list:

```
trivy image --severity CRITICAL nginx:1.18.0
trivy image --severity CRITICAL,HIGH nginx:1.18.0
```

Drop findings with **no fixed version available**, since those cannot be remediated yet:

```
trivy image --ignore-unfixed nginx:1.18.0
```

Scan an archive without a registry round-trip:

```
docker save nginx:1.18.0 > nginx.tar
trivy image --input nginx.tar
```

Combine the two for the tightest practical gate: `--severity CRITICAL,HIGH --ignore-unfixed` reports only the actionable problems.

**Verify it directly** — run the gate against the archive:

```
trivy image --input nginx.tar --severity CRITICAL,HIGH --ignore-unfixed
```

The surviving rows are the findings your pipeline should block on.

## When to use

* Gates in CI/CD: allow a build only when the filtered report is empty.
* Offline or air-gapped pipelines that scan the artifact, not the registry.
* Cutting alert fatigue: `--ignore-unfixed` when policy only cares about fixable CVEs.