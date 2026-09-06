# Lab Context

This file tracks the current state of the lab and learning progress.
Updated after each learning session so new conversations can resume immediately.

## How to use

At the start of a new conversation, say:
> "Read `CONTEXT.md` and continue from where we left off."

---

## Current State

- **Last updated:** 2026-09-06
- **Lab status:** working
- **Active learning module:** Module 6 - Docker fundamentals (see `MODULE-6.md`)
- **Full plan:** [`ROADMAP.md`](ROADMAP.md) - Docker to AZ-104, task by task

## Lab Topology

| Host | IP | Role | OS |
|------|----|------|----|
| bastion | 192.168.122.10 | SSH jump host | Debian |
| web01 | 192.168.122.20 | Web server / NFS client / Node Exporter | Debian |
| storage01 | 192.168.122.30 | NFS server / Node Exporter | Debian |
| monitor01 | 192.168.122.40 | Prometheus / NFS client / monitoring | Debian |

## Completed Modules

- [x] Phase 1 - Linux fundamentals (filesystem, users, permissions, SSH, systemd, storage)
- [x] Phase 2 - NFS server/client, shared storage, UID/GID consistency
- [x] Phase 3 - Ansible basics (inventory, playbooks, roles, variables, templates, handlers, conditionals, idempotency)
- [x] Phase 4 - Healthcheck (systemd service + timer, Jinja2 template, dedicated user)
- [x] Phase 5 - Monitoring (Node Exporter on all servers, Prometheus on monitor01)
- [x] Phase 6 - Firewall (UFW, default-deny inbound, source-restricted rules)
- [x] Phase 7 - Identity role (users/groups with consistent UIDs across servers)
- [x] Module 1 - ansible.cfg + ansible-lint
- [x] Module 2 - Grafana dashboards
- [x] Module 3 - Alertmanager
- [x] Module 4 - Centralized logging (Loki + Alloy)

## Ansible Roles

| Role | Applied to | Purpose |
|------|-----------|---------|
| healthcheck | all lab servers | Systemd timer + script for health checks |
| identity | all lab servers | Users/groups with consistent UIDs |
| firewall | all lab servers | UFW rules, default-deny, source-restricted |
| nfs_server | storage01 | NFS exports configuration |
| nfs_client | web01, monitor01 | NFS mount points |
| node_exporter | all lab servers | Prometheus metrics exporter |
| prometheus | monitor01 | Metrics collection, inventory-driven targets |
| alertmanager | monitor01 | Alert routing |
| grafana | monitor01 | Dashboards, provisioned data sources |
| loki | monitor01 | Log aggregation backend |
| alloy | web01, storage01 | Journal log shipping to Loki |

## Key Decisions

- **NFSv4** over NFSv3 for better security and performance
- **UFW** over firewalld for simplicity in a Debian lab
- **Dedicated healthcheck user** with nologin shell for least privilege
- **Consistent UIDs/GIDs** across servers for NFS identity matching
- **Bastion outside the lab group** - it's SSH entry point, not a managed server

## Known Issues

All previously listed issues are resolved (2026-09-05):

- ~~Healthcheck role has duplicate files~~ - removed the unused static
  `files/lab-healthcheck.sh`; the Jinja2 template is the single source
- ~~`firewall_bastion_ip` hardcoded in role defaults~~ - moved to `group_vars/lab.yml`
- ~~Inventory hosts use bare names without `ansible_host`~~ - **this was not actually a bug.**
  The SSH client config defines `Host web01` etc. with `ProxyJump bastion`. Setting
  `ansible_host` to a raw IP would stop those blocks from matching and break ProxyJump. The
  bare names are intentional; the requirement is now documented in `README.md` instead.

Also cleaned up: leftover `debug` tasks in the `firewall` and `healthcheck` roles and in
`first-playbook.yml`; boilerplate `vars/main.yml` files; ansible-galaxy placeholder READMEs
replaced with real documentation for all 11 roles.

## Learning Module Plan

[`ROADMAP.md`](ROADMAP.md) is the plan of record - task lists, hour estimates, verification
criteria and the reasoning behind each choice. Only the status lives here.

| # | Module | Status |
|---|--------|--------|
| 1 | ansible.cfg + ansible-lint | completed |
| 2 | Grafana dashboards | completed |
| 3 | Alertmanager | completed |
| 4 | Centralized logging (Loki + Alloy) | completed |
| 5 | ~~Terraform (libvirt provider)~~ | superseded - see `ROADMAP.md` |
| 6 | Docker fundamentals | **current** - `MODULE-6.md` |
| 7 | Kubernetes on k3s | next - `MODULE-7.md` |
| 8 | Terraform on Azure | not started |
| 9 | AZ-104 | not started |
| 10 | CI/CD, Molecule, secrets, capstone | not started |

Tasks are addressed as `<module>.<task>`, so a session can begin with "let's do 7.3".

Modules 8-10 get a detailed `MODULE-N.md` written when they start, not in advance - cloud
tooling moves and stale instructions are worse than none.

## Session Log

### Session 1 - 2026-08-27
- Set up CONTEXT.md, docs/, learning journal
- Reviewed existing project structure
- Planned Module 1: ansible.cfg + ansible-lint

### Session 2 - 2026-08-30
- Completed Module 1: ansible.cfg + ansible-lint
- Created ansible.cfg with inventory, roles_path, retry disabled, timeout, become
- Ran ansible-lint - 5/5 star rating, 2 accepted warnings on firewall policy variables
- Fixed lint issues: removed boilerplate, added FQCNs, cleaned whitespace
- Removed redundant NFS mount point creation task from nfs_client role
- All servers ping successfully, playbook runs clean

### Session 2 (cont) - 2026-08-30
- Completed Module 2: Grafana dashboards
- Created grafana Ansible role (GPG key, repo, package, service, datasource config)
- Configured Prometheus as default data source via Jinja2 template
- Added grafana play to playbook targeting monitor01
- Accessed Grafana via SSH tunnel, imported Node Exporter Full dashboard (ID 1860)
- ansible-lint still 5/5 stars

### Session 2 (cont) - 2026-08-30
- Completed Module 3: Alertmanager
- Created alertmanager Ansible role (install, configure, handlers)
- Created alert rules template (InstanceDown, DiskSpaceLow)
- Updated Prometheus template with alerting and rule_files sections
- Fixed var-naming lint issue (role variable prefix convention)
- ansible-lint back to 5/5 stars

### Session 3 - 2026-09-01
- Completed Module 4: Centralized logging with Loki + Alloy
- Created loki Ansible role (binary, config, systemd service)
- Created alloy Ansible role (GPG key, repo, package, config, service)
- Added host labels to Alloy config for log filtering
- Provisioned Loki as Grafana data source
- Fixed firewall rule (missing `when` condition for monitor01)
- Logs from web01/storage01 visible in Grafana Explore

### Session 4 - 2026-09-05
- Reviewed the whole learning path end to end and re-targeted the remaining modules
- Repo cleanup: removed unused `files/lab-healthcheck.sh`, leftover debug tasks, and
  boilerplate `vars/main.yml` files
- Moved `firewall_bastion_ip` from role defaults into `group_vars/lab.yml`
- Wrote real READMEs for all 11 roles (were ansible-galaxy placeholders or absent)
- Rewrote `README.md` and updated `docs/architecture.md` to cover the full observability stack
- Established that the `ansible_host` "known issue" was not a bug - documented the SSH config
  requirement instead
- `ansible-lint` still 5/5; `--syntax-check` passes
- Module 5 (Terraform/libvirt) superseded in favour of k3s, then Terraform on Azure

### Session 5 - 2026-09-06
- Wrote `ROADMAP.md`: the full path from Docker through Kubernetes and Terraform to AZ-104,
  with task IDs, hour estimates and verification criteria for each module
- Wrote `MODULE-7.md` (Kubernetes on k3s) in detail; modules 8-10 stay at task-list level
  until they start
- **Revised the cluster topology to 2 nodes.** Measured host memory: 14 GiB total with under
  1 GiB free, and `monitor01` already at 1.5 GB of its 2 GB ceiling running Prometheus,
  Alertmanager, Grafana and Loki. k3s server goes on `web01`, agent on `storage01`, and
  `monitor01` stays outside the cluster as the observability plane - which is the correct
  architecture independently of the memory constraint
- Decided Terraform/Azure gets its own repository (`azure-terraform-lab`), created at task 8.1
  rather than now; Kubernetes work stays in this repo
