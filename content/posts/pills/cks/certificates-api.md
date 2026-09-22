---
date: '2026-09-21T14:00:00Z'
title: 'The Certificates API: Automating CSR Approval'
category: ['cks']
---

## Problem

A new administrator needs their own certificate and key to access the cluster. Doing this manually means logging into the master and signing with the CA by hand — slow, error-prone, and impossible to scale past a handful of users.

## Context

The **Certificate Authority** (CA) is a private key and root certificate that signs certificates for the entire cluster; anyone who controls it can grant privileges inside Kubernetes, so it is secured on the control plane (in kubeadm, `/etc/kubernetes/pki/ca.crt` and `ca.key`).

To automate signing, Kubernetes provides the **Certificates API**. Instead of manual signing, a user submits a `CertificateSigningRequest` (CSR) object to the API server. The `kube-controller-manager` runs two controllers for this flow:

* **CSR-approving** — marks the request as approved.
* **CSR-signing** — signs it with the cluster CA, configured via `--cluster-signing-cert-file` and `--cluster-signing-key-file`.

## Solution

The user generates a private key and a CSR:

```
openssl genrsa -out jane.key 2048
openssl req -new -key jane.key -subj "/CN=jane" -out jane.csr
```

The administrator base64-encodes that CSR and creates a `CertificateSigningRequest`:

```
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: jane
spec:
  signerName: kubernetes.io/kube-apiserver-client
  groups:
  - system:authenticated
  usages:
  - digital signature
  - key encipherment
  - server auth
  request: <base64-encoded-CSR>
```

**Verify it** — list, approve, and retrieve the signed certificate:

```
kubectl get csr && kubectl certificate approve jane && kubectl get csr jane -o yaml
```

The CSR moves from `Pending` to `Approved`; the signed certificate appears base64-encoded in `status.certificate`, ready to decode and share with the user. Approval and signing happen inside the controller manager, not on a host with shell access to the CA.

## When to use

* Onboarding users or components that need their own client certificates.
* Rotating expiring certificates without touching the CA files directly.
* Reviewing and auditing who requested what before approval.