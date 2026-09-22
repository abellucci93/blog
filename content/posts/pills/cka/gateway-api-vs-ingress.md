---
date: '2026-09-29T09:00:00Z'
title: 'Gateway API vs Ingress: What Is Changing'
category: ['cka']
---

## Problem

Two teams each manage a web Service behind the same Ingress, but one Ingress object has a **single owner**: every rule change is an edit conflict. TLS, traffic splitting, and CORS are controller-specific annotations that NGINX and Traefik spell differently, and the API server never validates them.

## Context

**Ingress** only matches HTTP by host or path; everything else is expressed as annotations, so the same manifest is not portable across controllers. **Gateway API** is the official project that replaces this by splitting routing into three objects, each owned by a different persona:

* **Infrastructure provider** — `GatewayClass` names the controller (NGINX, Envoy, Kong, ...).
* **Cluster operator** — `Gateway` instantiates that class with listeners and TLS.
* **Application developer** — `HTTPRoute` declares matching and backends, attaching via `parentRefs`.

## Solution

Routing rules move into the `HTTPRoute`, whose declarative `matches` and `backendRefs` replace annotation spills:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: example-httproute
spec:
  parentRefs:
  - name: example-gateway
  hostnames:
  - www.example.com
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /login
    backendRefs:
    - name: example-svc
      port: 8080
```

TLS moves into the Gateway listener (`mode: Terminate`, `certificateRefs: tls-secret`); a canary is two `backendRefs` with `weight: 80` and `weight: 20`; CORS becomes a `ResponseHeaderModifier` filter. All of it is portable across implementations.

**Verify the Gateway became programmed:**

```
kubectl get gateway example-gateway
```

Confirm the listener reports a programmed condition; controllers with Gateway API support include EKS, GKE, Contour, Envoy, HAProxy, Istio, Kong, Kuma, and NGINX.

## When to use

* Multi-tenant clusters where several teams route independently.
* Any protocol beyond HTTP, such as TCP or gRPC routing.
* New clusters that do not need to preserve existing Ingress manifests.
* Caveat: the cluster must run a Gateway API controller — it is not installed by default.