---
date: '2026-09-24T19:00:00Z'
title: 'Anatomy of sudoers: Privilege Escalation Done Right'
category: ['linux']
---

## Problem

You disabled direct root access via SSH — but now routine administrative work grinds to a halt: `apt install nginx` dies with a permission error because the `dpkg` lock is owned by root. The node still needs administrator tasks performed by real users, with accountability, and without handing anyone the root password or a root shell.

## Context

`sudo` is the mechanism that bridges this: a **trusted user** runs a command as another user (typically root) by entering their own password, and the action is recorded for an audit trail. Only users explicitly listed in `/etc/sudoers` can use sudo at all, so there is no shared root login to leak. The remaining hard part is granting elevation — and granting it narrowly rather than as a blanket root-equivalent.

## Solution

The policy lives in `/etc/sudoers`, edited only with `visudo`:

```
cat /etc/sudoers
root    ALL=(ALL:ALL) ALL
%admin  ALL=(ALL) ALL
%sudo   ALL=(ALL:ALL) ALL
mark    ALL=(ALL:ALL) ALL
sarah   localhost=/usr/bin/shutdown -r now
```

Each entry has four fields:

* **User or group** — who receives the privilege; groups are prefixed with `%`.
* **Host** — typically `ALL`, or `localhost` to confine the rule to one machine.
* **Run-as** — the part in parentheses: which users the command may run as; `(ALL:ALL)` means any user and any group.
* **Command** — what may run: `ALL` permits anything, or a single path such as Sarah's `shutdown -r now`.

A narrow entry enables only the task that matters; a broad `ALL` entry is root by another name. The command runs inside the user's own session environment rather than dropping the user into a root shell.

**Verify it directly** — after any edit, confirm the file still parses:

```
visudo -c
/etc/sudoers parsed OK
```

## When to use

* Replacing shared root logins on any Linux node.
* Granting an operator exactly one command (such as `shutdown -r now`) instead of blanket root.
* Auditing who can escalate with `sudo -l` before trusting a node.