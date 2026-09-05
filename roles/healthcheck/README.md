# `healthcheck`

Deploys a periodic system health check as a systemd timer.

## What it does

Installs a Jinja2-templated health-check script that verifies disk usage, inode usage, load
average, service status and (on NFS clients) mount health. Runs as a dedicated system user
with a `nologin` shell. Results go to the journal: `journalctl -u lab-healthcheck`.

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `healthcheck_user` | `healthcheck` | System user the script runs as |
| `healthcheck_script` | `/usr/local/bin/lab-healthcheck.sh` | Script destination |
| `healthcheck_service` | `lab-healthcheck.service` | Oneshot unit name |
| `healthcheck_timer` | `lab-healthcheck.timer` | Timer unit name (5-minute interval) |

## Dependencies

Defined in `group_vars/lab.yml`.

## Example

```yaml
- name: Configure healthcheck
  hosts: lab
  become: true
  roles:
    - healthcheck
```
