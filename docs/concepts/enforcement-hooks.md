# Enforcement hooks

Hooks are how prose policies become actual blocks. Without them,
"approve before X" is a hope; with them, it's a `exit 2`.

## How Claude Code hooks work

Three event types matter:

- `SessionStart` — fires once when the session begins.
- `PreToolUse` — fires before every tool invocation, with the tool
  call as JSON on stdin. Exit 2 blocks the call and feeds stderr
  back to Claude.
- `Stop` — fires when the session is about to end.

(There are others — `PostToolUse`, `UserPromptSubmit`,
`SessionEnd` — but the three above cover most enforcement needs.)

Registration is in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "./.claude/hooks/foo.sh" }
        ]
      }
    ]
  }
}
```

## What this template ships

| Hook | Event | Blocks? | Purpose |
|---|---|---|---|
| `session-start-decay-check.sh` | SessionStart | No | Warn on stale state |
| `pre-bash-destructive-gate.sh` | PreToolUse[Bash] | Yes | rm -rf on shared / harness dirs, force pushes, hard resets |
| `stop-handoff-check.sh` | Stop | No | Validate CURRENT.md frontmatter schema |
| `optional/pre-bash-slurm-gate.sh` | PreToolUse[Bash] | Yes | sbatch without active contract |
| `optional/pre-bash-db-gate.sh` | PreToolUse[Bash] | Yes | psql DDL |

## Matching policy — the two rules

Both rules are about avoiding false positives, which would train you
to ignore the hooks.

**Rule 1: anchor the pattern to a real command position.**

A naive regex like `[[ "$cmd" =~ rm -rf /mnt/data ]]` will match
inside quoted strings (e.g. `git commit -m "fix rm -rf /mnt/data
bug"`). All hooks here use an anchor:

```
(^|[[:space:]]*\;|\&\&|\|\||\|[[:space:]]|<newline>)[[:space:]]*(sudo[[:space:]]+)?
```

This forces the dangerous token to be at start-of-string or right
after a shell separator. It does not understand quotes, but combined
with Rule 2 it covers the common cases.

**Rule 2: strip heredoc bodies.**

The agent commonly runs commands like:

```bash
git commit -m "$(cat <<'EOF'
fix: handle DROP TABLE edge case
EOF
)"
```

The hook receives the entire command including the heredoc body. To
avoid matching keywords in the body:

```bash
cmd_check="${cmd%%<<*}"
```

Now only the part before the first `<<` is scanned. Heredoc payloads
(commit messages, docs, multi-line string args) are excluded.

## Writing a new blocking hook

```bash
#!/usr/bin/env bash
set -uo pipefail

input=$(cat)
[ "$(jq -r '.tool_name // ""' <<< "$input")" = "Bash" ] || exit 0
cmd=$(jq -r '.tool_input.command // ""' <<< "$input")
cmd_check="${cmd%%<<*}"

ANCHOR='(^|[[:space:]]*\;|\&\&|\|\||\|[[:space:]]|'$'\n'')[[:space:]]*(sudo[[:space:]]+)?'

if [[ "$cmd_check" =~ ${ANCHOR}your-binary[[:space:]] ]] && \
   [[ "$cmd_check" =~ <your dangerous pattern> ]]; then
    {
        echo "BLOCKED: <reason>"
        echo "Detected command: $cmd"
    } >&2
    exit 2
fi

exit 0
```

Then register in `.claude/settings.json`.

## Testing a hook

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"sbatch x.sh"}}' \
  | bash .claude/hooks/pre-bash-slurm-gate.sh
echo "exit: $?"
```

When writing the test JSON inline, beware: if the outer command
contains the dangerous keyword, your *own* hooks may block your test
runner. Either write the JSON to a file first:

```bash
cat > /tmp/test.json <<'JSON'
{"tool_name":"Bash","tool_input":{"command":"sbatch x.sh"}}
JSON
bash .claude/hooks/pre-bash-slurm-gate.sh < /tmp/test.json
```

Or use `jq -nc` to construct the JSON without echoing the dangerous
keyword in the outer command.

## What blocking hooks cannot do

- Stop a command launched by another process.
- Parse shell syntax exactly. They are heuristics. A determined
  agent can construct command lines that bypass them (variable
  expansion, base64 decode, etc.). The point is to catch *accidents*,
  not *attacks*.
- Replace the human review for truly destructive ops. Even with the
  hook, the user should be in the loop for high-blast-radius
  operations.
