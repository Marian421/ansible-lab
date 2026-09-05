# Learning Journal

Ticket-based progress log for the Ansible Infrastructure Lab.
Each completed task is documented here as evidence of hands-on experience.

---

## Pre-Lab Work (Completed before formal tracking)

### Ticket: Build the Lab Infrastructure
**Date:** 2026-07/08
**Goal:** Set up a multi-server lab environment on KVM/libvirt

**What was done:**
- Installed KVM, QEMU, libvirt, virt-manager
- Created 4 VMs: bastion, web01, storage01, monitor01
- Configured static IPs on 192.168.122.0/24
- Set up SSH key authentication with Ed25519 keys
- Configured SSH ProxyJump through bastion

**What was learned:**
- KVM/QEMU/libvirt relationship (KVM = kernel module, QEMU = emulator, libvirt = management)
- SSH config with ProxyJump for bastion host pattern
- ssh-agent lifecycle and persistence across reboots

---

### Ticket: Users, Groups, and Permissions
**Date:** 2026-07/08
**Goal:** Manage users with consistent UIDs across servers for NFS compatibility

**What was done:**
- Created `developers` group with GID 1003 across all servers
- Created users with consistent UIDs
- Configured SGID directories for shared storage
- Troubleshot NFS permission issues caused by UID mismatches

**What was learned:**
- NFS uses numeric UIDs, not usernames
- SGID directories ensure files inherit the parent group
- UID/GID consistency is critical for NFS shared storage

---

### Ticket: NFS Server and Client Setup
**Date:** 2026-07/08
**Goal:** Set up shared storage between servers using NFS

**What was done:**
- Configured storage01 as NFS server with NFSv4
- Created exports: `/srv/storage/shared`, `/srv/storage/projects`
- Mounted NFS shares on web01 and monitor01
- Configured `/etc/fstab` for persistent mounts

**What was learned:**
- NFSv4 uses TCP/2049 (no rpcbind dependency like NFSv3)
- `root_squash` and `all_squash` affect file ownership
- `exportfs -ra` to reload exports without restarting service

---

### Ticket: Ansible Setup and First Playbook
**Date:** 2026-08
**Goal:** Automate lab configuration with Ansible

**What was done:**
- Created inventory with groups: web, storage, monitoring, lab, nfs_clients, monitored
- Wrote first playbook with multiple plays targeting different groups
- Created healthcheck role with tasks, handlers, templates, defaults
- Converted healthcheck script from static file to Jinja2 template

**What was learned:**
- Inventory groups enable targeted plays (e.g., `hosts: monitored`)
- `gather_facts: true` is required for `ansible_facts` to be available
- Handlers run only when notified by a task that changed state
- Jinja2 templates produce per-host output from the same template
- Idempotency: Ansible checks desired state, doesn't re-run unless needed

---

### Ticket: Healthcheck with Systemd Timer
**Date:** 2026-08
**Goal:** Automated health checks running on a schedule

**What was done:**
- Created dedicated `healthcheck` system user with nologin shell
- Deployed healthcheck script via Ansible template
- Created systemd service (oneshot) and timer (5min interval)
- Script checks: disk usage, inode usage, load average, service status, NFS mounts

**What was learned:**
- Systemd timers vs cron (timers are more flexible, integrate with journalctl)
- `daemon_reload: true` needed when unit files change
- System accounts should have nologin shell for least privilege

---

### Ticket: Node Exporter and Prometheus Monitoring
**Date:** 2026-08
**Goal:** Set up monitoring with Prometheus scraping Node Exporter

**What was done:**
- Installed prometheus-node-exporter on web01 and storage01
- Installed Prometheus on monitor01
- Configured Prometheus to scrape Node Exporter on port 9100
- Created Prometheus config template with dynamic targets from inventory

**What was learned:**
- Prometheus pull model: it scrapes targets, targets don't push
- Node Exporter exposes system metrics at `/metrics`
- Template loop over `groups['monitored']` for dynamic target discovery

---

### Ticket: Firewall with UFW
**Date:** 2026-08
**Goal:** Default-deny inbound with source-restricted rules

**What was done:**
- Installed UFW on all lab servers
- Configured default-deny inbound, allow outbound
- Restricted SSH to bastion IP only
- Restricted Node Exporter to monitor01 only
- Restricted NFS to web01 and monitor01 only

**What was learned:**
- `hostvars` cross-host lookup requires gathered facts from all referenced hosts
- `--limit` flag breaks cross-host fact gathering
- Ansible facts ≠ inventory information
- Firewall rules should be source-restricted, not just port-allowed

---

### Ticket: Identity Role (Users/Groups)
**Date:** 2026-08
**Goal:** Automate user/group management with consistent UIDs

**What was done:**
- Created identity Ansible role
- Defined users and groups in vars
- Applied role to all lab servers
- Ensured UID/GID consistency across servers

**What was learned:**
- Separating identity from healthcheck keeps roles focused
- Consistent UIDs across servers prevents NFS permission issues
- Role vars vs defaults: vars are "always applied", defaults are "overridable"

---

## Learning Modules (Formal Tickets)

---

### Ticket #1: ansible.cfg and ansible-lint
**Date:** 2026-08-30
**Goal:** Clean up Ansible project structure and enforce code quality
**Status:** completed

**What was done:**
- Created `ansible.cfg` at project root with:
  - Default inventory path (`./inventory`)
  - Roles path (`~/ansible-lab/roles/`)
  - Retry files disabled
  - 30s timeout
  - Privilege escalation with `become=True`
- Ran `ansible-lint` - achieved 5/5 star rating
- Fixed lint issues:
  - Removed boilerplate `meta/main.yml` and `tests/` from firewall and identity roles
  - Added FQCN (`ansible.builtin.systemd`) in handlers
  - Cleaned trailing whitespace in defaults and vars
  - Added `name:` to unnamed tasks
- Removed redundant NFS mount point creation task from `nfs_client` role (mount module handles this)

**What was learned:**
- `ansible.cfg` centralizes configuration - no more passing `-i inventory` and `--ask-become-pass` every time
- `ansible-lint` enforces code quality and catches common mistakes
- FQCN (fully qualified collection names) make module origins explicit
- `ansible.posix.mount` with `state: mounted` creates mount points automatically - separate `mkdir` is redundant
- Some lint warnings are false positives (e.g., variable values that resolve correctly at runtime)

**Remaining warnings (accepted):**
- 2 `args[module]` warnings on firewall policy variables - linter can't verify variable values statically

---

### Ticket #2: Grafana Dashboards
**Date:** 2026-08-30
**Goal:** Install Grafana on monitor01, configure Prometheus data source, import Node Exporter dashboard
**Status:** completed

**What was done:**
- Created `grafana` Ansible role with tasks, handlers, defaults, templates
- Added Grafana repository with GPG key verification
- Installed Grafana via apt
- Configured Prometheus as default data source using Jinja2 template
- Added Grafana play to `first-playbook.yml` targeting monitor01
- Accessed Grafana via SSH tunnel (`ssh -L 3000:localhost:3000 monitor01`)
- Imported Node Exporter Full dashboard (ID 1860)

**What was learned:**
- Installing software with Ansible requires multiple steps: GPG key, repository, package, service, configuration
- `notify` handlers allow different actions for install vs config changes
- Grafana provisioning files can be templated for idempotent configuration
- SSH tunneling avoids opening ports in firewall for development access
- Grafana and Prometheus on the same host can use `localhost` for data source URL

---

### Ticket #3: Alertmanager
**Date:** 2026-08-30
**Goal:** Install Alertmanager, create alert rules, connect Prometheus to Alertmanager
**Status:** completed

**What was done:**
- Created `alertmanager` Ansible role (install, configure, handlers)
- Created alert rules template with InstanceDown and DiskSpaceLow alerts
- Updated Prometheus template to include `alerting` and `rule_files` sections
- Added rules directory creation and rule validation (`promtool check rules`) to Prometheus role
- Alertmanager accessible via SSH tunnel (`ssh -L 9093:localhost:9093 monitor01`)

**What was learned:**
- Alerting architecture: Prometheus evaluates rules → fires alerts → Alertmanager handles routing
- `{% raw %}` blocks in Jinja2 templates preserve Prometheus's `{{ $labels.instance }}` syntax
- `promtool check rules` validates alert rules before deploying
- Variable naming convention: role variables should use role name as prefix (fixed `alertmanager_prometheus_rules` → `prometheus_rules_path`)

---

### Ticket #4: Centralized Logging with Loki + Alloy
**Date:** 2026-09-01
**Goal:** Centralize logs from all servers into Grafana using Loki and Alloy
**Status:** completed

**What was done:**
- Created `loki` Ansible role (binary download, config, systemd service)
- Created `alloy` Ansible role (GPG key, repo, package, config, service)
- Configured Alloy to collect journal logs and forward to Loki
- Added host labels to Alloy config for log filtering
- Provisioned Loki as Grafana data source
- Updated firewall to allow port 3100 from lab servers to monitor01

**What was learned:**
- Modern observability stack: Prometheus (metrics) + Loki (logs) + Grafana (visualization)
- Alloy is Grafana's unified agent (replaces Promtail)
- Label-based log indexing follows the same pattern as Prometheus metrics
- Host labels are essential for filtering logs in Grafana (`{host="web01"}`)
- Firewall rules need `when` conditions to target only the correct hosts

**Issues encountered:**
- Initially no host label on Alloy logs → couldn't filter by host in Grafana
- Firewall rule for Loki missing `when: inventory_hostname == 'monitor01'` condition

---

*This journal is updated after each completed ticket.*
*Entries show real work done, not just theory.*
