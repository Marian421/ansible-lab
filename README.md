# Ansible Infrastructure Lab

A four-node Linux environment on KVM/libvirt, configured entirely through Ansible: shared
storage, a default-deny firewall, and a full metrics-and-logs observability stack. Built as a
self-directed lab to practise infrastructure automation end to end.

**12 idempotent Ansible roles · `ansible-lint` clean at 5/5 (production profile)**

```
                        Ansible controller
                                │
                                │ SSH (ProxyJump)
                                ▼
                          ┌───────────┐
                          │  bastion  │  192.168.150.10
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
      │              │  │              │  │ Loki, Alloy  │
      └──────┬───────┘  └──────▲───────┘  └──────┬───────┘
             │  NFSv4          │                 │
             └─────────────────┘                 │
             │                                   │
             └── metrics :9100 ── logs :3100 ────┘
```

## What this demonstrates

| Area | Detail |
| --- | --- |
| **Configuration management** | 12 idempotent Ansible roles with defaults, handlers, templates and conditionals |
| **Observability** | Prometheus + Alertmanager + Grafana + Loki + Alloy, all deployed and provisioned via Ansible |
| **Shared storage** | NFSv4 exports with UID/GID consistency enforced across every host |
| **Security** | UFW default-deny inbound; every rule restricted by source address, not just port |
| **Service management** | systemd oneshot units and timers for scheduled health checks |
| **Virtualisation** | VMs provisioned with Terraform on KVM/libvirt ([`terraform-kvm-lab`](https://github.com/Marian421/terraform-kvm-lab)), DHCP-reserved addresses and DNS names, SSH access via a bastion (ProxyJump) |

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
| `bastion` | 192.168.150.10 | SSH jump host — entry point, deliberately not a managed node |
| `web01` | 192.168.150.20 | Web server, NFS client, Node Exporter, Alloy |
| `storage01` | 192.168.150.30 | NFS server, Node Exporter, Alloy |
| `monitor01` | 192.168.150.40 | Prometheus, Alertmanager, Grafana, Loki, Alloy, NFS client |

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
| [`grafana_apt_repo`](roles/grafana_apt_repo) | dependency of `grafana`, `alloy` | The Grafana APT repository and signing key, defined once |
| [`loki`](roles/loki) | `monitoring` | Log aggregation backend |
| [`alloy`](roles/alloy) | `monitored` | Journal log shipping to Loki, with per-host labels |

## Requirements

- The four VMs from [`terraform-kvm-lab`](https://github.com/Marian421/terraform-kvm-lab)'s `dev`
  environment on `192.168.150.0/24`. Its network gives each VM a DNS name
  (`<host>.dev.lab.test`), which the NFS clients use to find `storage01`.
- Ansible with the collections in `requirements.yml`:
  `ansible-galaxy collection install -r requirements.yml`
- **SSH client configuration defining the host aliases.** The inventory uses bare hostnames, so
  connection details live in `~/.ssh/config` — this is what routes every host through the
  bastion:

  ```sshconfig
  Host bastion
      HostName 192.168.150.10
      User john
      IdentityFile ~/.ssh/id_ed25519_lab

  Host web01
      HostName 192.168.150.20
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

## Things I ran into

Moving the lab from hand-built VMs to Terraform-built ones (empty Debian cloud images, rebuilt
from code) showed what the old VMs had picked up by hand and no file recorded:

- **DNS names.** NFS failed with `Failed to resolve server storage01`. The old libvirt network
  had hostnames on its DHCP reservations, added by hand; the new one had none, so libvirt's
  dnsmasq answered from the host's `/etc/hosts`, which still held the old addresses. Fixed in
  Terraform (hostnames in the reservations) and by using the full name
  `storage01.dev.lab.test` in `group_vars/lab.yml`.
- **`unzip`.** The `loki` role extracts a `.zip` and the cloud image has no `unzip`. The role now
  installs it first.
- **Two roles, one APT source, two keys.** `grafana` and `alloy` each added `apt.grafana.com`
  with a different key file. Only `monitor01` runs both, and there apt refused to read any
  sources. The repository moved into `grafana_apt_repo`, which both roles depend on.
- **Healthcheck on a first run.** The healthcheck handler runs the check in the first play,
  before the NFS client play has mounted anything, so a fresh build fails on `web01` and
  `monitor01` the first time. Still open.

## Documentation

- [`docs/architecture.md`](docs/architecture.md) — topology, data flows, inventory groups
- [`docs/learning-journal.md`](docs/learning-journal.md) — build log, including the problems hit
  and how they were diagnosed
- Each role carries its own README: variables, dependencies and a usage example.
