# Remote Hosts

Use SSH config aliases. Do not store private keys, passwords, tokens, or production secrets here.

| Alias | Purpose | Environment | Repo path | Safe to modify | Notes |
| --- | --- | --- | --- | --- | --- |
| example-dev | development server | dev | `/srv/app` | yes | replace with real alias |
| example-prod | production server | prod | `/srv/app` | approval required | read-only by default |

## Required Host Facts

Record these in `bootstrap-log.md` after first connection:

- OS and version
- shell
- git version
- Node/Python/runtime versions
- package manager
- service manager
- repo branch
- verify command result

## SSH Usage

Prefer:

```bash
ssh <alias> 'cd /path/to/repo && ./scripts/verify.sh'
```

Avoid embedding hostnames, credentials, or secrets in repository files.
