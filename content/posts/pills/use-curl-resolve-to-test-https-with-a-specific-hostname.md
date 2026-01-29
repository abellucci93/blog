---
date: '2026-01-29T19:56:00Z'
title: 'Use curl --resolve to test HTTPS with a specific hostname'
---

## Problem

When debugging HTTPS services behind a reverse proxy, it’s often necessary to verify that the backend server is returning the **correct SSL certificate** for a specific domain.

This becomes tricky when:

* The server responds **only** to a specific hostname (via SNI)
* The environment is local or private
* You cannot (or do not want to) modify DNS or `/etc/hosts`

In these cases, a simple `curl https://<ip>` won’t work, because the TLS handshake depends on the hostname, not the IP address.

## Context

This problem commonly appears in the following setup:

* A **private local network**, not reachable from the internet
* A **reverse proxy** configured with **SSL passthrough**
* A backend service that:

  * Listens on HTTPS only
  * Expects a specific domain name
* No DNS entry exists for that domain
* You don’t want to touch `/etc/hosts` or local DNS configuration

You need a way to send an HTTPS request **to a specific IP** while still presenting the **correct hostname** during the TLS handshake.

## Solution

The trick is to use `curl --resolve`.

```sh
curl -vvv -k --resolve <your.domain.tld>:<your-local-ip> "https://<your.domain.tld>"
```

* `-vvv`
  Enables very verbose output, useful for inspecting:

  * TLS handshake
  * SNI
  * Certificate details
  * Headers and connection flow

* `-k`
  Allows insecure connections (useful for self-signed or internal certificates)

* `--resolve <your.domain.tld>:<your-local-ip>`
  This is the key option. It tells `curl` to bypass DNS and force a specific IP for a given hostname.

  From the official `curl` documentation:

  > “Provide a custom address for a specific host and port pair. Using this, you can make requests to a server without using the DNS resolver.”

  Official docs:
  [https://curl.se/docs/manpage.html#--resolve](https://curl.se/docs/manpage.html#--resolve)

  In practice:

  * The **TCP connection** goes to the local IP
  * The **HTTPS request and SNI** still use the domain name
  * No DNS changes required
  * No `/etc/hosts` modifications

This makes `--resolve` ideal for testing HTTPS behavior in isolated or internal environments.

## When to use

* Debugging SSL certificates behind a reverse proxy
* Verifying SNI-based routing
* Testing HTTPS services in private networks
* Avoiding permanent local DNS changes
