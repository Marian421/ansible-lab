# Ansible Infrastructure Lab

A multi-server infrastructure lab built to practice Linux administration, automation, monitoring, and security. Configuration is managed through Ansible with idempotent roles.

## Architecture

```
                    Bastion (SSH Jump Host)
                              │
              ┌───────────────┼───────────────┐
              │               │               │
           web01          storage01       monitor01
        Web Server       NFS Server      Prometheus
        NFS Client       Metrics Export   NFS Client
        Metrics Export
```

| Host | IP | Role |
|------|----|------|
| bastion | 192.168.122.10 | SSH jump host |
| web01 | 192.168.122.20 | Web server, NFS client, Node Exporter |
| storage01 | 192.168.122.30 | NFS server, Node Exporter |
| monitor01 | 192.168.122.40 | Prometheus, NFS client |

## What This Lab Demonstrates

- **Linux Administration:** Users, groups, permissions, systemd, SSH, networking
- **Storage:** NFSv4 server/client with consistent UID/GID across servers
- **Automation:** Ansible roles with variables, templates, handlers, conditionals
- **Security:** UFW default-deny firewall with source-restricted rules
- **Monitoring:** Prometheus + Node Exporter for system metrics
- **Health Checks:** Systemd timers with automated health verification

## Ansible Roles

| Role | Purpose |
|------|---------|
| `healthcheck` | Systemd timer + script for periodic health checks |
| `identity` | User/group management with consistent UIDs |
| `nfs_server` | NFS exports configuration |
| `nfs_client` | NFS mount points |
| `node_exporter` | Prometheus metrics exporter |
| `prometheus` | Prometheus monitoring setup |
| `firewall` | UFW rules, default-deny inbound |

## Project Structure

```
ansible-lab/
├── ansible.cfg
├── inventory
├── group_vars/
├── first-playbook.yml
├── roles/
│   ├── healthcheck/
│   ├── identity/
│   ├── nfs_server/
│   ├── nfs_client/
│   ├── node_exporter/
│   ├── prometheus/
│   └── firewall/
├── docs/
│   ├── architecture.md
│   └── learning-journal.md
└── CONTEXT.md
```

## Usage

```bash
# Test connectivity
ansible -i inventory lab -m ping

# Run all roles
ansible-playbook -i inventory first-playbook.yml

# Run specific role
ansible-playbook -i inventory first-playbook.yml --limit web01
```

## Security

- Default-deny inbound firewall (UFW)
- SSH restricted to bastion host only
- NFS restricted to known clients
- Node Exporter restricted to Prometheus server
- Dedicated healthcheck user with nologin shell

## Learning Progress

See [docs/learning-journal.md](docs/learning-journal.md) for ticket-based documentation of what was built and learned.
