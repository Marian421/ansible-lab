# Module 3: Alertmanager

## Scenario

Prometheus is scraping metrics. Grafana shows dashboards. But nobody's watching the dashboards 24/7.

Your boss says:

> "I need to know when disk usage is above 85%, when a service goes down, or when a server is unreachable. Send an email. Or at least log it somewhere I can see."

---

## Tasks

### Task 1: Install Alertmanager

Create an `alertmanager` Ansible role. Install Alertmanager on `monitor01` (same host as Prometheus).

The package name is `prometheus-alertmanager`.

### Task 2: Configure Alertmanager

Create a configuration file at `/etc/alertmanager/alertmanager.yml` using a Jinja2 template.

Basic structure:
```yaml
global:
  resolve_timeout: 5m

route:
  receiver: 'default'
  group_by: ['alertname', 'instance']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

receivers:
  - name: 'default'
    # For now, just log to a file or use a webhook
    # We'll add email/Slack later
```

For now, use a simple receiver that logs alerts. We'll add email notifications later.

### Task 3: Create Prometheus alert rules

Create alert rule files in `/etc/prometheus/rules/` using Ansible templates.

Create rules for:
- **InstanceDown** - target is unreachable
- **HighCPU** - CPU usage above 85% for 5 minutes
- **HighMemory** - memory usage above 85%
- **DiskSpaceLow** - disk usage above 85%

Example rule:
```yaml
groups:
  - name: node
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} is down"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disk space low on {{ $labels.instance }}"
```

### Task 4: Configure Prometheus to use Alertmanager

Update the Prometheus configuration template (`roles/prometheus/templates/prometheus.yml.j2`) to include:

```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - 'localhost:9093'

rule_files:
  - '/etc/prometheus/rules/*.yml'
```

### Task 5: Add handlers

The alertmanager and prometheus handlers should restart their respective services when config changes.

### Task 6: Add the role to your playbook

```yaml
- name: Install Alertmanager
  hosts: monitoring
  become: true
  roles:
    - alertmanager
```

Make sure this runs BEFORE the Prometheus role (so the config is ready).

### Task 7: Run and verify

```bash
ansible-playbook first-playbook.yml
```

Verify:
- Alertmanager is running on port 9093
- Prometheus is connected to Alertmanager
- Alert rules are loaded
- Try creating a test alert (optional)

### Task 8: View alerts

Access Alertmanager UI via SSH tunnel:
```bash
ssh -L 9093:localhost:9093 monitor01
```

Then open `http://localhost:9093` in your browser.

---

## What You're Learning

- Alerting architecture (Prometheus → Alertmanager → notifications)
- Prometheus recording rules and alerting rules
- YAML configuration for alert routing
- Service integration between Prometheus and Alertmanager
- The difference between "monitoring" (seeing data) and "alerting" (being notified)

## Verification

1. `ansible-playbook first-playbook.yml` completes without errors
2. Alertmanager service is running on monitor01
3. Prometheus is connected to Alertmanager (check Prometheus UI → Status → Alertmanagers)
4. Alert rules are loaded (check Prometheus UI → Status → Rules)
5. Alertmanager UI is accessible via SSH tunnel
6. `ansible-lint` still passes

## Deliverables

When you're done, show me:
1. Your `roles/alertmanager/` structure
2. Your alert rules file
3. Output of `ansible-playbook first-playbook.yml`
4. Screenshot or description of Alertmanager UI showing connected state
