---
date: '2026-09-21T19:00:00Z'
title: 'Kubernetes Audit Logs: Detecting Suspicious API Calls'
category: ['cks']
---

## Problem

Falco can see a shell spawned inside a container, but it cannot tell you who ran `kubectl delete pod webapp-pod -n prod-namespace` or whether that call was legitimate. You need a record of every **API request**: the requester, the object, and the verb.

## Context

The `kube-apiserver` is the single entry point for cluster interactions, and every request passes through stages:

* **RequestReceived** — the request arrives; an event is generated regardless of validity.
* **ResponseStarted** — a response began; useful for long-running requests such as `--watch`.
* **ResponseComplete** — the response body is sent.
* **Panic** — the request errored or was invalid.

Auditing is built into `kube-apiserver` but **disabled by default**. You must enable it and define which events to keep, or the volume of events becomes overwhelming.

## Solution

Write an audit **policy** — an `audit.k8s.io/v1` `Policy` with `omitStages` and `rules`. This one captures only the `delete` of a specific pod:

```
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: ["RequestReceived"]
rules:
  - level: RequestResponse
    namespaces: ["prod-namespace"]
    verbs: ["delete"]
    resources:
      - group: ""
        resources: ["pods"]
        resourceNames: ["webapp-pod"]
```

`level: RequestResponse` records request and response bodies; `Metadata` keeps only timestamps and operation details; `None` skips logging. Point `kube-apiserver` at the policy and a log file in its static pod manifest:

```
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
    - command:
        - kube-apiserver
        - --audit-log-path=/var/log/k8-audit.log
        - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
        - --audit-log-maxbackup=5
        - --audit-log-maxage=10
```

**Verify it** — delete the watched pod, then read the backend:

```
kubectl delete pod webapp-pod -n prod-namespace && cat /var/log/k8-audit.log
```

The resulting JSON `Event` records `verb: delete`, the user, the `requestURI`, and `responseStatus.code`, proving only the calls you selected are logged.

## When to use

* Detecting who deleted or modified sensitive objects after the fact.
* Auditing every access to Secrets without drowning in request noise.
* Feeding API events to an external service via the webhook audit backend.