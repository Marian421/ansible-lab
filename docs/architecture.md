# Lab Architecture

Multi-server infrastructure lab for practicing Linux administration, automation, monitoring, and security.

---

## Network Topology

```
                    Laptop / Ansible Controller
                              │
                              │ SSH
                              ▼
                         ┌─────────┐
                         │ bastion │
                         │  .10    │
                         └────┬────┘
                              │ ProxyJump
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
        ┌──────────┐   ┌───────────┐   ┌───────────┐
        │  web01   │   │ storage01 │   │ monitor01 │
        │  .20     │   │   .30     │   │   .40     │
        │          │   │           │   │           │
        │ Web      │   │ NFS       │   │ Prometheus│
        │ NFS      │   │ Server    │   │ NFS       │
        │ Client   │   │ Exporter  │   │ Client    │
        │ Exporter │   │           │   │ Exporter  │
        └────┬─────┘   └─────┬─────┘   └─────┬─────┘
             │               ▲               │
             │               │               │
             └──── NFS ──────┘───────────────┘

                      monitor01
                         │
                         │ HTTP :9090
                         ▼
                    Prometheus
                         │
                         ├── scrape web01:9100
                         └── scrape storage01:9100
```

## Hosts

| Host | IP | Role |
|------|----|------|
| bastion | 192.168.122.10 | SSH jump host, firewall gateway |
| web01 | 192.168.122.20 | Web server, NFS client, Node Exporter |
| storage01 | 192.168.122.30 | NFS server, Node Exporter |
| monitor01 | 192.168.122.40 | Prometheus, NFS client, monitoring |

All hosts on `192.168.122.0/24` (KVM default NAT network).

## Security Model

```
Inbound: DENY by default (UFW)

SSH:        bastion → all servers (TCP/22)
NFS:        web01, monitor01 → storage01 (TCP/2049)
Metrics:    monitor01 → web01, storage01 (TCP/9100)
Logs:       web01, storage01 → monitor01 (TCP/3100)
Everything else: DENY
```

## Inventory Groups

| Group | Members | Purpose |
|-------|---------|---------|
| web | web01 | Web server |
| storage | storage01 | NFS server |
| monitoring | monitor01 | Monitoring server |
| nfs_clients | web, monitoring | Machines mounting NFS |
| lab | web, storage, monitoring | All managed servers |
| monitored | web, storage, monitoring | All machines with Node Exporter |

The bastion is outside the `lab` group - it's SSH entry point, not a managed server.

## Ansible Roles

| Role | Applied to | Purpose |
|------|-----------|---------|
| healthcheck | lab | Systemd timer + script for health checks |
| identity | lab | Users/groups with consistent UIDs |
| firewall | lab | UFW rules, default-deny, source-restricted |
| nfs_server | storage | NFS exports configuration |
| nfs_client | nfs_clients | NFS mount points |
| node_exporter | monitored | Prometheus metrics exporter |
| prometheus | monitoring | Metrics collection, inventory-driven targets |
| alertmanager | monitoring | Alert routing |
| grafana | monitoring | Dashboards, provisioned data sources |
| loki | monitoring | Log aggregation backend |
| alloy | monitored | Journal log shipping to Loki |

## NFS Layout

```
storage01:
  /srv/storage/shared    → /mnt/shared    (web01, monitor01)
  /srv/storage/projects  → /mnt/projects  (web01, monitor01)
```

NFSv4 over TCP/2049. Consistent UIDs/GIDs across servers ensure permissions work.

## Observability Flow

Two independent pipelines, joined at Grafana.

```
METRICS                                 LOGS

Node Exporter :9100                     systemd journal
(web01, storage01, monitor01)           (web01, storage01)
       │                                       │
       │ scraped every 15s                     │ collected by Alloy
       ▼                                       │ push :3100
  Prometheus (monitor01)                       ▼
       │                                  Loki (monitor01)
       │ evaluates alert rules                 │
       ▼                                       │
  Alertmanager (monitor01)                     │
       │ routes / groups / silences            │
       │                                       │
       └──────────► Grafana ◄──────────────────┘
                   (monitor01)
                        │
                        ▼
              SSH tunnel :3000 → laptop
```

Scrape targets are generated from the `monitored` inventory group, so adding a host to that
group is sufficient for Prometheus to begin scraping it.

Alert rules are validated with `promtool check rules` through the Ansible template `validate:`
hook, so an invalid rule fails the play rather than breaking Prometheus at restart.

Logs carry a `host` label applied by Alloy, which is what makes `{host="web01"}` filtering work
in Grafana Explore.

## Healthcheck Flow

```
systemd timer (every 5min)
       │
       ▼
lab-healthcheck.sh (as healthcheck user)
       │
       ├── disk usage check
       ├── inode usage check
       ├── load average
       ├── service status (ssh)
       └── NFS mount check (on nfs_clients)
       │
       ▼
exit 0 (OK) / exit 1 (FAILED)
       │
       ▼
journalctl -u lab-healthcheck
```
