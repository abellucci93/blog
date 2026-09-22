---
date: '2026-09-21T09:00:00Z'
title: 'Cloud-Init: Automating VM Provisioning from Scratch'
category: ['devops']
---

## Problem

Every new VM starts the same grind: boot an install ISO, click through the wizard, set the hostname, paste an SSH key, configure networking by hand. Repeat for the third machine and it already differs from the first — a fleet of unique snowflakes that cannot be rebuilt.

## Context

**Cloud-Init** is the standard for first-boot automation. In Proxmox you boot a ready-made **cloud image** (for example Ubuntu's `jammy-server-cloudimg`) and attach a special **cloud-init drive**. On first boot the guest reads user data from that drive and applies users, SSH keys, hostname, and network config before anyone ever logs in. The same template then clones into identical, reproducible VMs.

## Solution

Import the cloud image as the VM's disk and attach the cloud-init drive:

```
qm importdisk 9000 /var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
```

Configure what gets applied at first boot:

```
qm set 9000 --ciuser ubuntu
qm set 9000 --sshkey ~/.ssh/id_rsa.pub
qm set 9000 --hostname ubuntu-cloud
qm set 9000 --ipconfig0 ip=dhcp
```

Freeze it as a template, then clone VMs in one step:

```
qm template 9000
qm clone 9000 9010 --name ubuntu-test --full
qm start 9010
```

The clone comes up with the SSH key installed and its hostname and IP already set — no console, no install wizard.

**Verify it directly** — from inside the new VM, confirm Cloud-Init ran cleanly:

```
sudo cloud-init status
```

`status: done` means the config was applied; `status: error` points you at the failing stage in `/var/log/cloud-init-output.log`.

## When to use

* Spinning up VMs in batches that must be configured identically.
* Any VM you want to rebuild from a template instead of reinstalling.
* Pairing with IaC: a template-fed VM is exactly what Pulumi or Terraform clones.
* Homelab or edge machines where keyboard-and-screen provisioning is the bottleneck.