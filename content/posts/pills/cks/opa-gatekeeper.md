---
date: '2026-09-23T19:00:00Z'
title: 'OPA Gatekeeper: Policy as Code for Kubernetes'
category: ['cks']
---

## Problem

A developer applies a pod to the `expensive` namespace without the required `billing` label. The API server admits it: Kubernetes validates resource schemas, not business rules, so the pod runs and the namespace quietly drifts out of compliance. Enforcing a convention like "every pod must carry a label" or "no privileged containers" by review alone fails the moment someone forgets.

## Context

**OPA (Open Policy Agent)** is a policy engine that centralizes authorization decisions in one place. Policies are written in **Rego**, a declarative language, and served over a REST API. Plain OPA is a decision point you query yourself; nothing in Kubernetes calls it automatically.

**Gatekeeper** integrates OPA with Kubernetes as an *admission controller*. It evaluates every object at request time using the **OPA Constraint Framework**, which defines two CRDs:

* **ConstraintTemplate** — names a policy kind, declares the schema for its parameters, and embeds the Rego that computes a `violation`.
* **Constraint** — an instantiation of a template, matched against namespaces, that passes the concrete parameters.

Install Gatekeeper into its own namespace and check the controllers come up:

```
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.14.0/deploy/gatekeeper
kubectl get all -n gatekeeper-system
```

## Solution

Require a `billing` label with a template that compares the pod's labels against a parameter instead of hardcoding it:

```
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: systemrequiredlabels
spec:
  crd:
    spec:
      names:
        kind: SystemRequiredLabel
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package systemrequiredlabels
        violation[{"msg": msg, "details": {"missing_labels": missing}}] {
          provided := {label | input.request.object.metadata.labels[label]}
          required := {label | label == input.parameters.labels[_]}
          missing = required - provided
          count(missing) > 0
          msg = sprintf("you must provide labels: %v", [missing])
        }
```

Apply the template, then bind it to the namespace with a constraint:

```
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: SystemRequiredLabel
metadata:
  name: require-billing-label
spec:
  match:
    namespaces: ["expensive"]
  parameters:
    labels: ["billing"]
```

```
kubectl apply -f requiredlabels-template.yaml
kubectl apply -f require-label-billing.yaml
```

**Verify it directly** — try to create a pod without the label; the admission controller must reject it:

```
kubectl run nginx --image=nginx -n expensive
```

The create fails with `you must provide labels: {"billing"}`. Add the label with `--labels` and the same command succeeds. Want the same rule for another namespace? Add a new constraint with different `parameters` — the Rego stays untouched.

## When to use

* Enforcing label, image, or security conventions that plain Kubernetes cannot express.
* Sharing policies across namespaces or teams as versioned CRDs.
* Replacing manual review gates that drift as the cluster grows.