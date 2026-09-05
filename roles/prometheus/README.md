# `prometheus`

Installs and configures Prometheus, including alert rules.

## What it does

Scrape targets are **generated from inventory groups** rather than hard-coded, so adding a host
to the `monitored` group is enough to start scraping it. Alert rules are validated at deploy
time with `promtool check rules` via the template `validate:` hook — an invalid rule fails the
task and never reaches disk.

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `prometheus_package` / `prometheus_service` | `prometheus` | Package and service names |
| `prometheus_config` | `/etc/prometheus/prometheus.yml` | Main configuration file |
| `prometheus_rules` | `/etc/prometheus/rules/alert_rules.yml` | Alert rule file |

## Dependencies

Expects `node_exporter` on scraped hosts and `alertmanager` for routing.

## Example

```yaml
- name: Configure prometheus
  hosts: monitoring
  become: true
  roles:
    - prometheus
```
