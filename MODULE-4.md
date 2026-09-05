# Module 4: Centralized Logging with Loki + Alloy

## Scenario

web01 is having issues. You SSH in, check `journalctl`, but the logs are only on web01. What if web01 is unreachable? What if you need to correlate logs from web01 and storage01 at the same time?

Your colleague says:

> "I'm not SSHing into 4 different servers to read logs. And I'm not learning a new UI either. Put it in Grafana."

---

## Architecture

You already have Prometheus + Grafana for metrics. Now add Loki for logs:

```
web01 ──── Alloy ───────┐
                         ├──→ Loki ──→ Grafana
storage01 ── Alloy ─────┘
```

Same pattern as metrics:
- **Alloy** = log collector (like Node Exporter for logs, but newer)
- **Loki** = log storage and indexing (like Prometheus for logs)
- **Grafana** = visualization (already installed)

Why Alloy over Promtail:
- Alloy is Grafana's unified agent (replaces Promtail, Tempo agent, etc.)
- Actively developed (Promtail is in maintenance mode)
- Can collect logs, metrics, and traces in one binary
- More relevant for job posts

---

## Tasks

### Task 1: Install Loki on monitor01

Create a `loki` Ansible role that:
- Downloads the Loki binary (or installs via apt repo)
- Creates a systemd service for Loki
- Configures Loki to store data locally
- Exposes port 3100 for Alloy to push logs

Loki config (`/etc/loki/config.yml`):
```yaml
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /var/lib/loki
  storage:
    filesystem:
      chunks_directory: /var/lib/loki/chunks
      rules_directory: /var/lib/loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: "2024-01-01"
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
```

### Task 2: Install Alloy on web01 and storage01

Create an `alloy` Ansible role that:
- Adds the Grafana Alloy repository
- Installs the alloy package
- Configures Alloy to collect system logs and forward to Loki
- Targets Loki at `http://monitor01:3100/loki/api/v1/push`

Alloy config (`/etc/alloy/config.alloy`):
```hcl
logging {
  level = "info"
}

loki.write "loki" {
  endpoint {
    url = "http://monitor01:3100/loki/api/v1/push"
  }
}

loki.source.journal "journal" {
  forward_to = [loki.write.loki.receiver]
}

loki.source.syslog "syslog" {
  listener_address = "0.0.0.0:1514"
  forward_to       = [loki.write.loki.receiver]
}
```

### Task 3: Update Prometheus to scrape Loki (optional)

If you want to monitor Loki itself, add it to your Prometheus scrape config. Loki exposes metrics on `:3100/metrics`.

### Task 4: Add Loki as a Grafana data source

You can provision this via Ansible template:
```yaml
# /etc/grafana/provisioning/datasources/loki.yml
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://localhost:3100
    isDefault: false
```

### Task 5: Update firewall

On monitor01, allow port 3100 from web01 and storage01:
```yaml
- name: Allow Loki from lab servers
  community.general.ufw:
    rule: allow
    src: "{{ item }}"
    port: "3100"
    proto: tcp
  loop:
    - "{{ hostvars['web01']['ansible_facts']['default_ipv4']['address'] }}"
    - "{{ hostvars['storage01']['ansible_facts']['default_ipv4']['address'] }}"
```

### Task 6: Run and verify

```bash
ansible-playbook first-playbook.yml
```

On web01, generate a test log:
```bash
logger "Test message from web01"
```

In Grafana:
1. Go to Explore → Select Loki data source
2. Query: `{host="web01"}`
3. You should see the test message

---

## What You're Learning

- Modern observability stack (Prometheus + Loki + Grafana)
- Log collection with Alloy (unified agent pattern)
- Label-based log indexing (same concept as Prometheus metrics)
- Grafana as a unified observability platform
- The difference between traditional syslog and modern log aggregation

## Verification

1. `ansible-playbook first-playbook.yml` completes without errors
2. Loki service is running on monitor01 (port 3100)
3. Alloy service is running on web01 and storage01
4. Grafana has Loki as a data source
5. Logs from web01 appear in Grafana Explore
6. `ansible-lint` still passes

## Deliverables

When you're done, show me:
1. Your `loki` and `alloy` role structures
2. Output of `ansible-playbook first-playbook.yml`
3. Screenshot or description of logs appearing in Grafana
