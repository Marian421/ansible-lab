# `nfs_client`

Mounts NFS exports and persists them in `/etc/fstab`.

## What it does

Uses `ansible.posix.mount` with `state: mounted`, which creates the mount point and writes the
`fstab` entry in one step.

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `nfs_client_nfs_server` | `storage01` | Host serving the exports. The lab sets the full DNS name `storage01.dev.lab.test` in `group_vars/lab.yml`: a one-word name is not resolved by the VMs |
| `nfs_client_nfs_mounts` | `shared`, `projects` | List of `{name, export, mount_point}` |

## Dependencies

Requires `nfs_server` on the target server and matching UIDs via `identity`.

## Example

```yaml
- name: Configure nfs_client
  hosts: nfs_clients
  become: true
  roles:
    - nfs_client
```
