# Claude-Native Hooks

Hooks turn workspace policies from prose into enforced behavior. Each
script receives the Claude Code hook event as JSON on stdin and exits
**0 to allow** / **2 to block** (per Claude Code hook protocol). Stderr
is fed back to Claude on block.

| Hook | Event | Purpose |
|---|---|---|
| `session-start-decay-check.sh` | `SessionStart` | Warn about stale `CURRENT.md` / `.agent/status/*` + `project_*` memory leak; warn on a contested slice (fresh heartbeat under a different `owner_session` when `ENTERING_SLICE` is set); inject per-slice bootstrap context. Non-blocking. |
| `pre-bash-slurm-gate.sh` | `PreToolUse` (Bash) | Block `sbatch` submission unless a contract was modified in the last 7 days under `.agent/contracts/`. |
| `pre-bash-destructive-gate.sh` | `PreToolUse` (Bash) | Block `rm -rf` on `/mnt/data` or harness dirs, force pushes, `git reset --hard origin/...`, `git branch -D`. |
| `pre-bash-db-gate.sh` | `PreToolUse` (Bash) | Block `psql` containing DDL (`DROP TABLE/DATABASE/SCHEMA`, `TRUNCATE`, `ALTER TABLE`). |
| `stop-handoff-check.sh` | `Stop` | Validate the active slice's `.agent/status/<slice>.md` frontmatter (per-slice schema + `<...>` placeholder scan); warn if stale/invalid. Non-blocking. |

Registered in `/home/ubuntu/.claude/settings.json` under `hooks`.

To test a hook locally:
```bash
echo '{"tool_name":"Bash","tool_input":{"command":"sbatch test.sh"}}' \
  | bash /home/ubuntu/.claude/hooks/pre-bash-slurm-gate.sh
echo "exit: $?"
```
