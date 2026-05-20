# Handoff Checklist

Run this checklist before ending a session, before context exhaustion,
or before switching agents.

## Trigger conditions

Hand off when any of these is true:

- Session context budget below ~20%.
- Switching from one agent (Claude / Codex / Cursor) to another.
- Pausing for human review or approval gate.
- Long-running job (HPC, training, batch) needs to outlive the
  current chat.

## Required CURRENT.md frontmatter

```yaml
---
owner_agent: <claude|codex|cursor|human>
last_updated: <today, ISO date — e.g. 2026-05-20>
active_slice: <slice-name from WORKFLOW.md §1>
remaining_actions:                  # 1-3 items
  - "first concrete next step"
  - "..."
schema_version: 1
---
```

Optional but recommended: `session_title`, `files_touched_count`,
`verification_run`, `verification_result`, `failure_log`,
`prior_slice_archive`, `approval_required`, `contract_pointers`.

## Required Markdown body sections

- **Goal** — one paragraph, observable.
- **Current status** — concrete state.
- **Files touched this session** — real paths.
- **Verification run** — command + result, or "not run" + reason.
- **Failure / error log location** — absolute path or "n/a".
- **Memory / contract pointers** — paths.

## Forbidden at handoff time

- Uncommitted destructive ops left dangling (rm -rf, db drops).
- Background jobs you cannot point at by PID, job ID, or log path.
- "See chat above" — chat is not durable. Inline what matters.
- Empty `<...>` placeholders in CURRENT.md.

## After CURRENT.md is updated

Run:

```bash
./scripts/handoff.sh <next-agent>
```

This writes:

- `.agent/handoffs/state/git-status.txt`
- `.agent/handoffs/state/git-log.txt`
- `.agent/handoffs/state/diff.patch`
- `.agent/handoffs/state/diff-staged.patch`
- `.agent/handoffs/state/session-note.md`  (if missing)
- `.agent/handoffs/state/meta.txt`

It also prints a stale-placeholder warning if any `<...>` remain in
CURRENT.md.

## Archive policy

When a handoff is fully consumed (its remaining_actions are done) and
you are starting a new chapter, the new owner may move the prior
`CURRENT.md` and matching `state/` snapshot to
`.agent/handoffs/archive/YYYY-MM-DD-HHMM-<agent>-<topic>/`. Keep the
most recent ~10. Older snapshots can be deleted unless they
correspond to an open contract.
