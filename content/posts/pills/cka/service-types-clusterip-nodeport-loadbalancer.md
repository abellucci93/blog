---
date: '2026-09-27T14:00:00Z'
title: 'ClusterIP vs NodePort vs LoadBalancer: Service Types Compared'
category: ['cka']
---

## Problem

Your front-end pod calls a back-end pod whose IP changes whenever it restarts, and users can only reach the app by SSHing into a node. Pods on the internal network (like `10.244.0.2`) are unreachable from a laptop on `192.168.1.10`. You need one stable endpoint that survives pod churn and optionally faces the internet.

## Context

A **Service** groups pods by label selector and gives them a fixed entrypoint. Three types cover internal and external exposure:

* **ClusterIP** — a virtual IP inside the cluster, reachable only from other pods. The **default** type.
* **NodePort** — opens an external port (`30000`-`32767`) on every node and forwards to the ClusterIP.
* **LoadBalancer** — delegates to the cloud provider's load balancer and gives one public URL; on bare metal it behaves like NodePort.

A NodePort has three ports: `targetPort` is the pod's real port (defaults to `port` if omitted), `port` is the service's ClusterIP port, and `nodePort` is the external node port (auto-assigned within range if omitted).

## Solution

Expose the app externally with a NodePort Service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  type: NodePort
  ports:
    - targetPort: 80
      port: 80
      nodePort: 30008
  selector:
    app: myapp
```

For pod-to-pod traffic, use ClusterIP and call the service by its DNS name:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: back-end
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: myapp
```

Create it and check the mapping landed:

```
kubectl create -f service-definition.yml
kubectl get services
# myapp-service  NodePort  10.106.127.123  <none>  80:30008/TCP
```

Verify an actual request reaches the pod — the endpoint exists only if the selector matched:

```
kubectl get endpoints myapp-service
curl http://192.168.1.2:30008
```

The service load-balances across all pods the selector matches, and every node maps the same `nodePort`, so the curl works through any node IP.

## When to use

* **ClusterIP** — front-end to back-end, back-end to database tiers, anything internal.
* **NodePort** — quick external access, load testing, or on-prem clusters without a cloud load balancer.
* **LoadBalancer** — production internet exposure on GCP, AWS, or Azure.