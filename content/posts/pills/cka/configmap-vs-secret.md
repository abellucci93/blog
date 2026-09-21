---
date: '2026-09-27T09:00:00Z'
title: 'ConfigMap vs Secret: When to Use Each'
category: ['cka']
---

## Problem

A pod needs configuration (hostname, user, port) **and** credentials (password, API key). Hard-coding both in the pod spec, or dumping every value into a single ConfigMap, either bloats the pod definition or leaks passwords into plaintext.

## Context

**ConfigMap** and **Secret** both exist to externalize data from the pod spec and inject it at runtime via `envFrom`, `valueFrom`, or volume mounts. The trap: a Secret is **not** encryption — it is **Base64-encoded** by default. Shelter only hostile-to-share values there, never treat it as a vault.

## Solution

Split by sensitivity: non-sensitive config → **ConfigMap**, credentials → **Secret**.

ConfigMap (declarative):

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_COLOR: blue
  APP_MODE: prod
```

Secret (declarative, values Base64-encoded):

```
echo -n 'paswrd' | base64   # cGFzd3Jk
```

```
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
data:
  DB_Host: bXlzcWw=   # mysql
  DB_User: cm9vdA==   # root
  DB_Password: cGFzd3Jk
```

Create and inject both into one pod:

```
kubectl create -f config-map.yaml -f secret-data.yaml
```

```
apiVersion: v1
kind: Pod
metadata:
  name: simple-webapp-color
spec:
  containers:
    - name: simple-webapp-color
      image: simple-webapp-color
  envFrom:
    - configMapRef:
        name: app-config
    - secretRef:
        name: app-secret
```

Verify the values landed in the pod:

```
kubectl exec simple-webapp-color -- printenv | grep -E 'APP_COLOR|DB_Password'
# APP_COLOR=blue
# DB_Password=paswrd
```

Troubleshooting: a missing ConfigMap crashes or blocks pod **creation**; a missing Secret also blocks creation, and a Secret referred to by `envFrom` but missing a key keeps the pod **running** with that env var unset. To see stored data without dumping values, use `kubectl describe configmap app-config` — secrets show only key **counts**.

## When to use

* ConfigMap for anything **non-sensitive**: hostnames, ports, flags, feature toggles, `APP_COLOR: blue`.
* Secret for **credentials**: passwords, tokens, SSH keys, connection strings with secrets embedded.
* Always same-data-two-objects when a value is sensitive — never one ConfigMap "for convenience".
* Enable **encryption at rest** for etcd if Secret contents must stay protected at rest.
* Consider RBAC (limit who can *get* secrets) and external providers (Vault, cloud KMS) only when the plain `Secret` reaches its ceiling — not by default.
