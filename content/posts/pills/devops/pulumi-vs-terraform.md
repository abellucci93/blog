---
date: '2026-09-28T14:00:00Z'
title: 'Pulumi vs Terraform: Choosing an IaC Tool'
category: ['devops']
---

## Problem

Your Proxmox estate is described in HCL, but now you need to clone a template, compute an IP per VM, loop over three nodes with different parameters, and react to an API response. HCL turns into a tangle of `locals` and functions, and the rest of the team writes TypeScript or Python, not HCL.

## Context

**Terraform** and **Pulumi** are both **Infrastructure-as-Code** tools: declare the target state, the tool diffs it against the real state, and applies the change. The difference is the language. Terraform uses its own DSL, **HCL**, with a plugin ecosystem of providers. Pulumi uses a general-purpose language (Python, TypeScript, Go) with SDKs that wrap many of the same providers, plus its own state backend. Providers like Proxmox exist for both.

## Solution

Provisioning a VM from a Cloud-Init template — Pulumi TypeScript:

```typescript
import * as proxmox from "@muhlba91/pulumi-proxmoxve";

const vm = new proxmox.vm.VirtualMachine("ubuntu-cloud-vm", {
  nodeName: "pve",
  vmId: 9010,
  name: "ubuntu-cloud-vm",
  clone: { vmId: 9000, full: true, targetStorage: "local-lvm" },
  memory: { dedicated: 2048 },
  initialization: {
    userAccount: { username: "ubuntu", keys: ["ssh-rsa AAAA..."] },
    ipConfigs: [{ ipv4: { address: "dhcp" } }],
  },
});

export const vmName = vm.name;
```

The same intent in Terraform HCL, where loops and conditionals live in the expression language:

```hcl
resource "proxmox_virtual_environment_vm" "vm" {
  name      = "ubuntu-cloud-vm"
  node_name = "pve"
  clone {
    vm_id = 9000
    full  = true
  }
  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
}
```

Both deploy with preview-then-apply against the Proxmox API:

```
export PROXMOX_VE_ENDPOINT=https://proxmox:8006/api2/json
export PROXMOX_VE_TOKEN_ID=root@pam!pulumi
pulumi up
```

**Verify it directly** — the applied stack exposes its outputs:

```
pulumi stack output vmName
```

## When to use

* **Terraform** — teams standardizing on HCL who want the largest provider ecosystem and long-matured state locking.
* **Pulumi** — teams who already write Python, TypeScript, or Go and want real control flow inside IaC.
* Either — when the deciding factor is which language your team already lives in.