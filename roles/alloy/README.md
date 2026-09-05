# `alloy`

Installs Grafana Alloy to ship journal logs to Loki.

## What it does

Alloy is Grafana's unified collector and replaces Promtail. Collects from the systemd journal
and forwards to Loki, attaching a `host` label so logs are filterable per machine in Grafana
(`{host="web01"}`).

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `alloy_keyring_dir` / `alloy_keyring_file` | `/etc/apt/keyrings` | APT keyring location for the Grafana repo |
| `alloy_configuration_dir` / `alloy_configuration_file` | `/etc/alloy`, `/etc/alloy/config.alloy` | Configuration paths |

## Dependencies

Requires a reachable `loki` endpoint.

## Example

```yaml
- name: Configure alloy
  hosts: monitored
  become: true
  roles:
    - alloy
```
