# `nfs_server`

Configures an NFSv4 server and its exports.

## What it does

Installs the NFS server package and templates `/etc/exports`. Exports are reloaded via
`exportfs -ra` through a handler, so the service is not restarted unnecessarily.

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `nfs_server_nfs_export_root` | `/srv/storage` | Parent directory for all exports |
| `nfs_server_nfs_exports` | `shared`, `projects` | List of `{path, network, options}` export definitions |

## Dependencies

Pair with the `identity` role so UIDs match on clients.

## Example

```yaml
- name: Configure nfs_server
  hosts: storage
  become: true
  roles:
    - nfs_server
```
