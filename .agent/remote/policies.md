# Remote SSH Policies

These policies apply before Codex runs commands on any SSH server.

## Default Mode

- Treat unknown servers as read-only.
- Prefer SSH config aliases over raw hostnames.
- Use explicit repo paths.
- Run status and verification commands before making changes.
- Record important remote findings in `.agent/remote/bootstrap-log.md` or the task contract.

## Approval Required

Stop and ask before:

- production service restart
- DB migration
- destructive file operation
- `sudo` command
- firewall, SSH, nginx, systemd, Docker Compose, or Kubernetes changes
- secret or environment variable changes
- external data transfer
- package upgrade on production

## Command Discipline

- Prefer `pwd`, `uname -a`, `git status --short`, `git rev-parse --abbrev-ref HEAD`, and `./scripts/verify.sh` for first inspection.
- Use dry-run flags where available.
- Do not run long-lived processes without a plan for stopping them.
- Do not leave SSH tunnels or background processes running without recording them.

## Browser QA Over SSH

For web apps on a remote server:

1. Confirm the app is listening on the expected remote port.
2. Open a local tunnel with `ssh -L <local-port>:127.0.0.1:<remote-port> <alias>`.
3. Run Chrome QA against `http://127.0.0.1:<local-port>`.
4. Close the tunnel when done.
