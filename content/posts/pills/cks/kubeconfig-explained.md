---
date: '2026-10-16T09:00:00Z'
title: 'Kubeconfig Explained: Clusters, Users and Contexts'
category: ['cks']
---

## Problem

Every call to the API server needs the server address plus three credentials: the client key, the client certificate, and the CA certificate. Passing them as flags on every command is unworkable, and hardcoding them in scripts leaks secrets. You need one file that holds the credentials and switches between clusters and users.

## Context

A **kubeconfig** file is the CLI's client-side configuration. kubectl reads it from `$HOME/.kube/config` by default, or from any path passed to `--kubeconfig`, and uses it to talk to the API server. Without it, the equivalent curl call spells everything out:

```
curl https://my-kube-playground:6443/api/v1/pods \
  --key admin.key \
  --cert admin.crt \
  --cacert ca.crt
```

The file organizes the same data into three sections: **clusters** (API servers you reach), **users** (credentials that authenticate), and **contexts** (which user talks to which cluster). A context is a named pairing, like `prod-user@production`.

## Solution

A minimal kubeconfig:

```
apiVersion: v1
kind: Config
current-context: admin@production
clusters:
- name: production
  cluster:
    certificate-authority: ca.crt
    server: https://172.17.0.51:6443
contexts:
- name: admin@production
  context:
    cluster: production
    user: admin
    namespace: finance
users:
- name: admin
  user:
    client-certificate: admin.crt
    client-key: admin.key
```

* **`current-context`** selects the active context — the default kubectl uses.
* A context can set a **default namespace** (`finance`), so you skip `--namespace` per command.
* `certificate-authority` can be an absolute file path; `certificate-authority-data` embeds the base64-encoded CA instead, which is more portable.

Switch clusters, users, or namespaces without touching the file by hand:

```
kubectl config use-context prod-user@production
kubectl config set-context admin@production --namespace=finance
```

**Verify it here** — confirm which context kubectl is using right now:

```
kubectl config view
```

`kubectl config view` prints the file's clusters, contexts, and users plus `current-context`, so you can confirm kubectl is authenticating against the cluster and user you intend.

## When to use

* Managing several clusters (dev, staging, prod) from one machine.
* Switching identity or namespace quickly instead of re-editing flags.
* Troubleshooting which cluster or user an API call is actually sent as — or is refused for.