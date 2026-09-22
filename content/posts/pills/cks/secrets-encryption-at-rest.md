---
date: '2026-09-23T09:00:00Z'
title: 'Secrets at Rest: EncryptionConfiguration and External Secrets'
category: ['cks']
---

## Problem

A `Secret` in Kubernetes is only **base64-encoded**, not encrypted. Anyone who can read etcd — a backup, a debug console, a compromised control-plane host — can decode every secret in the cluster, including database credentials. `kubectl get secret -o yaml` shows the base64 form, and `echo ... | base64 --decode` recovers the plaintext in one step. The API server encrypts data only if you configure it to, and by default it does not.

## Context

Secrets are stored under `/registry/secrets/<namespace>/<name>` in etcd. Whether encryption is on is a flag check on the API server:

```
ps aux | grep kube-apiserver
```

If `--encryption-provider-config` is absent, secrets are written to etcd in plaintext. Encryption at rest comes from an **EncryptionConfiguration** file plus a list of providers, and order matters — the **first** provider encrypts new writes, everything after it is a read fallback:

* `aescbc`, `aesgcm`, `secretbox` — real encryption, different algorithms.
* `identity` — no encryption; valid only as a fallback, listed after an encrypting provider.

A key's `secret` value must be the base64 encoding of exactly 32 random bytes.

## Solution

Create the configuration:

```
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <base64-of-32-random-bytes>
  - identity: {}
```

Generate the key with `head -c 32 /dev/urandom | base64`. Place the file on the control-plane node (e.g. `/etc/kubernetes/enc/enc.yaml`) and wire it into the kube-apiserver manifest: a `--encryption-provider-config` flag, a read-only volume mount, and a hostPath volume:

```
spec:
  containers:
  - command:
    - kube-apiserver
    - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml
    volumeMounts:
    - name: enc
      mountPath: /etc/kubernetes/enc
      readOnly: true
  volumes:
  - name: enc
    hostPath:
      path: /etc/kubernetes/enc
      type: DirectoryOrCreate
```

Only objects written after the restart are encrypted, so re-encrypt existing secrets:

```
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

**Verify it directly** — create a secret, then read the raw etcd value; you must not see the plaintext:

```
ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/default/my-secret | hexdump -C
```

Before encryption the ASCII column shows the decoded secret; after, it shows ciphertext. For stronger guarantees, keep secrets out of etcd entirely with an **external provider** (Vault, cloud KMS) via a Secrets Store CSI driver, and constrain who can create pods with RBAC.

## When to use

* Clusters where etcd access or backups sit outside process and access controls.
* Compliance requirements for encryption of data at rest.
* A first step before migrating secrets to an external store.