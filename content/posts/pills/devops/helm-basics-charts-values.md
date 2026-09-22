---
date: '2026-10-08T19:00:00Z'
title: 'Helm Basics: Charts, Values and Release Lifecycle'
category: ['devops']
---

## Problem

A WordPress deploy means a Deployment, a Service, a Secret for the admin password, a PersistentVolume, a PersistentVolumeClaim, and possibly a backup Job. Kept as separate YAML files, each gets its own `kubectl apply`, state is tracked by memory, and the first shared configuration change — say resizing storage from 20Gi to 2200Gi — risks breaking half the files.

## Context

**Helm** is the Kubernetes package manager. A **chart** is a package of files that describes an application: templates for each resource, a `values.yaml` with configuration defaults, and a `Chart.yaml` with metadata. Installing a chart produces a **release** — one tracked instance with a version history — and Helm stores that bookkeeping inside the cluster as Kubernetes Secrets, not on your laptop.

## Solution

A minimal chart renders its resources from values:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
        - name: hello-world
          image: "{{ .Values.image.repository }}"
```

```yaml
apiVersion: v2
name: hello-world
version: 1.0.0
appVersion: "1.16.0"
```

```yaml
replicaCount: 1
image:
  repository: nginx
```

One command installs, and every later change goes through the same tracked lifecycle:

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install hello-world bitnami/nginx --set image.repository=nginx:1.21.4
```

Upgrade to release revision 2, or roll back on trouble — rollback creates a *new* revision that mirrors the old state, it does not undo history:

```
helm upgrade hello-world bitnami/nginx --set image.repository=nginx:1.25.0
helm rollback hello-world 1
```

**Verify it directly** — inspect the release's revision trail:

```
helm history hello-world
```

Each row is one installation state you can audit or return to.

## When to use

* Deploying packaged apps (WordPress, Prometheus, ingress controllers) without writing ten manifests.
* Sharing an app between environments where only the values differ.
* When install, upgrade, and rollback must be first-class, tracked operations.
* Publishing your own app as a reusable chart for teams or a public repo.