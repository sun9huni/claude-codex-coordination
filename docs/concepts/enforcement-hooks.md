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
- `PreCompact` — fires before a long conversation is compacted; stdout
  is carried into the summarized context.

(There are others — `PostToolUse`, `UserPromptSubmit`,
`SessionEnd` — but the events above cover most enforcement needs.)

Registration is in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/foo.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

## What this template ships

| Hook | Event | Blocks? | Purpose |
|---|---|---|---|
| `session-start-decay-check.sh` | SessionStart | No | Regenerate the derived index, flag baton drift, warn on stale state |
| `pre-compact-inject.sh` | PreCompact | No | Carry the freshly-regenerated index + drift through compaction |
| `pre-bash-destructive-gate.sh` | PreToolUse[Bash] | Yes | rm -rf on shared / harness dirs, force pushes, hard resets |
| `stop-handoff-check.sh` | Stop | No | Validate CURRENT.md frontmatter schema |
| `session-end-cleanup.sh` | SessionEnd | No | Delete this session's start marker (leak prevention) |
| `optional/pre-bash-slurm-gate.sh` | PreToolUse[Bash] | Yes | sbatch without active contract |
| `optional/pre-bash-db-gate.sh` | PreToolUse[Bash] | Yes | psql DDL |

### Freshness (auto-index + baton-drift)

The derived `CURRENT.md` index only reflects the per-slice batons when
something runs `scripts/status.sh index`. To stop it (and any view
derived from it) from silently freezing when a session edits batons but
forgets the manual regen, three entry points regenerate it
automatically and surface `scripts/baton-drift.sh` findings:

- `session-start-decay-check.sh` (Job 0) — regenerate before the session
  reads state.
- `pre-compact-inject.sh` — regenerate before snapshotting into the
  compacted context.
- `handoff.sh` (claim **and** `--release` paths) — regenerate on every
  handoff.

`baton-drift.sh` is read-only and best-effort: it reports a baton whose
`heartbeat` is ≥ N days old (default 2), and — only where `sacct` is on
PATH (bash ≥ 4) — a baton still asserting a job is RUNNING that the
scheduler has finished. Empty output means no drift; it never exits
non-zero, so it can never fail a handoff.

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

The hook receives the entire command including the heredoc body. The
naive fix — `cmd_check="${cmd%%<<*}"` — has a hole: it throws away
*everything* after the first `<<`, including real commands that follow
the heredoc, so a harmless heredoc prefix could smuggle `rm -rf /data`
past the gate. The shipped gates instead strip only the heredoc /
here-string *bodies* and keep scanning what follows:

```bash
cmd_check=$(python3 -c 'import re,sys; s=sys.stdin.read(); s=re.sub(r"<<-?[ \t]*\\?([\"\x27]?)(\w+)\1([^\n]*\n).*?\n\2", r" \3", s, flags=re.S); s=re.sub(r"<<<\s*(\"[^\"]*\"|\x27[^\x27]*\x27|[^\s;&|]+)", " ", s); print(s)' <<< "$cmd" 2>/dev/null) || cmd_check="$cmd"
[ -n "$cmd_check" ] || cmd_check="$cmd"
```

Heredoc payloads (commit messages, docs, multi-line string args) are
excluded; commands *after* the heredoc are still matched. If python3 is
missing the gate falls back to scanning the raw command — fail closed:
body text may then false-positive (block), never false-negative.

## Writing a new blocking hook

```bash
#!/usr/bin/env bash
set -uo pipefail

input=$(cat)
[ "$(jq -r '.tool_name // ""' <<< "$input")" = "Bash" ] || exit 0
cmd=$(jq -r '.tool_input.command // ""' <<< "$input")
# Strip heredoc/here-string BODIES, keep commands that follow them
# (see "Rule 2" above for the python3 one-liner used by the shipped
# gates; fall back to the raw command if python3 is unavailable).
cmd_check=$(strip_heredoc_bodies <<< "$cmd") || cmd_check="$cmd"

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
