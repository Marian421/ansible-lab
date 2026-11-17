# `grafana`

Installs Grafana and provisions its data sources.

## What it does

Installs the package from the Grafana APT repository (added by `grafana_apt_repo`), and templates
data-source provisioning files so Prometheus and Loki are configured on first start — no
clicking through the UI.

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `grafana_datasource_url` | `http://localhost:9090` | Prometheus URL (same host, so localhost) |
| `grafana_datasource_configuration_file_path` | `/etc/grafana/provisioning/datasources/prometheus.yml` | Provisioning file path |

## Dependencies

Requires `prometheus`; `loki` is provisioned as a second data source. Pulls in
`grafana_apt_repo` (`meta/main.yml`) for the package repository.

## Example

```yaml
- name: Configure grafana
  hosts: monitoring
  become: true
  roles:
    - grafana
```
