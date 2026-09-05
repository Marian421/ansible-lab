# `firewall`

Applies a default-deny UFW policy with source-restricted rules.

## What it does

Every rule is restricted by **source address**, not merely by port. Source IPs are resolved at
run time from other hosts' gathered facts via `hostvars`, so the rules follow the inventory.

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `firewall_bastion_ip` | *(set in `group_vars/lab.yml`)* | Only source permitted to reach SSH |
| `firewall_ssh_port` | `22` | SSH |
| `firewall_nfs_port` | `2049` | NFSv4 |
| `firewall_alloy_port` | `3100` | Loki ingest |
| `firewall_node_exporter_port` | `9100` | Node Exporter scrape |
| `firewall_default_incoming_policy` | `deny` | Default inbound policy |
| `firewall_default_outgoing_policy` | `allow` | Default outbound policy |

## Dependencies

**Requires facts from every referenced host.** Running with `--limit` skips fact gathering for
the hosts that are excluded, leaving `hostvars[...]` undefined and the rules wrong. Run this
role against the whole `lab` group.

## Example

```yaml
- name: Configure firewall
  hosts: lab
  become: true
  roles:
    - firewall
```
