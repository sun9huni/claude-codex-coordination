---
contract: .agent/contracts/harness-template-v040-port-20260527.md
slice: harness
status: done
total_tasks: 13
estimated_total_min: 52
---

# Plan — Template v0.4.0: port the per-slice handoff migration

Target repo: `scratch/claude-codex-coordination` (origin →
github.com/sun9huni/claude-codex-coordination, `main` @ fe64db6, v0.3.1).
ALL paths below are under `scratch/claude-codex-coordination/` unless noted.

Phase order: Setup(branch) → Core scripts → Hooks → Tests → Docs →
Changelog → Scrub+test gate → Push/PR.

**Genericization rule (every task)**: NO `fragmap|mmgbsa|fksfold|slurm|notion|
9nfr|/mnt/data|kim|sunghoon|vav1|arl` strings. Use the template's existing
abstract placeholders (`<slice>`, `slice-1`, `slice-2`). The scrub gate (Task
12) is the hard guard; each task should already be clean.

**Source of the port** (workspace, read-only — DO NOT edit `/home/ubuntu`
files): `scripts/handoff.sh`, `scripts/status.sh`,
`.claude/hooks/{session-start-decay-check,stop-handoff-check}.sh`,
`tests/run-harness-concurrency.sh`, `.agent/status/README.md`.

---

## Task 1: Branch the template clone

- **Status**: done (2026-05-27; branch v0.4.0-per-slice-handoff off main @ fe64db6, clean)
- **Prereq tasks**: none
- **Files touched**: none (git branch only, in `scratch/claude-codex-coordination`)
- **Change shape**: `git -C scratch/claude-codex-coordination checkout -b v0.4.0-per-slice-handoff` off clean `main` @ fe64db6.
- **Verification**: `git -C scratch/claude-codex-coordination branch --show-current` → `v0.4.0-per-slice-handoff`; `git -C scratch/claude-codex-coordination status -s` → empty.
- **Estimated time**: 2 min
- **Rollback (if this task only)**: `git -C scratch/claude-codex-coordination checkout main && git -C scratch/claude-codex-coordination branch -D v0.4.0-per-slice-handoff`

## Task 2: Port per-slice mode + AGENT_ROOT into handoff.sh

- **Status**: done (2026-05-27, commit 6a5a4eb; code-review APPROVE, smoke + scrub clean)
- **Prereq tasks**: 1
- **Files touched**: `scripts/handoff.sh`
- **Change shape**: Port the workspace per-slice additions into the template's existing `handoff.sh`: (a) usage `<next-agent> [<slice>]` + `SLICE="${2:-}"`; (b) the `AGENT_ROOT` env seam (`AGENT_DIR="${AGENT_ROOT:-$ROOT/.agent}"`) routing `HANDOFF_DIR`/`STATE_DIR`/`STATUS_DIR` reads/writes (ROOT still locates the repo for git ops); (c) the CURRENT.md-required check gated on no-slice mode only; (d) the entire per-slice block (claim/refresh ONLY `$STATUS_DIR/<slice>.md` — 6 frontmatter fields via the `awk` rewriter, preserving remaining_actions/contract_pointers/body, then `exit 0`) with `OWNER_SESSION`/`OWNER_LABEL` env seams + UUID fallback. No-slice path unchanged (backward-compat). No workspace strings to scrub.
- **Verification**: `bash -n scripts/handoff.sh`; per-slice run against a temp tree — `AGENT_ROOT=$(mktemp -d)/.agent` with a seeded `status/slice-1.md`, run `OWNER_SESSION=test-sess bash scripts/handoff.sh claude slice-1`, then assert the file's frontmatter now has `owner_session: test-sess`, bumped `version`, a `heartbeat`, and the original `remaining_actions` preserved; no-slice run still bumps CURRENT.md `version`.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git -C scratch/claude-codex-coordination checkout scripts/handoff.sh`

## Task 3: Add generic scripts/status.sh (index + discovery scan)

- **Status**: done (2026-05-27, commit bfb831a; index_mode byte-identical to workspace, discovery scan generic, code-review APPROVE, scrub clean)
- **Prereq tasks**: 1
- **Files touched**: `scripts/status.sh` (new)
- **Change shape**: New generic `status.sh`. Port `index_mode()` VERBATIM from the workspace (AGENT_ROOT seam, python3 frontmatter parser → derived `CURRENT.md`, atomic `.tmp`+`mv`, zero-status hard error). Replace the workspace `slice_*()` scans + hardcoded `SLICES=` with a **generic discovery scan**: `list_slices()` enumerates `$AGENT_DIR/status/*.md` (excluding `README.md`) and prints each slice's name + `last_updated`/`heartbeat`/first `remaining_action` (reuse the same frontmatter parse, or a small awk); a `<slice>` arg prints that one slice's status-file summary. No `/mnt/data`, no Cursor/local-repo paths, no hardcoded slice names. CLI: no-arg/`-h` → list; `<slice>` → one; `index`/`--index` → index_mode.
- **Verification**: `bash -n scripts/status.sh`; on a temp `AGENT_ROOT` with `status/slice-1.md` + `status/slice-2.md` seeded, `AGENT_ROOT=... bash scripts/status.sh index` writes `handoffs/CURRENT.md` containing a table row for both `slice-1` and `slice-2`; `bash scripts/status.sh` (no arg) lists both discovered slices; `grep -iE 'fragmap|mmgbsa|/mnt/data|cursor|vav1|arl' scripts/status.sh` → empty.
- **Estimated time**: 7 min
- **Rollback (if this task only)**: `rm scripts/status.sh`

## Task 4: Port claim-check + AGENT_ROOT into session-start-decay-check.sh

- **Status**: done (2026-05-27, commit 303f8b8; claim-check fires fresh/silent stale, per-slice bootstrap, kept template auto-detection, code-review APPROVE, scrub clean)
- **Prereq tasks**: 1
- **Files touched**: `.claude/hooks/session-start-decay-check.sh`
- **Change shape**: Port the workspace hook's per-slice additions into the template's existing hook: (a) `AGENT_ROOT` seam for the status/handoffs dirs; (b) the Job1b claim-check — given `ENTERING_SLICE` + `OWNER_SESSION` env, read `status/<slice>.md` frontmatter; if its `heartbeat` is fresh (<30 min) AND `owner_session` differs from the current `OWNER_SESSION`, emit a contested-slice warning; stale heartbeat → no warning; (c) de-scalar the bootstrap to source per-slice frontmatter (not a single `active_slice`). Genericize ALL bootstrap help-text: replace the workspace subagent list (`slurm-status`/`fragmap-diagnose`/`mmgbsa-stage-check`) and the `rm -rf on /mnt/data*` line with abstract/template-appropriate text (or drop the project-specific lines).
- **Verification**: `bash -n .claude/hooks/session-start-decay-check.sh`; with a temp `AGENT_ROOT` holding a fresh-heartbeat `status/slice-1.md` owned by `S1`, running with `ENTERING_SLICE=slice-1 OWNER_SESSION=S3` prints a contested/claim warning; a 60-min-stale heartbeat prints none. `grep -iE 'fragmap|mmgbsa|slurm|/mnt/data' .claude/hooks/session-start-decay-check.sh` → empty.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git -C scratch/claude-codex-coordination checkout .claude/hooks/session-start-decay-check.sh`

## Task 5: Port per-slice validation + AGENT_ROOT into stop-handoff-check.sh

- **Status**: done (2026-05-27, commit 20e021d; byte-identical to workspace source, good/bad fixtures verified, code-review APPROVE, scrub clean)
- **Prereq tasks**: 1
- **Files touched**: `.claude/hooks/stop-handoff-check.sh`
- **Change shape**: Port the workspace hook's per-slice validation: (a) `AGENT_ROOT` seam; (b) validate the ACTIVE slice's `status/<slice>.md` frontmatter against the per-slice schema (owner_session/owner_agent/version/last_updated/heartbeat present, `owner_agent ∈ VALID_AGENTS`, no `<placeholder>` left); (c) exclude `README.md` from any claimed-slice loop. `VALID_AGENTS` (`claude|codex|cursor|human`) is already generic — keep. No workspace strings expected; scrub anyway.
- **Verification**: `bash -n .claude/hooks/stop-handoff-check.sh`; a well-formed temp `status/slice-1.md` passes validation; one with a `<placeholder>` or missing `owner_agent` is flagged. `grep -iE 'fragmap|mmgbsa|slurm|notion|/mnt/data' .claude/hooks/stop-handoff-check.sh` → empty.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C scratch/claude-codex-coordination checkout .claude/hooks/stop-handoff-check.sh`

## Task 6: Port the concurrency test with neutral fixtures

- **Status**: done (2026-05-27, commit a5c6e28; 5/5 GREEN standalone, neutral slice-1/slice-2 fixtures, header reframed, CI wired, code-review APPROVE, scrub clean)
- **Prereq tasks**: 2, 3, 4
- **Files touched**: `tests/run-harness-concurrency.sh` (new), `.github/workflows/*.yml` (only if a CI workflow exists and wiring is one line)
- **Change shape**: Port `tests/run-harness-concurrency.sh` (hermetic: sandbox repo + `AGENT_ROOT`, 5 assertions — lost-update, index regen, claim warning, no-leak, backward-compat Stop). Rename fixture slices `fragmap`→`slice-1`, `mmgbsa`→`slice-2`; replace the workspace action strings (`light-filter recal`, `5331 NVT`, etc.) and contract paths with neutral text (`slice-1 action A`, `.agent/contracts/slice-1-example-20260527.md`). Keep the `S1`/`S2`/`S3` UUID fixtures. If the template has a CI workflow that runs the other test scripts, add a one-line invocation of this test to the same matrix step.
- **Verification**: `bash -n tests/run-harness-concurrency.sh`; `cd scratch/claude-codex-coordination && bash tests/run-harness-concurrency.sh` → all 5 PASS. `grep -iE 'fragmap|mmgbsa|5331|light-filter|/mnt/data' tests/run-harness-concurrency.sh` → empty.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `rm tests/run-harness-concurrency.sh` (+ revert CI wiring if added)

## Task 7: Update .agent/status/README.md with per-slice frontmatter schema

- **Status**: done (2026-05-27, commit 593ca38; baton schema + generic example, removed parallel-SSOT framing, code-review APPROVE, scrub clean)
- **Prereq tasks**: none
- **Files touched**: `.agent/status/README.md`
- **Change shape**: Extend the template's existing status README with the per-slice **baton** framing + the YAML frontmatter schema (owner_session/owner_label/owner_agent/version/last_updated/heartbeat/remaining_actions/contract_pointers), the "a session writes only its own slice's file" rule, and "CURRENT.md is a DERIVED index generated by `scripts/status.sh index` — never hand-edit". Genericize the example frontmatter + any slice list to `slice-1`/`slice-2` with neutral actions/contract paths. Remove/replace the workspace "Cursor plans / shared outputs / ARL milestones" scan description with the generic discovery scan from Task 3.
- **Verification**: `grep -q 'owner_session' .agent/status/README.md && grep -q 'DERIVED' .agent/status/README.md && grep -qi 'never hand-edit' .agent/status/README.md`; `grep -iE 'fragmap|mmgbsa|cursor|arl|/mnt/data' .agent/status/README.md` → empty.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git -C scratch/claude-codex-coordination checkout .agent/status/README.md`

## Task 8: Update CLAUDE.md + WORKFLOW.md to the per-slice + derived-index model

- **Status**: done (2026-05-27, commit a030b03; per-slice ritual + handoff, active_slice removed, surgical, code-review APPROVE, scrub clean)
- **Prereq tasks**: none
- **Files touched**: `CLAUDE.md`, `WORKFLOW.md`
- **Change shape**: Edit the template's existing `CLAUDE.md` + `WORKFLOW.md` so the session ritual and handoff description reflect the per-slice model: `.agent/status/<slice>.md` is the authoritative per-slice baton; `CURRENT.md` is a DERIVED index (`scripts/status.sh index`, never hand-edited); `handoff.sh <agent> <slice>` claims/refreshes one slice; the SessionStart hook warns on a contested slice. Replace any single-`active_slice` / hand-edited-CURRENT.md language. Keep all slice references abstract (`<slice>`). This is a docs rewrite of the relevant sections only — do not touch unrelated v0.3.1 content.
- **Verification**: `grep -qi 'derived' CLAUDE.md WORKFLOW.md && grep -q 'status/<slice>.md' CLAUDE.md`; `grep -niE 'active_slice' CLAUDE.md WORKFLOW.md` → empty (or only as a historical note); `grep -iE 'fragmap|mmgbsa|slurm|/mnt/data' CLAUDE.md WORKFLOW.md` → empty.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C scratch/claude-codex-coordination checkout CLAUDE.md WORKFLOW.md`

## Task 9: Update .agent/handoffs ritual docs for the derived index

- **Status**: done (2026-05-27, commit 6a26b52; all 3 docs per-slice, no-slice snapshot path accurately described, placeholder-scan attributed to Stop hook, code-review APPROVE_WITH_NITS (nit fixed), scrub clean. NOTE: template's shipped CURRENT.md keeps active_slice as the no-slice backward-compat seed — out of scope.)
- **Prereq tasks**: none
- **Files touched**: `.agent/handoffs/handoff.md`, `.agent/handoffs/takeover-prompt.md`, `.agent/handoffs/README.md`
- **Change shape**: Update the three handoff docs: `handoff.md` describes `handoff.sh <agent> <slice>` as a per-slice frontmatter refresh (claim + heartbeat + version bump) and `status.sh index` as the CURRENT.md regenerator; `takeover-prompt.md` keys takeover off the contested per-slice `owner_session`/`heartbeat`; `README.md` states CURRENT.md is generated, never hand-edited. Abstract slices only.
- **Verification**: `grep -qi 'per-slice\|<slice>' .agent/handoffs/handoff.md && grep -qi 'never hand-edit\|derived\|generated' .agent/handoffs/README.md`; `grep -iE 'fragmap|mmgbsa|/mnt/data' .agent/handoffs/*.md` → empty.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git -C scratch/claude-codex-coordination checkout .agent/handoffs/handoff.md .agent/handoffs/takeover-prompt.md .agent/handoffs/README.md`

## Task 10: HARNESS_USAGE.md per-slice section

- **Status**: done (2026-05-27, commit 2097461; §1/§2/§5/§7 per-slice, §5 retitled w/ baton schema, fixed 2 stale valid_slices refs, code-review APPROVE_WITH_NITS, scrub clean)
- **Prereq tasks**: none
- **Files touched**: `HARNESS_USAGE.md`
- **Change shape**: Add/update a section documenting the per-slice handoff workflow: how to claim a slice (`handoff.sh <agent> <slice>`), how the derived index is regenerated (`status.sh index`), and the contested-slice warning. Abstract examples only.
- **Verification**: `grep -qi 'per-slice\|status.sh index' HARNESS_USAGE.md`; `grep -iE 'fragmap|mmgbsa|slurm|/mnt/data' HARNESS_USAGE.md` → empty.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `git -C scratch/claude-codex-coordination checkout HARNESS_USAGE.md`

## Task 11: CHANGELOG [0.4.0] + version marker

- **Status**: done (2026-05-27, commit a63f452; Keep-a-Changelog [0.4.0] above [0.3.1], all 9 commits described, no VERSION/README marker exists → CHANGELOG suffices, code-review APPROVE, scrub clean)
- **Prereq tasks**: 2, 3, 4, 5, 6, 7, 8, 9, 10
- **Files touched**: `CHANGELOG.md` (+ any single version marker file/README badge the repo carries)
- **Change shape**: Add a Keep-a-Changelog `## [0.4.0] - 2026-05-27` entry above `[0.3.1]`: Added (`scripts/status.sh` with derived-index mode, `tests/run-harness-concurrency.sh`, per-slice baton frontmatter), Changed (per-slice `handoff.sh <slice>` + AGENT_ROOT seam; CURRENT.md now a generated index; both hooks gain claim-check / per-slice validation; ritual docs to per-slice). Bump any version marker the repo uses to `0.4.0` (check README/VERSION; if none, CHANGELOG entry suffices).
- **Verification**: `grep -q '\[0.4.0\]' CHANGELOG.md`; if a version marker exists, `grep -q '0.4.0' <that file>`.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `git -C scratch/claude-codex-coordination checkout CHANGELOG.md`

## Task 12: Scrub gate + all template tests (HARD GATE)

- **Status**: done (2026-05-27; scrub of `git diff main...HEAD` CLEAN for contract pattern; skill-lint 11/11, hook-tests 13/13, harness-concurrency 5/5 GREEN; CI mirror — bash -n sweep ALL_OK, settings JSON valid, test.yml YAML valid)
- **Prereq tasks**: 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
- **Files touched**: none (verification only)
- **Change shape**: Run the scrub gate over the whole branch diff and run all three template test scripts. NO code change — if either fails, stop the loop and route the failing file back for a fix.
- **Verification**: `cd scratch/claude-codex-coordination && git diff main...HEAD | grep -iE 'fragmap|mmgbsa|fksfold|slurm|notion|9nfr|/mnt/data|kim|sunghoon|vav1|arl' ` → **empty** (exit 1 from grep = clean); AND `bash tests/run-skill-lint.sh && bash tests/run-hook-tests.sh && bash tests/run-harness-concurrency.sh` → all PASS.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: n/a (verification gate)

## Task 13: Commit, push branch, open PR (PUSH GATE — confirm with user)

- **Status**: done (2026-05-27; user confirmed at push gate "Push branch + open PR". Pushed v0.4.0-per-slice-handoff to origin; opened PR #1 -> main (+1343/-215, 14 files). main untouched at fe64db6. https://github.com/sun9huni/claude-codex-coordination/pull/1)
- **Prereq tasks**: 12
- **Files touched**: none (git commit/push in `scratch/claude-codex-coordination`)
- **Change shape**: **STOP and confirm with the user before pushing** (public-repo push gate). Then commit the branch in a few logical commits (scripts / hooks / tests / docs+changelog), `git push -u origin v0.4.0-per-slice-handoff`, and `gh pr create` titled "v0.4.0: per-slice handoff model (concurrent-safe batons + derived CURRENT.md index)" with a body summarizing the migration. NO direct main push; NO force push.
- **Verification**: `gh pr view --repo sun9huni/claude-codex-coordination` shows the open PR against `main`; `git -C scratch/claude-codex-coordination status -s` clean; branch visible on origin.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `gh pr close <n>` + `git push origin --delete v0.4.0-per-slice-handoff` (main untouched until merge)
