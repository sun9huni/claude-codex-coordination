---
name: handoff
description: Update your slice's .agent/status/<slice>.md baton and run scripts/handoff.sh to claim/refresh it (the derived CURRENT.md index regenerates automatically). Use at end of session, near context limit (< 20%), before switching agents, before a long-running job that must outlive the chat, or before any approval gate.
argument-hint: "[optional one-line note to include in session-note.md]"
allowed-tools: Read Edit Write Bash(./scripts/handoff.sh:*) Bash(./scripts/status.sh:*) Bash(cat:*) Bash(stat:*)
---

# /handoff — Session handoff

The next agent (Claude / Codex / Cursor / next-session) cannot see this
chat. State must live in files. This skill produces the durable record.

## Step 1 — Read current state

Read your slice's `.agent/status/<slice>.md` baton (the authoritative
per-slice state; the slice IS the filename). Read
`.agent/handoffs/handoff.md` for the canonical field list. The
`.agent/handoffs/CURRENT.md` index is DERIVED — never hand-edit it.

## Step 2 — Fill or update the slice baton

These yaml frontmatter fields MUST be present in
`.agent/status/<slice>.md` (no `<placeholder>`; schema in
`.agent/status/README.md`):

```yaml
---
owner_session: <session UUID — handoff.sh fills this>
owner_label: <free-form, may be empty>
owner_agent: <claude|codex|cursor|human>
version: <int — handoff.sh bumps this>
last_updated: <today, ISO date>
heartbeat: <ISO timestamp — handoff.sh refreshes this>
state: <active|closed|released>
remaining_actions:
  - "1-3 concrete next actions"
contract_pointers: []
---
```

In the Markdown body below the frontmatter:
- **Goal** — one paragraph, observable, what success looks like.
- **Current status** — concrete state: done / mid-flight.
- **Files touched this session** — real paths.
- **Verification run** — exact command + result, or "not run" + reason.
- **Failure / error log location** — absolute path, or "n/a".
- **Memory / contract pointers** — paths to relevant `.agent/contracts/*`.

If the user supplied `$ARGUMENTS`, append it to
`.agent/handoffs/state/session-note.md` (create the file if missing).

## Step 3 — Run handoff.sh

```bash
./scripts/handoff.sh <next-agent> <slice>     # claim / refresh
./scripts/handoff.sh --release <slice>        # done with the slice
```

`<next-agent>` is one of `claude` / `codex` / `cursor` / `human`. The
script claims the baton (owner_session / heartbeat / version), then
regenerates the derived CURRENT.md index and reports baton drift for
you. No-slice mode (`./scripts/handoff.sh <next-agent>`) additionally
snapshots git state under `.agent/handoffs/state/` — use it for
lab-wide handoffs.

## Step 4 — Verify

Confirm:
- Your `.agent/status/<slice>.md` frontmatter shows today's date and a
  fresh heartbeat.
- The regenerated `.agent/handoffs/CURRENT.md` row for your slice shows
  your owner_session.
- No stderr warnings from `handoff.sh` or the Stop hook.

Report one line to the user: `handoff written, next: <first remaining action>`.

## Red Flags

| Rationalization | Reality |
|---|---|
| "See chat above for context." | Chat is not durable. Inline the facts the next agent needs. |
| "I'll fill in placeholders later." | Now. `handoff.sh`'s stale-placeholder warning exists for this exact case. Leave none. |
| "Owner agent: claude is the default — skip it." | Explicit owner prevents takeover-prompt.md ambiguity. Always set. |
| "version: 0 is fine, I didn't really change anything." | If you ran any tool calls this session, state changed. handoff.sh bumps the baton version; the Stop hook flags sessions that end without it. |
| "Files touched: the diff shows it." | The diff shows lines, not semantic groupings. List paths grouped by area when many. |
| "Approval required: n/a for now, I'll update if needed." | If a gate is pending (deploy, DB, long-running job), name it now. The next agent acts on this list. |
| "Verification: tests pass." | Cite the exact command + outcome ("`pytest -q` 47 passed in 12s"), or "not run" with reason. "Tests pass" without a command is unverifiable. |

## Forbidden

- Do NOT write "see chat above" — inline the relevant facts.
- Do NOT leave `<...>` placeholders in the slice baton
  (`.agent/status/<slice>.md`).
- Do NOT hand-edit `.agent/handoffs/CURRENT.md` — it is a derived
  index; `status.sh index` overwrites hand-edits silently.
- Do NOT commit handoff state files to project repos — they belong to
  the workspace coordination layer.
