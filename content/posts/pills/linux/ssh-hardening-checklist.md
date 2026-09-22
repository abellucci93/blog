---
date: '2026-10-09T14:00:00Z'
title: 'SSH Hardening: From Key Auth to Disabling Root Login'
category: ['linux']
---

## Problem

A server that accepts SSH passwords and allows direct root login is a brute-force magnet: any reachable client can try passwords against root, and one weak credential is a foothold. The service cannot simply be closed — it is the only door to remote administration. It must be hardened so the door stays usable but only for the right people.

## Context

SSH authenticates two ways: username/password or a **key pair** — a private key held by the client and the matching public key installed on the server. Passwords are guessable and reusable; keys prove identity cryptographically and cannot be brute-forced. Hardening follows a fixed sequence: get key authentication working first, then turn off passwords and root login — never the reverse, or you lock yourself out.

## Solution

Generate a key pair on the client, then copy the public key to the server:

```
ssh-keygen -t rsa
ssh-copy-id mark@node01
```

The public key lands in `~/.ssh/authorized_keys` on the remote host; the private key stays with you. Only after passwordless login is confirmed, edit `/etc/ssh/sshd_config`:

```
PermitRootLogin no
PasswordAuthentication no
```

Then restart the service:

```
systemctl restart sshd
```

Work from a session you keep open — a misplaced directive is easy to spot while you can still get back in. After the change, a key-only login still connects.

**Verify it directly** — an unauthenticated return should require no password:

```
ssh mark@node01
```

If it asks for a password, key authentication is misconfigured or `PasswordAuthentication no` did not take effect — fall back before closing the session.

## When to use

* Any internet-reachable Linux server.
* Nodes that administrators reach directly with `ssh user@host`.
* Environments where shared accounts or direct root logins are currently in use.
* After creating a new account that should administer remote nodes.