# `grafana_apt_repo`

Adds the Grafana APT repository (`apt.grafana.com`) and its signing key.

## What it does

Downloads Grafana's signing key into `/etc/apt/keyrings/` and adds one `signed-by=` source line
in `/etc/apt/sources.list.d/grafana.list`. It is the only place in this repository that defines
that source. `grafana` and `alloy` both install packages from it and list this role as a
dependency in their `meta/main.yml`.

Before this role existed, each of those two roles added the repository itself, with a different
key file. On `monitor01`, which runs both, apt found one source signed by two keys and refused
to read any sources at all.

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `grafana_apt_repo_key_url` | `https://apt.grafana.com/gpg.key` | Signing key to download |
| `grafana_apt_repo_keyring_dir` | `/etc/apt/keyrings` | Directory for locally added keys |
| `grafana_apt_repo_keyring_file` | `/etc/apt/keyrings/grafana.asc` | Key file, referenced by `signed-by=` |
| `grafana_apt_repo_url` | `https://apt.grafana.com` | Repository URL |

## Dependencies

None. Used as a dependency by `grafana` and `alloy`.

## Example

```yaml
# roles/<role>/meta/main.yml
dependencies:
  - role: grafana_apt_repo
```
