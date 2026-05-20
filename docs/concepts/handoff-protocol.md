# Handoff protocol

Sessions are not durable. Files are. The handoff is how state
survives the gap between sessions and the swap between agents.

## The contract

At the end of a session, the outgoing agent leaves:

1. A complete `.agent/handoffs/CURRENT.md` with valid yaml
   frontmatter and a populated markdown body.
2. A snapshot under `.agent/handoffs/state/` (git status, diff,
   log, optional session-note).

At the start of the next session, the incoming agent:

1. Reads `CURRENT.md`.
2. If `owner_agent ≠ self`, runs the takeover protocol
   (`.agent/handoffs/takeover-prompt.md` steps 4-7).
3. Acts.

That's the contract. Everything else is mechanism.

## What lives in the frontmatter vs body

The frontmatter is **machine-readable**:
- `owner_agent` — who finished the last session.
- `last_updated` — ISO date; Stop hook warns if > 7 days.
- `active_slice` — which slice the work belongs to.
- `remaining_actions` — list of 1-3 concrete next steps.
- Optional metadata: `session_title`, `verification_run`,
  `failure_log`, `approval_required`, `contract_pointers`, etc.

The body is **human-readable**:
- Goal in one paragraph.
- Current status (done / in flight, concrete).
- Files touched this session (real paths).
- Verification command and result.
- Failure log paths.
- Memory / contract pointers.

Both must stay consistent. The Stop hook validates the frontmatter
but cannot validate the body — that's on you.

## Why yaml frontmatter

- Machine-parseable by `python3 -c "import yaml; ..."` or `yq`.
- Codex/Cursor without yaml awareness still read the markdown body
  unchanged (backward compatible).
- Schema validation catches "I forgot to set the date" cases at
  Stop time, not at the next session's start (faster feedback loop).

## scripts/handoff.sh

Captures the bits that depend on git state, which the agent cannot
inline reliably:

- `state/git-status.txt` — `git status --short`.
- `state/git-log.txt` — last 10 commits.
- `state/diff.patch` — working tree diff.
- `state/diff-staged.patch` — staged diff.
- `state/meta.txt` — timestamp, agent, host.
- `state/session-note.md` — free-form notes (created empty).

These let the next agent verify "what does the prior agent claim
matches what git shows".

## Crossing agent boundaries (Claude ↔ Codex ↔ Cursor ↔ human)

- All three coding agents read `.agent/handoffs/CURRENT.md`.
- `takeover-prompt.md` is the canonical instruction to paste into
  the next agent.
- The 3-step ritual at the top of `takeover-prompt.md` matches the
  one in `CLAUDE.md` and `WORKFLOW.md §0` (steps 1-3). Steps 4-7
  are the takeover extension.

## Forbidden at handoff

- "See chat above" — chat is gone.
- Background jobs without a PID / log / job ID pointer.
- `<...>` placeholders left in CURRENT.md.
- Destructive ops "left to do" — finish them or document the
  rollback.

## Archive policy

When a CURRENT.md chapter is complete (its `remaining_actions` are
done) and you start something new, move the consumed CURRENT.md +
state into `.agent/handoffs/archive/YYYY-MM-DD-HHMM-<agent>-<topic>/`.
Keep the most recent ~10 archive entries; older ones can be deleted
unless they correspond to an open contract.
