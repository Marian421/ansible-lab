# Module 5: Terraform with libvirt Provider

> **SUPERSEDED — 2026-09-05. Kept for reference; do not work through this module.**
>
> The Infrastructure-as-Code concepts here are sound, but the `dmacvicar/libvirt` provider
> appears in essentially no job postings, and the lab VMs it would manage already exist.
> Terraform is still on the path — against **Azure** instead, where the same concepts produce a
> recognisable portfolio artefact and overlap directly with the AZ-104 exam.
>
> The lab VMs are more valuable hosting a real **k3s** cluster than being re-declared in HCL.
> See `CONTEXT.md` for the revised module plan.

## Scenario

You've been managing VMs manually with virt-manager. Your colleague says:

> "What happens when we need to rebuild storage01? You're going to click through virt-manager again? Define the VMs in code."

---

## What You're Learning

Terraform is Infrastructure as Code (IaC). Instead of clicking through a UI to create VMs, you describe them in files and Terraform creates them.

You'll use the **libvirt provider** to manage your lab VMs on KVM.

---

## Tasks

### Task 1: Install Terraform

```bash
sudo apt install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

Or use Ansible to install it (create a `terraform` role).

### Task 2: Create a Terraform project structure

```
terraform/
├── main.tf          # Provider and main resources
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── versions.tf      # Provider versions
└── templates/
    └── cloud-init.cfg  # VM initialization
```

### Task 3: Configure the libvirt provider

```hcl
# versions.tf
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}
```

### Task 4: Define a base image

Download a Debian cloud image and use it as a base:

```hcl
resource "libvirt_volume" "debian_base" {
  name   = "debian-base.qcow2"
  pool   = "default"
  source = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  format = "qcow2"
}
```

### Task 5: Define a VM

Create one of your lab VMs (start with a test VM, not your existing ones):

```hcl
resource "libvirt_volume" "test_vm_disk" {
  name           = "test-vm.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.debian_base.id
  size           = 20 * 1024 * 1024 * 1024  # 20GB
}

resource "libvirt_domain" "test_vm" {
  name   = "test-vm"
  memory = 2048
  vcpu   = 2

  network_interface {
    network_name = "default"
  }

  disk {
    volume_id = libvirt_volume.test_vm_disk.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
```

### Task 6: Initialize and apply

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

### Task 7: Verify

```bash
virsh list --all
# Should show test-vm

ssh root@test-vm-ip "hostname"
# Should return test-vm
```

### Task 8: Destroy

```bash
terraform destroy
```

---

## Important: Do NOT destroy your existing VMs

Start with a test VM. Your lab VMs (bastion, web01, storage01, monitor01) have data and configuration you want to keep. Don't define them in Terraform yet.

The goal is to learn Terraform, not to rebuild your lab.

---

## What You're Learning

- Infrastructure as Code concepts
- Terraform workflow: init → plan → apply → destroy
- Declarative vs imperative infrastructure
- State management (terraform.tfstate)
- Provider ecosystem (libvirt for local VMs)

## Verification

1. `terraform init` succeeds
2. `terraform plan` shows what will be created
3. `terraform apply` creates a running VM
4. You can SSH into the VM
5. `terraform destroy` cleans up everything

## Deliverables

When you're done, show me:
1. Your Terraform project structure
2. Output of `terraform plan`
3. Output of `terraform apply`
4. Proof the VM is running (virsh list, SSH test)
