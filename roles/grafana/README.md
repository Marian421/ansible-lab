# `grafana`

Installs Grafana and provisions its data sources.

## What it does

Adds the Grafana APT repository with GPG key verification, installs the package, and templates
data-source provisioning files so Prometheus and Loki are configured on first start — no
clicking through the UI.

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `grafana_datasource_url` | `http://localhost:9090` | Prometheus URL (same host, so localhost) |
| `grafana_datasource_configuration_file_path` | `/etc/grafana/provisioning/datasources/prometheus.yml` | Provisioning file path |

## Dependencies

Requires `prometheus`; `loki` is provisioned as a second data source.

## Example

```yaml
- name: Configure grafana
  hosts: monitoring
  become: true
  roles:
    - grafana
```
