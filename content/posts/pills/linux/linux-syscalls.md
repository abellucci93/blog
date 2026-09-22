---
date: '2026-09-28T09:00:00Z'
title: 'Understanding Linux Syscalls: The Kernel Interface'
category: ['linux']
---

## Problem

A container or daemon misbehaves and the failure is a black box: a hung process, a file that appears out of nowhere, a connection that dies. Programs cannot touch hardware, storage, or the network directly — everything flows through the kernel. Without seeing that traffic you cannot tell what the process is actually doing or why it is failing.

## Context

The kernel mediates everything between hardware and applications. It runs in its own protected memory region, **kernel space**, while user programs (C, Java, Python) run in **user space**. When an application needs a kernel service — opening a file, creating a socket, executing a program — it issues a **system call** such as `open`, `close`, `read`, or `execve`. Even creating an empty file with `touch` triggers many syscalls: `execve` to run the binary, then `openat`, `utimensat`, and `close`.

The syscalls a process makes are its complete record of interaction with the system, which is exactly the evidence you want when diagnosing it.

## Solution

Trace every syscall a command makes by prefixing it with `strace`:

```
strace touch /tmp/error.log
```

The output opens with the `execve` call that launched the program:

```
execve("/usr/bin/touch", ["touch", "/tmp/error.log"], 0x7ffce8f874f8 /* 23 vars */) = 0
```

Read it left to right: the absolute path to the executable, the array of arguments, and the inherited environment. For a process that is already running, attach by PID:

```
pidof etcd
strace -p 3596
```

Press `Ctrl+C` to detach once you have what you need. To get a summary of how often each syscall fires instead of the full stream, add `-c`:

```
strace -c touch /tmp/error.log
```

**Verify it directly** — the `execve` line reports `/* 23 vars */`; confirm the count on your own shell:

```
env | wc -l
```

The output should print `23`.

## When to use

* Explaining what a process is doing when its logs do not tell you.
* Finding unexpected syscalls from a container or daemon during an incident.
* Measuring syscall volume with `strace -c` before tuning a hot path.
* Confirming which kernel services a compromised process is reaching.