# Proxmox Homelab Automation

A multi-stage Terraform-based infrastructure-as-code (IaC) repository designed to bootstrap, configure, and orchestrate a modular Proxmox Virtual Environment homelab.

---

## Architecture Overview

The repository is split into sequential, decoupled stages that consume remote state from one another:

```text
 00-bootstrap ──> 01-platform ──> 02-workloads

```

1. **`00-bootstrap/`**: Sets up initial service accounts, roles, access control lists (ACLs), resource pools, and cloud-init snippets for automation.
2. **`01-platform/`**: Deploys software-defined networking (SDN) VNets, downloads base OS images & LXC templates, and builds unified VM templates.
3. **`02-workloads/`**: Provisions concrete LXC containers and Virtual Machines, enforces unique VMID validation ranges, and outputs an Ansible-ready inventory.

---

## Repository Structure

```text
terraform/
├── 00-bootstrap/         # Identity, permissions, pools, and snippets
├── 01-platform/          # SDN, VNets, downloaded images, and VM templates
├── 02-workloads/         # Guest workload orchestration (LXC & VMs)
└── terraform/modules/    # Reusable Terraform modules for LXC and VMs

```

---
