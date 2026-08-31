# Module 2: Grafana Dashboards

## Scenario

Prometheus is scraping Node Exporter on web01 and storage01. But the only way to see metrics is:

```bash
curl http://monitor01:9090/api/v1/query?query=node_cpu_seconds_total
```

Nobody's going to do that at 2 AM. You need a visual dashboard.

A colleague says:

> "Install Grafana on monitor01. Point it at Prometheus. Import a dashboard. Make it look professional."

---

## Tasks

### Task 1: Install Grafana

Install Grafana on `monitor01`. The package name is `grafana`.

```bash
sudo apt install -y apt-transport-https software-properties-common
sudo wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt update && sudo apt install grafana
```

**Don't do this manually.** Create an Ansible role for it. You already know how.

### Task 2: Create a grafana role

Structure:
```
roles/grafana/
├── tasks/main.yml
├── handlers/main.yml
└── defaults/main.yml
```

Think about:
- What package to install
- What service to enable
- What port Grafana listens on (default: 3000)
- Whether you need to configure the Prometheus data source

### Task 3: Configure Prometheus as a data source

Grafana needs to know where Prometheus is. You can configure this via:
- Ansible template for `/etc/grafana/provisioning/datasources/prometheus.yml`
- Or via the Grafana UI (but that's not idempotent)

The data source URL should be `http://localhost:9090` since Prometheus runs on the same host.

### Task 4: Add the role to your playbook

Add a `grafana` play targeting `monitor01`:

```yaml
- name: Install Grafana
  hosts: monitoring
  become: true
  roles:
    - grafana
```

### Task 5: Run the playbook

```bash
ansible-playbook first-playbook.yml
```

Verify Grafana is running:

```bash
ssh monitor01 "systemctl status grafana-server"
```

### Task 6: Access Grafana

Open `http://192.168.122.40:3000` in your browser.

Default credentials:
- Username: `admin`
- Password: `admin`

You'll be prompted to change the password.

### Task 7: Import a Node Exporter dashboard

Go to Dashboards → Import → Enter dashboard ID `1860` (Node Exporter Full).

This is the most popular Node Exporter dashboard. It shows:
- CPU usage
- Memory usage
- Disk I/O
- Network traffic
- System load

### Task 8: Update the firewall

Grafana listens on port 3000. You need to allow access from your laptop (or the bastion).

Add a firewall rule:
```yaml
- name: Allow Grafana from bastion
  community.general.ufw:
    rule: allow
    src: "{{ firewall_bastion_ip }}"
    port: "3000"
    proto: tcp
  when: inventory_hostname == "monitor01"
```

Or allow from the entire lab network if you prefer.

---

## What You're Learning

- Installing software with Ansible (package + service + config)
- Grafana as a visualization layer on top of Prometheus
- Dashboard provisioning (importing pre-built dashboards)
- Data source configuration
- Firewall management for new services

## Verification

1. `ansible-playbook first-playbook.yml` completes without errors
2. `grafana-server` service is running on monitor01
3. Grafana UI accessible at `http://192.168.122.40:3000`
4. Prometheus data source is configured and working
5. Node Exporter dashboard shows live data from web01 and storage01
6. `ansible-lint` still passes

## Deliverables

When you're done, show me:
1. Your `roles/grafana/` structure
2. Output of `ansible-playbook first-playbook.yml`
3. Screenshot or description of the Grafana dashboard
4. Any problems you ran into and how you solved them
