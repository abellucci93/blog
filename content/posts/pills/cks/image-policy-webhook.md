---
date: '2026-10-13T14:00:00Z'
title: 'Image Policy Webhook: Whitelisting Allowed Registries'
category: ['cks']
---

## Problem

Anyone with pod-create access can deploy `some-registry.io/a-very-vulnerable-image`. That image runs against the node's kernel, and a known flaw in it can be exploited up to the underlying OS — exposing every other workload. You must whitelist registries so only `internal-registry.io` images ever land in the cluster.

## Context

A pod request passes **authentication → authorization → admission control** before it is persisted. `ImagePolicyWebhook` is a **built-in admission controller** in the API server that forwards each request to an external webhook server, letting you enforce the registry whitelist in code. The webhook's credentials and retry behavior come from an admission configuration file plus a kubeconfig.

## Solution

Tell the API server how to reach the webhook:

```
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/imagepolicy-kubeconfig.yaml
      allowTTL: 50
      denyTTL: 50
      retryBackoff: 500
      defaultAllow: true
```

The referenced kubeconfig supplies the webhook `server` URL and the API server's client certificate. Then enable the controller on the `kube-apiserver`:

```
--enable-admission-plugins=ImagePolicyWebhook \
--admission-control-config-file=/etc/kubernetes/admission-config.yaml
```

On reachability failure: `defaultAllow: true` lets requests through unless the webhook explicitly denies; `false` fails closed. Keep the webhook server highly available — it now sits in the pod-creation path.

**Verify it directly** — deploy an unapproved image and the API server rejects it:

```
kubectl create -f sample-pod.yaml
```

The webhook replies `allowed: false` with a `status.message`, so the pod is never created.

## When to use

* Enforcing internal-only registries across the whole cluster.
* Failing closed (`defaultAllow: false`) for strict environments.
* Prefer an OPA/Rego webhook when policy must go beyond registry names.