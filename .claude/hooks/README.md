# Hooks (enforcement layer)

Hooks turn workspace policies from prose into enforced behavior. Each
script receives the Claude Code hook event as JSON on stdin. Exit 0 =
allow / exit 2 = block. Stderr is fed back to Claude on block.

## Core hooks (enabled by default)

| Hook | Event | Purpose |
|---|---|---|
| `session-start-decay-check.sh` | `SessionStart` | **Dual job**: (a) stderr warnings on stale `CURRENT.md` (>24h), stale `.agent/status/<slice>.md` (>7d), and `project_*` memory leak regressions. (b) stdout JSON `hookSpecificOutput.additionalContext` injecting the live workspace bootstrap (CURRENT.md frontmatter + detected skills + enabled gates + productive-hook presence + memory policy) into the session context. Non-blocking. |
| `pre-bash-destructive-gate.sh` | `PreToolUse` (Bash) | Block `rm -rf` on shared / harness dirs, `git push --force`, `git reset --hard origin/...`, `git branch -D`. Fail-closed if `jq` is missing. |
| `pre-compact-inject.sh` | `PreCompact` | Emit the current `CURRENT.md` content so workspace state survives context compaction. Non-blocking. |
| `post-edit-format.sh` | `PostToolUse` (Edit\|Write\|MultiEdit) | **Productive** (not defensive): auto-format the touched file via `ruff format` / `prettier --write` / `shfmt -w` based on extension. Every formatter is optional — silent no-op if not installed. Always exit 0. |
| `stop-handoff-check.sh` | `Stop` | Validate claimed per-slice `.agent/status/<slice>.md` yaml frontmatter against the schema in `.agent/status/README.md` (owner_session, owner_agent, version, last_updated, heartbeat, remaining_actions; stdlib mini-parser fallback if PyYAML missing). Also warns on stale CURRENT.md mtime, on a legacy CURRENT.md `version` unchanged since the last snapshot, and on a session ending without `handoff.sh` (via the session-start marker). Non-blocking. |
| `session-end-cleanup.sh` | `SessionEnd` | Delete this session's start marker (written by the SessionStart hook; it must survive every Stop and is removed only when the session truly ends — markers leaked by crashed sessions are swept by the >7d prune at session start). Always exit 0. |

Registered in `../settings.json`.

Plus a `statusLine` running `../statusline.sh` which surfaces the
current model, active slice, CURRENT.md owner / version / age, and
context window %. Customize the format string in the script.

## Optional hooks (opt-in)

Under `optional/`. Copy to this directory and add to
`../settings.json` `hooks.PreToolUse[*].hooks[]` to enable.

| Hook | Event | Purpose |
|---|---|---|
| `optional/pre-bash-slurm-gate.sh` | `PreToolUse` (Bash) | Block `sbatch` submission unless a contract under `.agent/contracts/` was modified in the last 7 days. For HPC users. |
| `optional/pre-bash-db-gate.sh` | `PreToolUse` (Bash) | Block `psql ... DROP TABLE / TRUNCATE / ALTER TABLE`. For PostgreSQL users. |

## Matching policy (all blocking hooks)

- Every blocking pattern is anchored to look like a real shell command
  (start-of-string or after `;`, `&&`, `||`, `|`, newline) so keywords
  inside quoted arguments do not trip the hook.
- Heredoc and here-string *bodies* are stripped before matching (a
  python3 regex one-liner — see docs/concepts/enforcement-hooks.md,
  Rule 2) so commit messages and other heredoc payloads do not cause
  false positives, while commands *after* a heredoc are still scanned
  (a naive `${cmd%%<<*}` would discard those too — that was the
  pre-0.5.0 bypass). If python3 is unavailable the gates fall back to
  matching the raw command: fail closed (may false-positive, never
  false-negative).

## Adding a new hook

1. Write the script. Read JSON via `cat`, parse with `jq` (e.g.
   `jq -r '.tool_input.command' <<< "$input"`), exit 2 to block with
   a clear stderr message.
2. `chmod +x .claude/hooks/yourhook.sh`.
3. Register under the right event in `.claude/settings.json`.
4. Test with synthetic input:
   ```bash
   echo '{"tool_name":"Bash","tool_input":{"command":"..."}}' \
     | bash .claude/hooks/yourhook.sh
   ```

## Testing the existing hooks

```bash
# Should block (after enabling slurm gate, when no recent contract):
echo '{"tool_name":"Bash","tool_input":{"command":"sbatch x.sh"}}' \
  | bash .claude/hooks/pre-bash-slurm-gate.sh
echo "exit: $?"
```
