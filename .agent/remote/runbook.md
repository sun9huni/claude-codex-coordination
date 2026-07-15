# Remote SSH Runbook

## First Connection

```bash
ssh <alias> 'pwd && uname -a && git --version'
```

## Inspect Repo

```bash
ssh <alias> 'cd <repo-path> && pwd && git status --short && git rev-parse --abbrev-ref HEAD'
```

## Bootstrap Harness

```bash
./scripts/remote-bootstrap.sh <alias> <repo-path>
```

## Verify Remote Repo

```bash
./scripts/remote-verify.sh <alias> <repo-path>
```

## Tunnel Web App For Chrome QA

```bash
ssh -L 3000:127.0.0.1:<remote-port> <alias>
```

Then run browser QA locally against:

```text
http://127.0.0.1:3000
```

## Closeout

- record commands run
- record verify result
- record active tunnels or background processes
- record any manual approval received
- update the task contract or handoff
