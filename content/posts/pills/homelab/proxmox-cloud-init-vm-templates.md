---
date: '2026-10-06T09:00:00Z'
title: 'Proxmox: Creating VM Templates with Cloud-Init'
category: ['homelab']
---

## Problem

Cloning an existing VM inherits its hostname, SSH keys, users, and network config, so every clone boots as a twin of the original and fights for the same IP. Reconfiguring each one by hand afterwards defeats the point of cloning. You want a reusable base that the hypervisor configures for you at first boot instead.

## Context

**Cloud-Init** is the standard mechanism: at first boot the VM reads a small metadata drive and applies hostname, user, SSH keys, and network settings before the OS finishes starting services. Proxmox turns this into a template workflow — import a prepared cloud image as a VM's disk, attach a Cloud-Init drive, set the parameters, then convert it into a **template** that clones reproduce as fully-configured VMs.

## Solution

Download a cloud-ready Ubuntu image, create an empty VM (no install media) with ID `9000`, then import the image as its main disk:

```
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --boot c --bootdisk scsi0
```

Attach the Cloud-Init drive and request DHCP:

```
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --ipconfig0 ip=dhcp
```

Set the user, SSH key, and hostname — the values each clone will customise:

```
qm set 9000 --ciuser ubuntu
qm set 9000 --sshkey ~/.ssh/id_rsa.pub
qm set 9000 --hostname ubuntu-cloud
```

Convert the VM into a template, then clone and start the first instance:

```
qm template 9000
qm clone 9000 9010 --name ubuntu-test --full
qm start 9010
```

**Verify it directly** — SSH in with the key and confirm Cloud-Init has finished:

```
ssh ubuntu@<vm-ip>
sudo cloud-init status
```

`status: done` means the clone applied its configuration. For failures, read `/var/log/cloud-init-output.log`.

## When to use

* Standing up many VMs in a homelab, each with unique hostname, user, and keys.
* Rebuilding an environment from a known-good image instead of manual installs.
* Reusing one template to give every clone identical baseline settings.