---
name: remote-harness
description: Use to install or operate the Codex harness on a remote SSH server, including bootstrap, verification, policies, and tunnel-based browser QA.
license: MIT
---

# Remote Harness

Use this skill when applying the Codex harness to an SSH-accessible server.

## Workflow

1. Read `.agent/remote/policies.md`.
2. Confirm the SSH alias and remote repo path.
3. Run read-only inspection commands first.
4. Bootstrap only missing harness files.
5. Run remote verification.
6. For web apps, open an SSH tunnel and run local Chrome QA.
7. Record results in `.agent/remote/bootstrap-log.md` or the task contract.

## Read-Only Inspection

```bash
ssh <alias> 'pwd && uname -a && git --version'
ssh <alias> 'cd <repo-path> && git status --short && git rev-parse --abbrev-ref HEAD'
```

## Bootstrap

```bash
./scripts/remote-bootstrap.sh <alias> <repo-path>
```

## Verify

```bash
./scripts/remote-verify.sh <alias> <repo-path>
```

## Guardrails

- Do not store secrets in the repo.
- Do not run `sudo` without explicit approval.
- Do not restart production services without explicit approval.
- Do not run DB migrations or destructive commands without explicit approval.
- Prefer dry-run, status, diff, and log collection before mutation.
