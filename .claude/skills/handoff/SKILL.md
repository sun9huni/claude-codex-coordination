---
name: handoff
description: Update .agent/handoffs/CURRENT.md and run scripts/handoff.sh to snapshot session state. Use at end of session, near context limit (< 20%), before switching agents, before a long-running job that must outlive the chat, or before any approval gate.
argument-hint: "[optional one-line note to include in session-note.md]"
allowed-tools: Read Edit Write Bash(./scripts/handoff.sh:*) Bash(cat:*) Bash(stat:*)
---

# /handoff — Session handoff

The next agent (Claude / Codex / Cursor / next-session) cannot see this
chat. State must live in files. This skill produces the durable record.

## Step 1 — Read current state

Read `.agent/handoffs/CURRENT.md` to see what is already filled in.
Read `.agent/handoffs/handoff.md` for the canonical field list.

## Step 2 — Fill or update CURRENT.md

These yaml frontmatter fields MUST be present (no `<placeholder>`):

```yaml
---
owner_agent: <claude|codex|cursor|human>
last_updated: <today, ISO date>
active_slice: <one of your defined slices>
remaining_actions:
  - "1-3 concrete next actions"
schema_version: 1
---
```

Optional but recommended:
`session_title`, `files_touched_count`, `verification_run`,
`verification_result`, `failure_log`, `prior_slice_archive`,
`approval_required`, `contract_pointers`.

In the Markdown body below the frontmatter:
- **Goal** — one paragraph, observable, what success looks like.
- **Current status** — concrete state: done / mid-flight.
- **Files touched this session** — real paths.
- **Verification run** — exact command + result, or "not run" + reason.
- **Failure / error log location** — absolute path, or "n/a".
- **Memory / contract pointers** — paths to relevant `.agent/contracts/*`
  and `.agent/status/*`.

If the user supplied `$ARGUMENTS`, append it to
`.agent/handoffs/state/session-note.md` (create the file if missing).

## Step 3 — Run handoff.sh

```bash
./scripts/handoff.sh <next-agent>
```

`<next-agent>` is one of `claude` / `codex` / `cursor` / `human`. The
script snapshots git state under `.agent/handoffs/state/`. Its
stale-placeholder warning will list any `<placeholder>` fields you
forgot.

## Step 4 — Verify

Confirm:
- `head -3 .agent/handoffs/CURRENT.md` shows today's date.
- `cat .agent/handoffs/state/meta.txt` shows the right `next_agent`.
- No stderr warnings from `handoff.sh` or the Stop hook.

Report one line to the user: `handoff written, next: <first remaining action>`.

## Forbidden

- Do NOT write "see chat above" — inline the relevant facts.
- Do NOT leave `<...>` placeholders in CURRENT.md.
- Do NOT commit handoff state files to project repos — they belong to
  the workspace coordination layer.
