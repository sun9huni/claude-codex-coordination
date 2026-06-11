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

## Required per-slice baton frontmatter (`.agent/status/<slice>.md`)

```yaml
---
owner_session: <auto UUID, set by handoff.sh>
owner_label: <optional, e.g. dev-a — may be empty>
owner_agent: <claude|codex|cursor|human>
version: <integer, bumped by handoff.sh>
last_updated: <today, ISO date>
heartbeat: <ISO timestamp, set by handoff.sh>
remaining_actions:                  # 1-3 items
  - "first concrete next step"
  - "..."
contract_pointers:
  - .agent/contracts/<slice>-<topic>-<YYYYMMDD>.md
---
```

Optional but recommended: `session_title`, `files_touched_count`,
`verification_run`, `verification_result`, `failure_log`,
`prior_slice_archive`, `approval_required`.

The `version`, `owner_session`, and `heartbeat` fields are managed by
`./scripts/handoff.sh <agent> <slice>` — you do not edit them by hand.
`version` increments on every successful claim and is used by the Stop
hook to detect "agent did not run /handoff this session"; `heartbeat`
and `owner_session` record who currently owns the slice.

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
- Empty `<...>` placeholders in your `status/<slice>.md` baton.

## After your slice baton is updated

Run, in order:

```bash
./scripts/handoff.sh <next-agent> <slice>   # refreshes the slice baton frontmatter
./scripts/status.sh index                   # regenerates the derived CURRENT.md index
```

The first command claims the slice and refreshes its
`status/<slice>.md` frontmatter (owner/heartbeat/version). The second
regenerates the derived `CURRENT.md` index — never hand-edited.

Since v0.4.2 `handoff.sh` already runs the index regen for you (on both
the claim and `--release` paths) and surfaces any baton drift, so the
explicit `status.sh index` is now a belt-and-suspenders step you can
skip when you just ran `handoff.sh`.

The git-snapshot files below are written by the plain no-slice mode
(`./scripts/handoff.sh <agent>`, no slice argument):

- `.agent/handoffs/state/git-status.txt`
- `.agent/handoffs/state/git-log.txt`
- `.agent/handoffs/state/diff.patch`
- `.agent/handoffs/state/diff-staged.patch`
- `.agent/handoffs/state/session-note.md`  (if missing)
- `.agent/handoffs/state/meta.txt`

The Stop hook flags any `<...>` placeholder left in your
`status/<slice>.md` baton frontmatter on the way out.

## Archive policy

When a handoff is fully consumed (its remaining_actions are done) and
you are starting a new chapter, the new owner may move the prior
`CURRENT.md` and matching `state/` snapshot to
`.agent/handoffs/archive/YYYY-MM-DD-HHMM-<agent>-<topic>/`. Keep the
most recent ~10. Older snapshots can be deleted unless they
correspond to an open contract.
