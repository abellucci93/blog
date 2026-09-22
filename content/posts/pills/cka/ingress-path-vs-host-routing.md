---
date: '2026-10-12T09:00:00Z'
title: 'Ingress Path-Based vs Host-Based Routing'
category: ['cka']
---

## Problem

Your store adds a second app, but each `LoadBalancer` Service costs a cloud LB and an extra IP; another team serves the same cluster from `www.` and needs different routing. You want one entry point that splits traffic by URL **and** by domain without owning separate proxies.

## Context

An **Ingress** exposes a single IP and routes layer-7 traffic via rules. Each rule has an optional `host` and an `http.paths` list, each path naming a backend Service. Leave `host` out and the rule matches **every domain** (shown as `*` in `kubectl get ingress`). No controller ships by default — deploy NGINX or another first, or the resource does nothing.

Path vs host is a structural choice:

* **Path-based:** one rule, several paths — `/wear` to wear-service, `/watch` to watch-service on the same domain.
* **Host-based:** several rules, each with its own `host` — `myonlinestore.com` to primary, `www.myonlinestore.com` to secondary.

## Solution

Path-based, one rule with multiple paths:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-wear-watch
spec:
  rules:
  - http:
      paths:
      - path: /wear
        pathType: Prefix
        backend:
          service:
            name: wear-service
            port:
              number: 80
      - path: /watch
        pathType: Prefix
        backend:
          service:
            name: watch-service
            port:
              number: 80
```

Host-based, two rules with one path each:

```yaml
spec:
  rules:
  - host: myonlinestore.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: primary-service
            port:
              number: 80
  - host: www.myonlinestore.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secondary-service
            port:
              number: 80
```

**Verify what the controller applied:**

```
kubectl describe ingress ingress-wear-watch
```

## When to use

* Multiple apps on one domain: path-based.
* Different backend per domain, or per-tenant domains: host-based.
* Any time you want one LB instead of per-Service LBs; you still need a NodePort or LoadBalancer once to reach the Ingress controller.
