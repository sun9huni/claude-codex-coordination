---
name: slice-status
description: Show the consolidated current state of one workspace slice. Combines the static .agent/status/<slice>.md, a live scan (project-specific helper if one exists, otherwise git status), and any project-repo git state. Use when entering or resuming work on a slice and want one view.
argument-hint: "<slice-name as defined in WORKFLOW.md §1>"
allowed-tools: Read Bash(./scripts/status.sh:*) Bash(cat:*) Bash(stat:*) Bash(git status:*) Bash(git log:*) Bash(git -C * status:*) Bash(git -C * log:*)
---

# /slice-status — Consolidated slice view

Compare three independent sources for the slice `$ARGUMENTS`:

1. **Static summary** — `.agent/status/<slice>.md`
   (human-written; check mtime, flag if > 7 days).
2. **Live scan** — `./scripts/status.sh <slice>` if it exists. If
   not, fall back to a `find`/`git`-based ad-hoc scan of the
   project repo associated with the slice.
3. **Project git** — `git -C <project-repo> status --short` and
   `git -C <project-repo> log --oneline -5`.

## Workflow

1. Resolve slice name from `$ARGUMENTS`. If empty, list the slices
   defined in `WORKFLOW.md §1` and ask the user.
2. Read `.agent/status/<slice>.md`. If mtime > 7 days, flag stale
   and rely more on live signals.
3. Run the live scan; capture output.
4. Capture project-repo git state.
5. Diff the three views. If the static summary contradicts live
   state, prefer live and note the contradiction.

## Output

Tight report (15-25 lines):

- Slice + last-touched date.
- Done so far (from static + git log).
- In-flight (from git status + live scan).
- Next action (from `.agent/handoffs/CURRENT.md.remaining_actions` if
  the slice matches, else from the static summary).
- Any contradictions or stale signals worth flagging.

## Slice → project-repo mapping

The mapping lives in `WORKFLOW.md §1`. Read it at invocation time so
you do not embed a stale copy in this skill. If the routing table is
empty (fresh template), tell the user to fill it in first.

## Red Flags

| Rationalization | Reality |
|---|---|
| "The static `.agent/status/<slice>.md` already says everything." | mtime-bounded. If > 7d, the live scan is the authority; the static may already be wrong. |
| "I'll just check `git log` instead." | git log shows merged history, not what's dirty in the active project repo nor what's in flight per `CURRENT.md`. Use all three sources. |
| "Multiple slices apply to this work — show all." | A consolidated view of two slices is two reports glued together; it hides what matters in each. Pick one; run the skill twice if you really need both. |
| "Static and live disagree, but live is probably wrong." | The disagreement IS the signal. Prefer live; flag the contradiction so the static gets refreshed. Suppressing it loses information. |
| "Slice name is close enough — a typo'd variant should resolve." | No fuzzy match. The `WORKFLOW.md §1` table is authoritative; if `$ARGUMENTS` isn't a row, stop and ask. Silently coercing breaks `/route` and the Stop hook's VALID_SLICES check. |
