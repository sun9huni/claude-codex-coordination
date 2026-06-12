# Handoff protocol

Sessions are not durable. Files are. The handoff is how state
survives the gap between sessions and the swap between agents.

## The contract

At the end of a session, the outgoing agent leaves:

1. An updated `.agent/status/<slice>.md` baton — the authoritative
   per-slice state — with valid yaml frontmatter and a populated
   markdown body, claimed via `./scripts/handoff.sh <agent> <slice>`
   (or released via `--release <slice>` when the slice is done).
2. A regenerated `.agent/handoffs/CURRENT.md` — the DERIVED lab-wide
   index. `handoff.sh` regenerates it for you; it is never hand-edited
   (hand-edits are silently overwritten — the SessionStart hook
   re-runs `status.sh index` at the next session start).
3. For lab-wide (no-slice) handoffs: a snapshot under
   `.agent/handoffs/state/sessions/<ts>-<agent>/` (git status, diff,
   log, optional session-note), with `state/latest` pointing at it.

At the start of the next session, the incoming agent:

1. Reads the `CURRENT.md` index, then its slice's
   `.agent/status/<slice>.md` baton.
2. If the baton's `owner_agent ≠ self` (or the heartbeat is fresh
   under a different `owner_session`), runs the takeover protocol
   (`.agent/handoffs/takeover-prompt.md` steps 4-7).
3. Acts.

That's the contract. Everything else is mechanism.

## What lives in the frontmatter vs body

The baton frontmatter is **machine-readable** (schema:
`.agent/status/README.md`):
- `owner_session` / `owner_label` — which live session holds the lease.
- `owner_agent` — who finished the last session.
- `version` — bumped by every `handoff.sh` run.
- `last_updated` — ISO date; Stop hook warns if > 7 days.
- `heartbeat` — ISO timestamp; fresh (≤30 min) means a live claim.
- `state` — `active` | `closed` | `released`.
- `remaining_actions` — list of 1-3 concrete next steps.
- `contract_pointers` — paths into `.agent/contracts/`.

(The slice itself IS the filename — there is no `active_slice` field.)

The body is **human-readable**:
- Goal in one paragraph.
- Current status (done / in flight, concrete).
- Files touched this session (real paths).
- Verification command and result.
- Failure log paths.
- Memory / contract pointers.

Both must stay consistent. The Stop hook validates the frontmatter of
every claimed baton but cannot validate the body — that's on you.

## Why yaml frontmatter

- Machine-parseable by `python3 -c "import yaml; ..."` or `yq`.
- Codex/Cursor without yaml awareness still read the markdown body
  unchanged (backward compatible).
- Schema validation catches "I forgot to set the date" cases at
  Stop time, not at the next session's start (faster feedback loop).

## scripts/handoff.sh

In slice mode (`handoff.sh <agent> <slice>`), claims/refreshes exactly
the baton's owner/version/timestamp fields, preserves everything else
verbatim, then regenerates the index and reports baton drift.

In no-slice mode, it additionally captures the bits that depend on git
state, which the agent cannot inline reliably:

- `state/sessions/<ts>-<agent>/git-status.txt` — `git status --short`.
- `.../git-log.txt` — last 10 commits.
- `.../diff.patch` — working tree diff.
- `.../diff-staged.patch` — staged diff.
- `.../meta.txt` — timestamp, agent, host.
- `.../session-note.md` — free-form notes (created empty).
- `state/latest` — symlink to the newest snapshot (keeps 20).

These let the next agent verify "what does the prior agent claim
matches what git shows".

## Crossing agent boundaries (Claude ↔ Codex ↔ Cursor ↔ human)

- All three coding agents read the `CURRENT.md` index, then the
  per-slice batons it points at.
- `takeover-prompt.md` is the canonical instruction to paste into
  the next agent.
- The 3-step ritual at the top of `takeover-prompt.md` matches the
  one in `CLAUDE.md` and `WORKFLOW.md §0` (steps 1-3). Steps 4-7
  are the takeover extension.

## Forbidden at handoff

- "See chat above" — chat is gone.
- Background jobs without a PID / log / job ID pointer.
- `<...>` placeholders left in the slice baton.
- Hand-editing `CURRENT.md` — it is a derived index.
- Destructive ops "left to do" — finish them or document the
  rollback.

## Archive policy

When a slice is complete (its `remaining_actions` are done), release
it: `./scripts/handoff.sh --release <slice>` clears the lease and sets
`state: released` while preserving the baton's history. Batons for
abandoned work can be set to `state: closed` by hand. Released/closed
batons stay in `.agent/status/` (the index marks them 📦/🔒); delete
them only when no open contract references them.
