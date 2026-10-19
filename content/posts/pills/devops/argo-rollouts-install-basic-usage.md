---
date: '2026-10-19T18:00:00Z'
title: 'Argo Rollouts: Install and Basic Usage with Argo CD'
category: ['devops', 'argocd', 'argo-rollouts']
---

## Problem

You update the image of a Kubernetes `Deployment` and the default strategy does the rest: with `maxSurge` and `maxUnavailable` both at 25%, the new ReplicaSet replaces the old pods one by one across every replica. That is the right default for stateless services, but it means a bad image is never caught before it reaches production: the first pods of the new version start taking traffic immediately, and if the health checks pass but the application is actually broken, your rollback is not a rollback — it is a second full rollout, with the same blast radius as the release that just failed.

Blue-green and canary solve exactly this: run the new version alongside the old one, inspect it, and only then switch the traffic. But they are not strategies you can express in a native `Deployment` — the closest Kubernetes gets is `maxUnavailable: 0`, which still shares one Service selector and gives you no stable "preview" endpoint and no promotion gate. You need a controller that owns the ReplicaSets, the traffic switch, and the pause between them.

The second problem is that this is not a greenfield cluster. Your application already lives in a Helm chart in Git, deployed and auto-synced by Argo CD with `selfHeal: true`, and you do not want to rewrite the chart from scratch just to change the deployment strategy.

## Context

[Argo Rollouts](https://argo-rollouts.readthedocs.io/) is a Kubernetes controller that introduces two new CRDs: `Rollout` (a drop-in replacement for `Deployment` that adds blue-green and canary strategies) and `AnalysisTemplate` (metric-driven promotion gates). It does not replace your workloads: a `Rollout` creates and manages its own ReplicaSets exactly like a Deployment does, so the migration path is additive — you can keep your existing pod template and put a `Rollout` in front of it.

The controller also does something that matters when Argo CD is in the picture: it **mutates live objects at runtime**. To route traffic it injects a `rollouts-pod-template-hash` label into the `selector` of the Services it manages, and during promotion it flips which ReplicaSet those selectors point to. When autoscaling is involved, the replica count of the underlying workload changes too. All of this is legitimate runtime state for the controller — and all of it looks like drift to Argo CD, which will mark the application `OutOfSync` and, with self-heal enabled, try to "fix" the cluster by undoing what the controller just did.

This pill walks through the full path: install the controller, deploy a first BlueGreen rollout from scratch, retrofit an existing Helm chart with the `workloadRef` pattern, and teach Argo CD to stop fighting the controller.

## Solution

### Install

Argo Rollouts ships as a Helm chart in the official `argo-helm` repository — a plain `helm install` into its own namespace is all it takes:

```sh
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argo-rollouts argo/argo-rollouts \
  --namespace argo-rollouts --create-namespace

kubectl get deploy -n argo-rollouts
```

The last command should show the controller pod in `Running` state; the chart also installs the CRDs (`Rollout`, `AnalysisTemplate`, `AnalysisRun`). Optionally install the `kubectl` plugin — every verification command in this post uses it:

```sh
curl -L -o /usr/local/bin/kubectl-argo-rollouts \
  https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-darwin-arm64
chmod +x /usr/local/bin/kubectl-argo-rollouts
```

Full install options (high-availability controller, metrics, dashboard) are covered in the [official installation docs](https://argo-rollouts.readthedocs.io/en/stable/installation/).

### Blue-green from scratch

A `Rollout` looks almost identical to a `Deployment` — same pod template, same selector — with the strategy section as the only real difference. Blue-green additionally requires **two** Services: one pointing at the active (production) ReplicaSet, one pointing at the preview (next version) ReplicaSet:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: rollout-bluegreen
spec:
  replicas: 2
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: rollout-bluegreen
  template:
    metadata:
      labels:
        app: rollout-bluegreen
    spec:
      containers:
      - name: rollouts-demo
        image: argoproj/rollouts-demo:blue
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
  strategy:
    blueGreen:
      activeService: rollout-bluegreen-active
      previewService: rollout-bluegreen-preview
      autoPromotionEnabled: false
      previewReplicaCount: 1
      scaleDownDelaySeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: rollout-bluegreen-active
spec:
  selector:
    app: rollout-bluegreen
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: rollout-bluegreen-preview
spec:
  selector:
    app: rollout-bluegreen
  ports:
  - port: 80
    targetPort: 8080
```

Both Services declare the same static selector (`app: rollout-bluegreen`), which looks like they would send traffic to the same pods. They do not: the Rollouts controller injects a `rollouts-pod-template-hash: <hash>` entry into each Service's `selector` at runtime, matching the hash of the ReplicaSet it should target. The active Service gets the hash of the current production ReplicaSet, the preview Service the hash of the new one. The selector in Git is only the "logical" base; the controller owns the rest.

When you change `.spec.template` (a new image tag, for example), the following sequence runs:

1. The controller creates a new ReplicaSet (revision N+1) with size 0 — nothing is running yet.
2. The **preview** Service is updated immediately to point at the new ReplicaSet, while the active Service stays on revision N.
3. The new ReplicaSet is scaled up to `previewReplicaCount` (1 here, instead of the full `spec.replicas`).
4. If a `prePromotionAnalysis` is defined, it runs against the preview pods now.
5. With `autoPromotionEnabled: false` the rollout **pauses**. This is your gate: the new version is reachable only via the preview Service, production traffic is untouched.
6. You inspect it, and if it looks good you promote: `kubectl argo rollouts promote rollout-bluegreen`. The active Service flips to the new ReplicaSet; with auto-promotion enabled this step happens by itself.
7. `postPromotionAnalysis` runs, and after `scaleDownDelaySeconds` the old ReplicaSet is scaled to zero.

A detail worth knowing: the preview Service is always guaranteed to point to the *latest* revision. If a second update lands before the first is promoted, the preview Service jumps to the newest ReplicaSet immediately — the old preview is abandoned, the active Service never notices.

Verify the state of the world at any point with:

```sh
kubectl argo rollouts get rollout rollout-bluegreen
kubectl argo rollouts watch rollout-bluegreen
kubectl argo rollouts promote rollout-bluegreen
```

### Integrating with an existing Helm chart

Rewriting a battle-tested chart's `deployment.yaml` into a `rollout.yaml` means duplicating every probe, resource limit, and volume — the template drifts twice from now on. Argo Rollouts offers a lazier path: keep the `Deployment` exactly as it is, and let the `Rollout` *reference* it through `workloadRef`. The controller reads the pod template from the Deployment and takes over ReplicaSet management and traffic routing; the Deployment degenerates into a template holder. Here is the shape a real integration takes, on a hypothetical `myapp` chart.

**1. Add a `Rollout` that references the existing `Deployment`:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}

  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}

  workloadRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "myapp.fullname" . }}
    scaleDown: onsuccess

  strategy:
    blueGreen:
      activeService: {{ .Values.service.name | default (include "myapp.fullname" .) }}-active
      previewService: {{ .Values.service.name | default (include "myapp.fullname" .) }}-preview
      autoPromotionEnabled: false
```

`workloadRef` points at the Deployment that was already there; `scaleDown: onsuccess` tells the controller to scale that Deployment down to zero once the Rollout's ReplicaSets are healthy, so you do not end up running both. The pod template, image tag, probes, and resource limits all stay in the original `deployment.yaml` — a single source of truth.

**2. Split the Service into `-active` and `-preview`.** The original `service.yaml` rendered one `Service` named after the release; it becomes the active Service, and a twin is added for the preview. Both keep the same selector — the controller injects the hash, as seen before:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.service.name | default (include "myapp.fullname" .) }}-active
  # ...
spec:
  # ...
  selector:
    {{- include "myapp.selectorLabels" . | nindent 4 }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.service.name | default (include "myapp.fullname" .) }}-preview
  # ...
spec:
  # ...
  selector:
    {{- include "myapp.selectorLabels" . | nindent 4 }}
```

Anything pointing at the old Service name (Ingress backends, HTTPRoutes, mesh configurations) must be updated to reference `myapp-active`.

**3. Retarget the HPA — the gotcha that silently breaks autoscaling.** A `HorizontalPodAutoscaler` scales whatever `scaleTargetRef` names. With the Rollout now owning the replica count, an HPA still targeting the Deployment scales a resource the controller has scaled to zero: nothing happens, and CPU-based autoscaling quietly dies. The fix is one field:

```yaml
spec:
  scaleTargetRef:
    # before
    apiVersion: apps/v1
    kind: Deployment
    # after
    apiVersion: argoproj.io/v1alpha1
    kind: Rollout
    name: {{ include "myapp.fullname" . }}
```

**4. Expose the preview endpoint.** The preview Service is only useful if you can actually reach it. With Gateway API this is one extra route with its own hostname — production traffic keeps flowing through the active Service:

```yaml
- name: web-blue
  parentRefs:
    - name: myapp
      sectionName: web-blue
  hostnames:
    - blue.myapp.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: myapp-preview
          port: 80
```

Now every release is inspectable at `https://blue.myapp.example.com` before promotion, while `https://www.myapp.example.com` stays on the current version.

### Integrating with Argo CD

Here is where the runtime mutations described in the Context come back to bite. With `syncPolicy.automated.selfHeal: true`, Argo CD continuously compares live state against Git and reverts anything that differs. The Rollouts controller keeps rewriting the `selector` of both Services and the replica count of the workload — Argo CD sees three permanently `OutOfSync` resources and, left alone, would strip the injected hash and hand traffic routing back to a controller that expects to own it. The two fight in a loop.

The fix is `ignoreDifferences` on the `Application`, teaching Argo CD to treat exactly those fields as controller-owned:

```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      name: myapp
      jsonPointers:
        - /spec/replicas
    - kind: Service
      name: myapp-active
      jsonPointers:
        - /spec/selector
    - kind: Service
      name: myapp-preview
      jsonPointers:
        - /spec/selector
```

Three entries, three drifts neutralized: the Deployment's replicas (mutated by the Rollout during adoption, and by the HPA when autoscaling is on) and the selector of both Services (mutated by the controller on every rollout). Everything else in the `Service` manifests — ports, type, labels — remains fully Git-synced, so a genuine change to, say, `targetPort` still shows up as a sync diff.

Two practical notes:

* The field name is camelCase: `ignoreDifferences`. A lowercase `ignoredifferences` is not rejected — it is silently ignored, and you are back to debugging a sync loop while your YAML looks correct. Check the rendered `Application` if the drift refuses to go away.
* Listing the Services by name is the surgical option. If you prefer fewer lines and do not care about tracking selector changes at all, the same block without `name` applies to every `Service` in the application — coarser, but shorter.

Finally, the Argo CD UI tells you nothing about rollout state out of scope of the sync: blue/green phases, pauses, and promotions are invisible in the default dashboard. The community [rollout-extension](https://github.com/argoproj-labs/rollout-extension) embeds the Argo Rollouts dashboard into the Argo CD resource view. If you install Argo CD via the official Helm chart it is a few lines of values:

```yaml
server:
  extensions:
    enabled: true
    extensionList:
      - name: rollout-extension
        env:
          - name: EXTENSION_URL
            value: https://github.com/argoproj-labs/rollout-extension/releases/download/v0.3.7/extension.tar
```

Note the version pairing: extension `v0.4.0`+ requires Argo CD v3.5 or later; on older Argo CD stick to the `v0.3.x` line. It is optional, but it turns "the app is OutOfSync, is that normal?" into a single glance at the rollout phase.

## When to use

* An existing Helm/GitOps application you want to move to blue-green without rewriting the chart — the `workloadRef` pattern makes it additive.
* You need a per-release preview endpoint (manual QA, smoke tests, stakeholder review) before production traffic moves.
* Promotion must be a human decision: `autoPromotionEnabled: false` plus `kubectl argo rollouts promote` as the release gate.
* Argo CD manages the app with self-heal — plan the `ignoreDifferences` entries as part of the migration, not as an afterthought when the sync loop starts.
* The app is behind an HPA — remember to retarget `scaleTargetRef` to the `Rollout`, or autoscaling silently stops working.
