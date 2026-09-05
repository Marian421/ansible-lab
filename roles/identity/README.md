# `identity`

Manages users and groups with fixed UIDs/GIDs across every host.

## What it does

NFS matches identity by **numeric UID/GID**, not by username. If UIDs drift between the server
and its clients, file ownership silently breaks. This role pins them so identity is consistent
fleet-wide.

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `identity_groups` | `developers` (gid 1003) | Groups to create, with explicit GIDs |
| `identity_users` | 4 users, uid 1001–1004 | Regular users, with explicit UIDs |
| `identity_system_users` | `healthcheck` (uid 1100) | System accounts (`nologin`, no home) |

## Dependencies

None.

## Example

```yaml
- name: Configure identity
  hosts: lab
  become: true
  roles:
    - identity
```
