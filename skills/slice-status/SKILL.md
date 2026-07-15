---
name: slice-status
description: Use when entering or resuming a workspace slice and you need one consolidated view from the static baton, live status scan, and relevant git status.
license: MIT
---

# Slice Status

Show the current state of one slice by comparing the static baton,
the live harness scan, and the owning repo's recent git state.

## Mapping

| Slice | Status file | Repo / live scope |
| --- | --- | --- |
| `fragmap` | `.agent/status/fragmap.md` | `FKSFold-Boltz_Advancement/` |
| `mmgbsa` | `.agent/status/mmgbsa.md` | `FKSFold-Boltz_Advancement/` |
| `vav1` | `.agent/status/vav1.md` | `FKSFold-Boltz_Advancement/` |
| `fksfold-core` | `.agent/status/fksfold-core.md` | `FKSFold-Boltz_Advancement/` |
| `arl` | `.agent/status/arl.md` | `arl-threads-coscientist/` |
| `harness` | `.agent/status/harness.md` | workspace root `/home/ubuntu` |

## Workflow

1. Resolve the slice name exactly. If missing or invalid, list valid slices
   and stop.
2. Read `.agent/status/<slice>.md`; if its mtime is older than seven days,
   flag it as stale.
3. Run `./scripts/status.sh <slice>` and treat contradictions with the static
   baton as important signal.
4. Run git status and recent log for the mapped repo/scope:
   - project slices: `git -C <repo> status --short` and `git -C <repo> log --oneline -5`.
   - `harness`: `git status --short`, `git --no-pager diff --stat`, and
     `git --no-pager log --oneline -5 --grep=harness`.
5. Report done, in-flight, next action, and contradictions in 15-25 lines.

## Guardrails

- Do not consolidate two slices into one report; run the workflow twice.
- Do not suppress static-vs-live disagreement.
- Do not modify `.agent/status/<slice>.md`; baton updates belong to
  `handoff-writer`.
- Do not fuzzy-match slice names.
