---
name: slice-status
description: Show the current state of one workspace slice. Combines the static .agent/status/<slice>.md, the live ./scripts/status.sh scan, and project-repo git status. Use when entering or resuming work on a slice and want one consolidated view.
argument-hint: "<slice-name e.g. fragmap | mmgbsa | vav1 | aigen-fold-core | arl | harness | fea>"
allowed-tools: Read Bash(./scripts/status.sh:*) Bash(cat:*) Bash(stat:*) Bash(git -C * status:*) Bash(git -C * log:*) Bash(git status:*) Bash(git --no-pager diff:*) Bash(git --no-pager log:*)
---

# /slice-status — Consolidated slice view

Compare three independent sources for `$ARGUMENTS`:

1. **Static summary** — `.agent/status/<slice>.md`
   (human-written, may be stale; check mtime).
2. **Live scan** — `./scripts/status.sh <slice>` (plans/outputs/git
   scanned at invocation time).
3. **Project git** — git status / recent commits for the project repo
   that owns this slice.

## Mapping

| Slice arg | Status file | Project repo |
|---|---|---|
| `fragmap` | `.agent/status/fragmap.md` | `FKSFold-Boltz_Advancement/` |
| `mmgbsa` | `.agent/status/mmgbsa.md` | `FKSFold-Boltz_Advancement/` |
| `vav1` | `.agent/status/vav1.md` | `FKSFold-Boltz_Advancement/` |
| `aigen-fold-core` | `.agent/status/aigen-fold-core.md` | `FKSFold-Boltz_Advancement/` |
| `arl` | `.agent/status/arl.md` | `arl-threads-coscientist/` |
| `harness` | `.agent/status/harness.md` | workspace root `/home/ubuntu` |
| `fea` | `.agent/status/fea.md` | workspace root `/home/ubuntu` (`scripts/fea/`) |

If `$ARGUMENTS` is not one of these, list the valid slices and stop.

## Workflow

1. Resolve slice name from `$ARGUMENTS`. If empty, ask the user.
2. Read `.agent/status/<slice>.md`. If mtime > 7 days, flag it as
   stale and rely more heavily on the live scan.
3. Run `./scripts/status.sh <slice>` and capture the output.
4. `git -C <project repo> status --short` and `git -C <project repo>
   log --oneline -5`. For `harness`, use workspace-root `git status --short`,
   `git --no-pager diff --stat`, and `git --no-pager log --oneline -5
   --grep=harness`.
5. Diff the three views. If the static summary contradicts the live
   scan, prefer the live scan and note the contradiction.

## Output

A consolidated report:
- Slice + last-touched date.
- Done so far (from static + git log).
- In-flight (from git status + live scan).
- Next action (from this slice's `.agent/status/<slice>.md` frontmatter
  `remaining_actions`, with the derived CURRENT.md index as cross-check).
- Any contradictions or stale signals worth flagging.

Keep it tight: 15-25 lines, not a wall of text.

## Red Flags

| Rationalization | Reality |
|---|---|
| "The static `.agent/status/<slice>.md` already says everything." | mtime-bounded. If > 7d, the live scan is the authority; the static may already be wrong. |
| "I'll just check `git log` instead." | git log shows merged history, not what's dirty in the active project repo nor what's in flight per the slice's `.agent/status/<slice>.md` frontmatter. Use all three sources. |
| "Multiple slices apply to this work — show all." | A consolidated view of two slices is two reports glued together; it hides what matters in each. Pick one; run the skill twice if you really need both. |
| "Static and live disagree, but live is probably wrong." | The disagreement IS the signal. Prefer live; flag the contradiction so the static gets refreshed. Suppressing the disagreement loses information. |
| "Slice name is close enough — `fragmap1` should resolve." | No fuzzy match. The Mapping table is authoritative; if `$ARGUMENTS` isn't in it, stop and ask. Silently coercing breaks `/route` and the Stop hook's VALID_SLICES check.|

## Forbidden

- Do NOT fuzzy-match slice names; require exact match against the Mapping table / `WORKFLOW.md §1`.
- Do NOT suppress disagreement between static and live sources; flag it.
- Do NOT consolidate two slices' views into one report.
- Do NOT modify the static `.agent/status/<slice>.md` from this skill; that belongs to `/handoff` or the slice owner.
