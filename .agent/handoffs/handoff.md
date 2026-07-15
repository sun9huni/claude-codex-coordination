# Handoff Checklist

Run this checklist before ending a session, before context exhaustion,
or before switching agents.

## Trigger conditions

Hand off when any of these is true:

- Session context budget below ~20%.
- Switching from Cursor / Claude / Codex to another agent.
- Pausing for human review or approval gate.
- Long-running job (SLURM, MMGBSA, ensemble run) needs to outlive the
  current chat.

## Required artifacts

The per-slice working state lives in `.agent/status/<slice>.md`. The
derived index lives under `.agent/handoffs/`:

- `.agent/status/<slice>.md` — frontmatter updated, never empty placeholders.
- `.agent/handoffs/CURRENT.md` — regenerated derived index.

Run `./scripts/handoff.sh <next-agent> <slice>` to claim/refresh the
slice frontmatter, then `./scripts/status.sh index` to regenerate
`CURRENT.md`. `CURRENT.md` is the lab-wide index, never filled by hand.

Historical `state/` snapshots may exist from legacy/no-slice handoffs.
Treat them as supporting evidence, not as the current per-slice baton.

## `.agent/status/<slice>.md` frontmatter fields that MUST be filled

- `owner_session` (the session id claiming this slice)
- `owner_label` (human-readable label for the owning session)
- `owner_agent` (the agent finishing the turn)
- `version` (bump on each update)
- `last_updated` (today, ISO date)
- `heartbeat` (timestamp proving the owner session is live)
- `remaining_actions`: exactly 1–3 concrete steps
- `contract_pointers` (open contracts under `.agent/contracts/`, or empty)

The Markdown body still carries the human-readable detail: goal (one
paragraph, observable), current status, files touched this session (real
paths, not placeholders), verification run (command + result, or "not
run" with reason), failure / error log location (or "n/a"), and approval
required (or "none").

## Forbidden at handoff time

- Uncommitted destructive ops (rm -rf, db drops) left dangling.
- Background jobs you cannot point at by PID, SLURM id, or log path.
- "See chat above" — chat is not durable. Inline it.
- Empty placeholders left as `<...>` in the slice's `.agent/status/<slice>.md`.

## Archive policy

When a handoff is consumed, the new owner may move the prior slice
`.agent/status/<slice>.md` and any matching legacy `state/` snapshot into
`.agent/handoffs/archive/YYYY-MM-DD-HHMM-<agent>/`.
Keep the most recent 10. Older snapshots can be deleted unless they
correspond to an open contract under `.agent/contracts/`.
