# `loki`

Installs Loki, the log aggregation backend.

## What it does

Downloads a pinned Loki release, installs it as a systemd service under a dedicated user, and
templates its configuration. Loki indexes logs by label — the same model Prometheus uses for
metrics — rather than full-text indexing.

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `loki_version` | `3.7.7` | Pinned release — never track `latest` |
| `loki_user` / `loki_group` | `loki` | Service account |
| `loki_binary` | `/usr/local/bin/loki` | Binary destination |
| `loki_config_dir` / `loki_data_dir` | `/etc/loki`, `/var/lib/loki` | Config and chunk storage |
| `loki_http_port` | `3100` | Listen port — must match the firewall rule |

## Dependencies

Pairs with `alloy` (shippers) and `grafana` (query UI).

## Example

```yaml
- name: Configure loki
  hosts: monitoring
  become: true
  roles:
    - loki
```
