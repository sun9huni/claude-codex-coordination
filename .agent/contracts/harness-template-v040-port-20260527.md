---
status: done
slice: harness
topic: template-v040-port
date: 2026-05-27
owner: claude
approved_by: user (2026-05-27, "run")
target_repo: scratch/claude-codex-coordination (origin → github.com/sun9huni/claude-codex-coordination, main @ fe64db6)
decisions:
  - Port this session's per-slice handoff migration into the template repo as v0.4.0, GENERICIZED to the template's existing convention (`<slice>` / `slice-1`/`slice-2` placeholders; NO fragmap/mmgbsa/FKSFold/SLURM/Notion specifics).
  - EXCLUDE (workspace-specific, not generic): all Notion (notion_sync.py, notion_map.yaml, runbook, Notion skills), project content (FKSFold/mmgbsa contracts/plans/status batons), workspace-only hooks (pre-bash-slurm-gate, pre-bash-db-gate), secrets/runtime.
  - Push via a BRANCH (`v0.4.0-per-slice-handoff`) + open a PR (gh) — NOT a direct main push — given it is a public repo (final push/PR confirmed with user at the push gate).
  - Template tests must pass before push: run-skill-lint, run-hook-tests, and the ported run-harness-concurrency.
  - CHANGELOG [0.4.0] entry (Keep a Changelog) + any VERSION marker bumped.
---

# Template v0.4.0 — port the per-slice handoff migration

## Purpose

The workspace built + verified a per-slice handoff model this session
(contract harness-concurrent-handoff-20260526): per-slice `status/<slice>.md`
batons, a DERIVED `CURRENT.md` index (`status.sh index`), claim/heartbeat,
Stop-hook per-slice validation, and a concurrency test. The upstream template
`claude-codex-coordination` is still at v0.3.1 (single hand-edited CURRENT.md).
Port the generic mechanism upstream as v0.4.0 so other projects inherit
concurrent-safe handoff, then push.

## Current State

- Template clone: `scratch/claude-codex-coordination`, `main` @ fe64db6, clean, in sync with origin.
- Template is v0.3.1, single-CURRENT.md: `handoff.sh` has no per-slice/AGENT_ROOT; **no `scripts/status.sh`**; CLAUDE.md/WORKFLOW use single `active_slice`; no concurrency test. Uses generic `<slice>` / `slice-1` placeholders + Keep-a-Changelog.
- Workspace (source of the port): `scripts/handoff.sh` (per-slice + AGENT_ROOT), `scripts/status.sh` (index mode + workspace `slice_*` scans), `.claude/hooks/{session-start-decay-check,stop-handoff-check}.sh` (claim-check + per-slice validation, AGENT_ROOT), `tests/run-harness-concurrency.sh`, ritual docs (CLAUDE.md/WORKFLOW.md/.agent/handoffs/{handoff,takeover-prompt,README}.md/.agent/status/README.md). These carry workspace specifics (fragmap/mmgbsa/SLURM/Notion) to be scrubbed.

## Assumptions And Questions

- assumptions:
  - The template's generic placeholder convention (`<slice>`, `slice-1`) is the genericization target; example slices stay abstract.
  - The workspace `status.sh` `index` mode is generic; the `slice_*` live-scan functions are workspace-specific → the template gets a generic `status.sh` with the `index` mode + a status/*.md-discovered slice list (no hardcoded slices).
  - The concurrency test is already generic (fixtures + AGENT_ROOT) — only fixture slice names need to be neutral.
- open questions:
  - Does the template want a full `status.sh` or just an `index` subcommand bolted onto its existing scripts? → Recommend a small generic `status.sh` providing `index` + a generic `<slice>` scan stub.
  - Branch+PR vs direct main — defaulting to branch+PR (confirm at push).
- tradeoffs:
  - Genericization is the main effort + risk; a leaked workspace-specific string in a public repo is the failure to avoid → grep-scrub gate before push.

## Constraints

- allowed change scope (ALL under `scratch/claude-codex-coordination/`):
  - `scripts/handoff.sh` (per-slice mode + AGENT_ROOT), `scripts/status.sh` (NEW, generic: index + slice scan), 
  - `.claude/hooks/session-start-decay-check.sh` + `stop-handoff-check.sh` (claim-check + per-slice validation + AGENT_ROOT),
  - `.agent/status/README.md` (per-slice frontmatter schema), `.agent/handoffs/{handoff.md,takeover-prompt.md,README.md}`,
  - `CLAUDE.md`, `WORKFLOW.md` (per-slice + derived-index ritual),
  - `tests/run-harness-concurrency.sh` (NEW, generic), `tests/run-hook-tests.sh` (extend if needed),
  - `CHANGELOG.md` (+ VERSION/README version marker), `HARNESS_USAGE.md` (per-slice section).
- forbidden change scope:
  - No Notion anything; no FKSFold/mmgbsa/SLURM strings; no workspace hooks (slurm/db gates); no project content; no secrets.
  - No edits to `/home/ubuntu` workspace files (only the template clone + this contract/plan in `.agent/`).
  - No direct push to `main` without the push gate.
- external constraints:
  - Public GitHub repo — scrub gate (grep for `fragmap|mmgbsa|FKSFold|SLURM|notion|9NFR|/mnt/data|sunghoon` in the diff) MUST be clean before push.

## Non-Goals

1. Porting Notion sync / reporting (workspace-specific add-on; could be a separate optional template module later).
2. Porting project content (FKSFold/mmgbsa slices, contracts, plans, status batons).
3. Porting workspace-only hooks (pre-bash-slurm-gate, pre-bash-db-gate).
4. A direct-to-main push (use branch + PR).
5. Re-genericizing unrelated v0.3.1 content beyond the per-slice migration.

## Done When

1. Template clone on branch `v0.4.0-per-slice-handoff` carries the genericized per-slice migration (handoff.sh per-slice+AGENT_ROOT, generic status.sh index, both hooks, ritual docs, status README schema, concurrency test).
2. **Scrub gate**: `git -C scratch/claude-codex-coordination diff main...HEAD` contains ZERO of `fragmap|mmgbsa|FKSFold|SLURM|notion|9NFR|/mnt/data|kim|sunghoon` (case-insensitive).
3. Template tests pass on the branch: `bash tests/run-skill-lint.sh`, `bash tests/run-hook-tests.sh`, `bash tests/run-harness-concurrency.sh` → all PASS.
4. `CHANGELOG.md` has a `[0.4.0]` entry describing the per-slice migration; version marker bumped.
5. Branch pushed to origin; PR opened (gh) — OR, if the user elects at the push gate, merged to main.
6. Verification: the PR/branch diff is the genericized migration only; `git status` clean in the template clone.

## Implementation Steps

1. Branch the template clone: `git -C scratch/claude-codex-coordination checkout -b v0.4.0-per-slice-handoff`. verify: branch shows.
2. Port + genericize `scripts/handoff.sh` (per-slice mode + AGENT_ROOT; strip workspace refs). verify: `bash -n`; per-slice run against a temp AGENT_ROOT works.
3. Add generic `scripts/status.sh` (index mode generating CURRENT.md from status/*.md frontmatter + a generic slice scan; no hardcoded slices). verify: `status.sh index` on a temp fixture renders an index.
4. Port + genericize the two hooks (claim-check + per-slice validation + AGENT_ROOT; strip SLURM/fragmap/Notion from bootstrap text). verify: `bash -n` both.
5. Port the concurrency test (neutral fixture slice names). verify: `bash tests/run-harness-concurrency.sh` → green.
6. Port ritual docs (CLAUDE.md, WORKFLOW.md, .agent/handoffs/{handoff,takeover-prompt,README}, .agent/status/README.md) to per-slice + derived-index, generic placeholders. verify: grep per-slice present, no workspace strings.
7. CHANGELOG [0.4.0] + version marker. verify: entry present.
8. Scrub gate + all template tests. verify: Done-When #2 + #3.
9. Commit (one or a few logical commits) + push branch + open PR (push gate: confirm with user). verify: `gh pr view` / branch on origin.

## Change Discipline

- simplest adequate approach: port the proven workspace files, genericize by scrub; add the one missing generic file (status.sh).
- new abstractions: none (the mechanism already exists + is verified in the workspace).
- request-to-diff trace: 사용자 "전신 템플릿 확인하고 업데이트할 수 있는 부분 + git push" → per-slice migration이 템플릿 v0.4.0 후보 → 제네릭 포팅.

## Verification

- `bash -n` on every ported script/hook.
- `bash tests/run-skill-lint.sh && bash tests/run-hook-tests.sh && bash tests/run-harness-concurrency.sh` (template clone) → all PASS.
- Scrub: `git diff main...HEAD | grep -iE 'fragmap|mmgbsa|fksfold|slurm|notion|9nfr|/mnt/data|kim|sunghoon'` → empty.
- `gh pr view` shows the opened PR (or confirmed merge).

## Risks

- workspace-string leak into public repo → scrub gate (Done-When #2) is the hard guard; push only after it's clean.
- status.sh genericization drift (template has none) → keep it minimal (index + generic scan), test on fixture.
- template test breakage from ritual-doc edits → run all three test scripts pre-push.
- wrong-branch/force push → branch + PR, no force.

## Rollback

- revert strategy: it's a branch — if wrong, delete the branch (`git branch -D` local, close PR) before merge; nothing on main affected until merge.
- containment: all work isolated on `v0.4.0-per-slice-handoff`; main untouched until an explicit merge.

## Progress Log

- 2026-05-27: contract drafted (status: pending). Per-slice migration → template v0.4.0, genericized, branch+PR, scrub-gated. 사용자 승인 대기.
- 2026-05-27: 사용자 "run" → approved → /write-plan (13 tasks) → 사용자 "approved" → /execute-plan.
- 2026-05-27: **DONE** (13 tasks, 10 commits 6a5a4eb..a63f452). See plan `.agent/plans/harness-template-v040-port-20260527.md`.

## Notes

Ported this session's per-slice handoff migration to the upstream template
`sun9huni/claude-codex-coordination` as **v0.4.0**, fully genericized. The
mechanism — per-slice `status/<slice>.md` batons, a DERIVED `CURRENT.md` index
(`scripts/status.sh index`), claim/heartbeat, `AGENT_ROOT` seam, contested-slice
SessionStart warning, per-slice Stop validation, and a 5-assertion concurrency
test — was copied from the proven workspace files (`index_mode()` and both
hooks' slice-mode logic are byte-identical to the workspace source) and scrubbed
of all workspace specifics. The no-slice `handoff.sh <agent>` mode is preserved
for backward compatibility (template stays dual-mode); the shipped `CURRENT.md`
seed retains `active_slice` as the no-slice path's SSOT (intentionally out of
scope). Delivered on branch `v0.4.0-per-slice-handoff` via **PR #1 → main**
(https://github.com/sun9huni/claude-codex-coordination/pull/1), not a direct main
push — `main` untouched at fe64db6 until the user merges. Gates: scrub of
`git diff main...HEAD` CLEAN; skill-lint 11/11, hook-tests 13/13,
harness-concurrency 5/5 GREEN; CI mirror (bash -n / JSON / YAML) all OK.
EXCLUDED per scope: Notion sync/reporting, project content, workspace-only
hooks (slurm/db gates), secrets.
