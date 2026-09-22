---
date: '2026-10-17T19:00:00Z'
title: 'Writing Custom Falco Rules'
category: ['cks']
---

## Problem

Falco's default rules only fire on generic behavior — a shell in a container, a read of `/etc/shadow`. None of them know that "this specific webapp image must only read `/opt/app`." Your application-specific anomalies stay invisible, and editing `/etc/falco/falco_rules.yaml` directly gets your changes wiped on the next package update.

## Context

Falco watches syscalls and fires alerts from a set of **rules**. All rule files are listed under `rules_file` in `/etc/falco/falco.yaml`; the built-ins in `/etc/falco/falco_rules.yaml` are always first, and a rule defined in a **later** file overrides an earlier one. Custom rules belong in `/etc/falco/falco_rules.local.yaml`, which package updates leave alone. Every rule has five mandatory keys: `rule` (unique name), `desc`, `condition` (filter expression), `output` (alert text with `%field` placeholders), and `priority` (debug to emergency).

## Solution

Write your rule to the local file, either overriding a built-in by reusing its name or adding a new one:

```yaml
- rule: Anomalous read in kodekloud/webapp pod
  desc: Detect suspicious file reads in a custom webapp container.
  condition: >
    open_read and container
    and container.image.repository == "kodekloud/simple-webapp"
    and fd.directory != "/opt/app"
  output: >
    A file was opened and read outside the /opt/app directory (user=%user.name
    container_id=%container.id image=%container.image.repository)
  priority: CRITICAL
```

Conditions stay readable by composing **macros** and **lists**. A macro is a named condition — `container.id != host` — and a list holds values, so `linux_shells: [bash, zsh, ksh, sh]` replaces five comparisons in one condition. Applying changes needs no full service restart: Falco hot-reloads on SIGHUP.

**Verify it directly** — reload the engine and confirm the config pick-up:

```
kill -1 $(cat /var/run/falco.pid) && journalctl -u falco -n 20
```

The log lines from the restarted engine confirm which configuration file and rules are in effect.

## When to use

* Application-specific detection the community rules cannot express.
* Overriding a rule's severity or output without touching the shipped file.
* Environments where a service restart is disruptive — SIGHUP is enough.