# `alertmanager`

Installs Alertmanager and the Prometheus alert rules it routes.

## What it does

Prometheus evaluates rules and fires alerts; Alertmanager handles grouping, silencing and
routing. Rule templates wrap Prometheus's own `{{ $labels.x }}` syntax in `{% raw %}` blocks so
Jinja2 does not consume it. Ships `InstanceDown` and `DiskSpaceLow`.

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `alertmanager_configuration_path` | `/etc/prometheus/alertmanager.yml` | Alertmanager configuration |
| `alertmanager_prometheus_rules` | `/etc/prometheus/rules/alert_rules.yml` | Rule file Prometheus loads |

## Dependencies

Requires the `prometheus` role.

## Example

```yaml
- name: Configure alertmanager
  hosts: monitoring
  become: true
  roles:
    - alertmanager
```
