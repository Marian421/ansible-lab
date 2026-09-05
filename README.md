# Ansible Infrastructure Lab

A four-node Linux environment on KVM/libvirt, configured entirely through Ansible: shared
storage, a default-deny firewall, and a full metrics-and-logs observability stack. Built as a
self-directed lab to practise infrastructure automation end to end.

**11 idempotent Ansible roles · `ansible-lint` clean at 5/5 (production profile)**

```
                        Ansible controller
                                │
                                │ SSH (ProxyJump)
                                ▼
                          ┌───────────┐
                          │  bastion  │  192.168.122.10
                          └─────┬─────┘
              ┌─────────────────┼─────────────────┐
              ▼                 ▼                 ▼
      ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
      │    web01     │  │  storage01   │  │  monitor01   │
      │    .20       │  │     .30      │  │     .40      │
      ├──────────────┤  ├──────────────┤  ├──────────────┤
      │ NFS client   │  │ NFS server   │  │ Prometheus   │
      │ Node Exporter│  │ Node Exporter│  │ Alertmanager │
      │ Alloy        │  │ Alloy        │  │ Grafana      │
      │              │  │              │  │ Loki         │
      └──────┬───────┘  └──────▲───────┘  └──────┬───────┘
             │  NFSv4          │                 │
             └─────────────────┘                 │
             │                                   │
             └── metrics :9100 ── logs :3100 ────┘
```

## What this demonstrates

| Area | Detail |
| --- | --- |
| **Configuration management** | 11 idempotent Ansible roles with defaults, handlers, templates and conditionals |
| **Observability** | Prometheus + Alertmanager + Grafana + Loki + Alloy, all deployed and provisioned via Ansible |
| **Shared storage** | NFSv4 exports with UID/GID consistency enforced across every host |
| **Security** | UFW default-deny inbound; every rule restricted by source address, not just port |
| **Service management** | systemd oneshot units and timers for scheduled health checks |
| **Virtualisation** | KVM/QEMU/libvirt, static addressing, SSH access via a bastion (ProxyJump) |

Three details worth pointing at:

- **Scrape targets are generated from inventory groups.** Adding a host to the `monitored` group
  is enough for Prometheus to start scraping it — no configuration edit.
- **Alert rules are validated before they land.** The Prometheus template uses
  `validate: 'promtool check rules %s'`, so an invalid rule fails the Ansible task rather than
  breaking Prometheus on restart.
- **Firewall rules resolve source IPs from other hosts' facts** via `hostvars`, so the policy
  follows the inventory instead of a hard-coded list.

## Hosts

| Host | IP | Role |
| --- | --- | --- |
| `bastion` | 192.168.122.10 | SSH jump host — entry point, deliberately not a managed node |
| `web01` | 192.168.122.20 | Web server, NFS client, Node Exporter, Alloy |
| `storage01` | 192.168.122.30 | NFS server, Node Exporter, Alloy |
| `monitor01` | 192.168.122.40 | Prometheus, Alertmanager, Grafana, Loki, NFS client |

## Roles

| Role | Applied to | Purpose |
| --- | --- | --- |
| [`healthcheck`](roles/healthcheck) | `lab` | systemd timer + templated script for periodic health checks |
| [`identity`](roles/identity) | `lab` | Users and groups with fixed UIDs/GIDs for NFS consistency |
| [`firewall`](roles/firewall) | `lab` | UFW default-deny with source-restricted rules |
| [`nfs_server`](roles/nfs_server) | `storage` | NFSv4 exports |
| [`nfs_client`](roles/nfs_client) | `nfs_clients` | Persistent NFS mounts via `fstab` |
| [`node_exporter`](roles/node_exporter) | `monitored` | Host metrics on `:9100` |
| [`prometheus`](roles/prometheus) | `monitoring` | Metrics collection, inventory-driven targets, validated rules |
| [`alertmanager`](roles/alertmanager) | `monitoring` | Alert routing (`InstanceDown`, `DiskSpaceLow`) |
| [`grafana`](roles/grafana) | `monitoring` | Dashboards with provisioned data sources |
| [`loki`](roles/loki) | `monitoring` | Log aggregation backend |
| [`alloy`](roles/alloy) | `monitored` | Journal log shipping to Loki, with per-host labels |

## Requirements

- A libvirt/KVM host with the four VMs reachable on `192.168.122.0/24`
- Ansible with the collections in `requirements.yml`:
  `ansible-galaxy collection install -r requirements.yml`
- **SSH client configuration defining the host aliases.** The inventory uses bare hostnames, so
  connection details live in `~/.ssh/config` — this is what routes every host through the
  bastion:

  ```sshconfig
  Host bastion
      HostName 192.168.122.10
      User john
      IdentityFile ~/.ssh/id_ed25519_lab

  Host web01
      HostName 192.168.122.20
      User john
      IdentityFile ~/.ssh/id_ed25519_lab
      ProxyJump bastion
  ```

  Setting `ansible_host` in the inventory instead would bypass these blocks and break
  `ProxyJump`, so the aliases are intentional.

## Usage

```bash
# Check connectivity
ansible lab -m ping

# Full run
ansible-playbook first-playbook.yml

# Dry run
ansible-playbook first-playbook.yml --check --diff

# Lint
ansible-lint
```

Reaching the monitoring UIs without opening firewall ports:

```bash
ssh -L 3000:localhost:3000 monitor01   # Grafana
ssh -L 9090:localhost:9090 monitor01   # Prometheus
ssh -L 9093:localhost:9093 monitor01   # Alertmanager
```

> **Note on `--limit`:** the `firewall` role resolves source addresses from other hosts'
> gathered facts. Running with `--limit` skips fact gathering for excluded hosts, leaving
> `hostvars[...]` undefined and the rules wrong. Run it against the whole `lab` group.

## Security model

```
Inbound: DENY by default (UFW)

SSH      bastion              → all lab servers   TCP/22
NFS      web01, monitor01     → storage01         TCP/2049
Metrics  monitor01            → web01, storage01  TCP/9100
Logs     web01, storage01     → monitor01         TCP/3100
Everything else: DENY
```

Grafana, Prometheus and Alertmanager are never exposed — they are reached over an SSH tunnel.

## Documentation

- [`docs/architecture.md`](docs/architecture.md) — topology, data flows, inventory groups
- [`docs/learning-journal.md`](docs/learning-journal.md) — build log, including the problems hit
  and how they were diagnosed
- [`CONTEXT.md`](CONTEXT.md) — current state and module progress
