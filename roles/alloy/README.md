# `alloy`

Installs Grafana Alloy to ship journal logs to Loki.

## What it does

Alloy is Grafana's unified collector and replaces Promtail. Collects from the systemd journal
and forwards to Loki, attaching a `host` label so logs are filterable per machine in Grafana
(`{host="web01"}`).

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `alloy_configuration_dir` / `alloy_configuration_file` | `/etc/alloy`, `/etc/alloy/config.alloy` | Configuration paths |

## Dependencies

Requires a reachable `loki` endpoint. Pulls in `grafana_apt_repo` (`meta/main.yml`) for the
package repository.

## Example

```yaml
- name: Configure alloy
  hosts: monitored
  become: true
  roles:
    - alloy
```
