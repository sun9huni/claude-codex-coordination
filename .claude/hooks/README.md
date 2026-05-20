# Hooks (enforcement layer)

Hooks turn workspace policies from prose into enforced behavior. Each
script receives the Claude Code hook event as JSON on stdin. Exit 0 =
allow / exit 2 = block. Stderr is fed back to Claude on block.

## Core hooks (enabled by default)

| Hook | Event | Purpose |
|---|---|---|
| `session-start-decay-check.sh` | `SessionStart` | Warn if `CURRENT.md` is older than 24h or a `.agent/status/<slice>.md` is older than 7d. Also catches `project_*` memory leak regressions. Non-blocking. |
| `pre-bash-destructive-gate.sh` | `PreToolUse` (Bash) | Block `rm -rf` on shared / harness dirs, `git push --force`, `git reset --hard origin/...`, `git branch -D`. Fail-closed if `jq` is missing. |
| `pre-compact-inject.sh` | `PreCompact` | Emit the current `CURRENT.md` content so workspace state survives context compaction. Non-blocking. |
| `stop-handoff-check.sh` | `Stop` | Validate `.agent/handoffs/CURRENT.md` yaml frontmatter against schema_version 1 (stdlib-only fallback if PyYAML missing). Compares CURRENT.md `version` against last snapshot to detect "agent forgot to /handoff". Non-blocking. |

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
| `optional/post-edit-format.sh` | `PostToolUse` (Edit\|Write\|MultiEdit) | Auto-format files after edit. Ships with `ruff format` for Python, prettier for JS/TS/JSON/MD/YAML, shfmt for shell — runs only if the formatter is installed. Always exit 0 (productive, never blocks). |

## Matching policy (all blocking hooks)

- Every blocking pattern is anchored to look like a real shell command
  (start-of-string or after `;`, `&&`, `||`, `|`, newline) so keywords
  inside quoted arguments do not trip the hook.
- Heredoc bodies are stripped before matching (`${cmd%%<<*}`) so
  commit messages and other heredoc payloads do not cause false
  positives.

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
