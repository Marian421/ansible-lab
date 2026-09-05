# `node_exporter`

Installs Prometheus Node Exporter for host-level metrics.

## What it does

Exposes CPU, memory, disk, filesystem and network metrics on `/metrics`. Prometheus scrapes
this endpoint; the exporter never pushes.

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `node_exporter_package` | `prometheus-node-exporter` | Package name |
| `node_exporter_service` | `prometheus-node-exporter` | Service name |
| `node_exporter_port` | `9100` | Listen port — must match the firewall rule |

## Dependencies

None. Access is restricted to the Prometheus host by the `firewall` role.

## Example

```yaml
- name: Configure node_exporter
  hosts: monitored
  become: true
  roles:
    - node_exporter
```
