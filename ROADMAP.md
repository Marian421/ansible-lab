# Learning Roadmap

The plan of record for this lab: what gets built, in what order, and what each step has to
produce before it counts as done.

`CONTEXT.md` tracks **where things stand right now**. This file tracks **where they are going**.

---

## How to use this file

Every task has an ID of the form `<module>.<task>` — `7.3`, `8.5`, and so on. A working session
starts by naming one:

> "Read `ROADMAP.md`, let's do 7.3."

Modules get a detailed `MODULE-N.md` written just before they start, not months in advance —
the tooling moves and stale instructions are worse than none. The task lists below are stable;
the step-by-step detail arrives with the module.

Hour estimates assume ~10h/week. They are estimates, and the failure mode to avoid is skipping
verification to stay on schedule. Dates slip; deliverables do not.

---

## Modules

| # | Module | Focus | Hours | Status |
|---|--------|-------|-------|--------|
| 1 | `ansible.cfg` + `ansible-lint` | Project hygiene | — | completed |
| 2 | Grafana dashboards | Visualisation | — | completed |
| 3 | Alertmanager | Alert routing | — | completed |
| 4 | Centralized logging (Loki + Alloy) | Log pipeline | — | completed |
| 5 | ~~Terraform (libvirt provider)~~ | — | — | **superseded** |
| 6 | Docker fundamentals | Images, layers, multi-stage | 20 | **current** |
| 7 | Kubernetes on k3s | Orchestration | 60 | next |
| 8 | Terraform on Azure | IaC against a public cloud | 50 | not started |
| 9 | AZ-104 | Azure administration, certified | 60 | not started |
| 10 | CI/CD, Molecule, secrets, capstone | Pipeline + testing | 40 | not started |

Target: Modules 6–10 across roughly 24 weeks from September 2026.

---

## Module 6 — Docker fundamentals

**Detail:** [`MODULE-6.md`](MODULE-6.md) · **Where the work lands:**
`learn-cicd-typescript-starter`, `complex-sportiv`

Container images are the unit of deployment for everything after this point. Module 7 cannot
start without an image worth deploying, and Module 8 cannot push one to a registry that does not
exist yet.

| ID | Task | h |
|----|------|---|
| 6.1 | Baseline: build, time and measure the existing Dockerfile | 1 |
| 6.2 | Layer caching — reorder so `npm ci` survives a source change | 2 |
| 6.3 | `.dockerignore`, and why it is a security control | 1 |
| 6.4 | `COPY` vs `ADD` | 1 |
| 6.5 | Multi-stage build | 3 |
| 6.6 | Non-root user | 1 |
| 6.7 | `HEALTHCHECK` against the readiness endpoint | 1 |
| 6.8 | Measure the win — before/after table | 1 |
| 6.9 | Named volumes vs bind mounts | 2 |
| 6.10 | `trivy` scan, baseline vs optimised | 1 |
| 6.11 | Containerise `complex-sportiv` from scratch + Compose with a health-gated database | 6 |

**Verification:** rebuild after a source change reuses the dependency layer · optimised image
materially smaller, with numbers written down · `docker run --rm <image> whoami` is not `root` ·
`docker compose ps` shows API and database both healthy.

---

## Module 7 — Kubernetes on k3s

**Detail:** [`MODULE-7.md`](MODULE-7.md) · **Where the work lands:** this repo
(`roles/k3s_server`, `roles/k3s_agent`, `k8s/`)

The largest single module, and the only one starting from zero. Everything before it converged
state **once, when told**; Kubernetes converges **continuously, on its own**. That difference is
the whole module.

### Topology

```
web01      k3s server (control plane + workload)
storage01  k3s agent (workload + NFS server for PVCs)
monitor01  OUTSIDE the cluster — Prometheus / Alertmanager / Grafana / Loki
bastion    unchanged — SSH entry point
```

`monitor01` stays out on purpose. Monitoring that lives inside the cluster it monitors goes blind
exactly when it is needed. It is also the only VM without the memory headroom to spare.

| ID | Task | h |
|----|------|---|
| 7.1 | Concepts, no cluster: the reconciliation loop, pod / deployment / service / ingress, why declarative | 8 |
| 7.2 | Install single-node k3s on `web01` by hand, then dissect what it did — systemd unit, containerd, kubeconfig, data directory | 6 |
| 7.3 | Ansible roles `k3s_server` + `k3s_agent`; join `storage01`; extend the `firewall` role for 6443/tcp, 8472/udp, 10250/tcp — source-restricted like every other rule | 12 |
| 7.4 | Deploy the Module 6 image: Deployment + Service; scale it; watch a rolling update | 8 |
| 7.5 | ConfigMap + Secret; the app reads its configuration from the environment | 5 |
| 7.6 | Ingress and hostname routing; reach the app from the laptop | 6 |
| 7.7 | PersistentVolumeClaim backed by the existing NFS server on `storage01` | 8 |
| 7.8 | Wire into the **existing** stack on `monitor01` — kube-state-metrics, cAdvisor, pod logs into Loki. No second Prometheus | 8 |
| 7.9 | Failure drills: kill a pod, drain a node, break a readiness probe, fill a volume | 5 |
| 7.10 | Document: README section, architecture diagram, journal entry | 4 |

**Verification:** `kubectl get nodes` shows 2 `Ready` · a full teardown and re-run of the
playbook rebuilds the cluster unattended · the app is reachable through Ingress · pod metrics
appear in the Grafana that already existed · `ansible-lint` still 5/5.

---

## Module 8 — Terraform on Azure

**Where the work lands:** a new repository, `azure-terraform-lab`, created at task 8.1

Same architecture as this lab, declared in HCL against a public cloud instead of Ansible against
KVM. Building the *same* thing twice with different tools is what makes the comparison mean
something.

| ID | Task | h |
|----|------|---|
| 8.1 | Azure account; **budget alert and spending limit configured before the first resource exists**; create the repo | 2 |
| 8.2 | `init` / `plan` / `apply` / `destroy` on a single resource group | 6 |
| 8.3 | State: local vs remote, backend in Azure Storage, locking | 6 |
| 8.4 | Variables, outputs, `tfvars`; nothing secret in git | 5 |
| 8.5 | VNet + subnets + NSGs mirroring the UFW ruleset + a Linux VM + a jump host restricted to one source address | 8 |
| 8.6 | Azure Files share mounted on the VM — the NFS equivalent | 5 |
| 8.7 | Container Registry + Container Apps running the Module 6 image | 8 |
| 8.8 | Managed PostgreSQL Flexible Server, cheapest SKU, destroyed in the same session | 5 |
| 8.9 | Refactor into a reusable Terraform module | 6 |
| 8.10 | Destroy / re-apply drill proving zero drift, plus a cost report | 4 |
| 8.11 | Repository README and architecture diagram | 4 |

**Cost discipline is part of the module, not a footnote.** Azure Bastion is billed hourly and is
deliberately *not* used — a jump VM with an NSG restricted to one source address is both cheaper
and closer to the on-prem design. `terraform destroy` runs at the end of every session.

**Verification:** a second `terraform plan` immediately after `apply` reports no changes ·
`terraform destroy` leaves no billable resource behind · the Azure portal cost view reads
approximately zero between sessions.

---

## Module 9 — AZ-104

**Where the work lands:** notes in `azure-terraform-lab`, and the certification itself

Module 8 teaches the resource model by building things. This module covers what Terraform never
shows: the portal, the CLI, identity, governance, backup, and the operational tooling.

| ID | Task | h |
|----|------|---|
| 9.1 | **Book the exam.** A date roughly eight weeks out | 1 |
| 9.2 | Identity and governance — Entra ID, RBAC, custom roles, Azure Policy, management groups | 10 |
| 9.3 | Storage — account types, redundancy tiers, Azure Files, SAS, lifecycle management | 9 |
| 9.4 | Compute — VM sizing, availability sets and zones, scale sets, App Service, backup | 10 |
| 9.5 | Networking — peering, NSG vs ASG, user-defined routes, Load Balancer vs Application Gateway, private endpoints, DNS | 12 |
| 9.6 | Monitoring — Azure Monitor, Log Analytics and KQL, alerts and action groups, Azure Backup | 10 |
| 9.7 | Practice assessments until scoring ≥85% twice | 6 |
| 9.8 | Sit the exam | 2 |

Read the objective weightings from the official study guide when the module starts — Microsoft
revises them, and studying to a remembered breakdown is how people fail on a domain they skipped.

Task 9.1 comes first for a reason. An exam with no booked date does not get sat.

---

## Module 10 — CI/CD, Molecule, secrets, capstone

**Where the work lands:** this repo, and `azure-terraform-lab`

Everything up to here was built by hand and verified by eye. This module makes the verification
automatic.

| ID | Task | h |
|----|------|---|
| 10.1 | Move this repo to a branch + pull request workflow | 3 |
| 10.2 | GitHub Actions running `ansible-lint` and `--syntax-check` on every PR | 6 |
| 10.3 | Molecule: converge + idempotence tests on 2–3 roles | 12 |
| 10.4 | Secrets: Ansible Vault, SOPS, Azure Key Vault | 8 |
| 10.5 | CD: build the image, push to GHCR, deploy to k3s | 8 |
| 10.6 | Capstone README tying the on-prem and cloud builds together | 3 |

**Verification:** CI green on a pull request · Molecule converge and idempotence both pass ·
no plaintext secret anywhere in git history.

---

## How to get hands-on practice

Reading about infrastructure does not transfer. Each of these is a place to actually run things.

**1. These four VMs.** Free, already built, and they can be broken and rebuilt without
consequence — which is the entire point of owning them. Modules 6, 7 and 10 need nothing else.
Breaking the cluster on purpose in task 7.9 teaches more than any amount of reading about
self-healing.

**2. The Microsoft Learn sandbox.** A free, temporary Azure subscription that lasts for the
duration of a Learn module, with no credit card and no possibility of a bill. This is where the
expensive AZ-104 services get practised — the ones that must never be left running on a personal
subscription.

**3. A personal Azure subscription, with a budget alert set on day one.** Needed for Module 8,
because Terraform state has to point at something real. The safety mechanism is Terraform itself:
teardown is a single command, so "I forgot it was running" stops being the default outcome.
Nothing survives the end of a session.

**4. Microsoft Learn practice assessments.** The free official AZ-104 practice test. Task 9.7
uses it as a gate, not as revision — score first, then study what the score exposed.

**5. Map every cloud service onto something already built here.** This is the highest-value
technique in the whole roadmap, because it converts abstract Azure concepts into things already
understood:

| On-prem, already built | Azure equivalent |
|------------------------|------------------|
| UFW default-deny, source-restricted | Network Security Groups |
| `bastion` + SSH `ProxyJump` | Jump host in its own subnet |
| NFSv4 exports from `storage01` | Azure Files |
| `identity` role — users, groups, fixed UIDs | Entra ID + RBAC |
| Prometheus + Loki + Grafana | Azure Monitor + Log Analytics (KQL) |
| Ansible roles converging state | Terraform / ARM declaring it |
| `promtool check rules` in a `validate:` hook | `terraform validate` / `plan` |

A service met for the first time is memorised. A service recognised as "the managed version of
the thing I already run" is understood.

---

## Design decisions

**k3s rather than kubeadm or minikube.** k3s is a conformant Kubernetes distribution in a single
binary, light enough for 2 GB VMs, and it installs as an ordinary systemd service — which makes
it automatable with the Ansible skills already in this repo rather than a parallel toolchain.
`minikube` is rejected for the opposite reason: a single-node VM-in-a-VM teaches nothing about
node joining, scheduling across hosts, or network fabric between machines.

**Two nodes, not three.** Measured on 2026-09-06: the host has 14 GiB of RAM with under 1 GiB
free, and `monitor01` already holds 1.5 GB of a 2 GB ceiling running Prometheus, Alertmanager,
Grafana and Loki. There is no memory to give it a k3s server as well. Keeping the observability
plane outside the cluster is the right architecture regardless — the monitoring must not die with
the thing it monitors.

**Azure rather than AWS.** AZ-104 sits within budget, the existing .NET and Angular work overlaps
with the Microsoft ecosystem, and Azure has a strong presence in the Romanian enterprise market.
AWS is not a worse cloud; picking one and going deep beats sampling two.

**A separate repository for Terraform.** This repo is an on-prem KVM lab configured with Ansible.
Adding public-cloud HCL to it would make both halves harder to read. Two coherent repositories
beat one incoherent one, and the comparison between them is more legible when they are distinct
artefacts.

**Module 5 was dropped.** It targeted the `dmacvicar/libvirt` Terraform provider — sound IaC
concepts, but aimed at a provider almost nobody uses, to re-declare VMs that already exist.
Terraform survived the cut; the target changed to Azure, and the VMs went to Kubernetes instead.
`MODULE-5.md` is kept with a banner rather than deleted, because the reasoning is worth more than
the file.
