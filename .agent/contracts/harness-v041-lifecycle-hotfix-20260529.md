---
status: done
slice: harness
topic: v041-lifecycle-hotfix
date: 2026-05-29
owner: claude
approved_by: user (2026-05-29, "approved")
follow_on_to: .agent/contracts/harness-template-v040-port-20260527.md
target_repos:
  - workspace (/home/ubuntu)
  - upstream template (scratch/claude-codex-coordination → github.com/sun9huni/claude-codex-coordination, main @ f5dd897, v0.4.0 merged)
  - Codex mirror (.codex/skills/handoff-writer/SKILL.md + AGENTS.md)
decisions:
  - Bundle as a single v0.4.1 release covering 4 items: (1) Stop hook per-slice "/handoff not run" detection, (2) `state: active|closed|released` frontmatter field, (3) `handoff.sh --release <slice>` verb, (4) auto-commit of the slice's own contracts/+plans/ untracked files at handoff time.
  - Codex parity INCLUDED — `AGENTS.md`, `.codex/skills/handoff-writer/SKILL.md`, and `.agent/templates/AGENTS.md.example` updated in the SAME contract so Codex sessions understand the new `state` field + `--release` verb.
  - Commit ritual = STRONG: `handoff.sh <agent> <slice>` (slice mode) auto-`git add`+`git commit` of `.agent/contracts/<slice>-*-<YYYYMMDD>.md` and `.agent/plans/<slice>-*.md` that are untracked AND match the active slice's prefix. SAFEGUARDS: skip if the repo has other dirty changes (avoid sweeping unintended files); skip if not a git repo; non-fatal — warns and continues if the commit fails.
  - Ship order: workspace first (proving ground), then port the generic mechanism to the upstream template as v0.4.1 via a branch + PR (same flow as v0.4.0). Workspace + upstream both released together (workspace `tag v0.4.1-workspace` optional; upstream `tag v0.4.0` → `v0.4.1`).
  - Backward compat: `state` field defaults to `active` if absent (old batons keep working). `--release` is a new flag (no impact on existing two-arg form `handoff.sh <agent> <slice>`). The auto-commit refuses if other dirty changes are present, so users in dirty trees see a warning but no surprise commit.
---

# Harness v0.4.1 — per-slice lifecycle hotfix

## Purpose

v0.4.0 migrated coordination to per-slice batons + a derived `CURRENT.md`
index. In doing so it broke three v0.3.x guard-rails and introduced two
small lifecycle gaps that the v0.4.0 port left as future work. v0.4.1
closes those four gaps in one bundle, restoring the v0.3.x safety net to
the per-slice model and adding the missing lifecycle verbs.

## Current State

- v0.4.0 is shipped (upstream `main` @ f5dd897, tag `v0.4.0`, PR #1 merged).
- Workspace is on the per-slice model end-to-end (concurrency test 5/5
  GREEN, 6 slice batons live).
- KNOWN gaps (from system-issues review 2026-05-29):
  1. **Stop hook silent on missed /handoff**: v0.3.x had a `CURRENT.md
     version vs state/latest/meta.txt snap_version` check that warned
     when an agent ended a session without running handoff. In v0.4.0
     CURRENT.md is derived and has no top-level `version`, so the check
     is gated off by `[ -n "$fm_version" ]` and silently never fires.
     No equivalent per-slice check exists.
  2. **No lifecycle state**: when a slice closes (e.g. fragmap Phase 10),
     the body says `✅ CLOSED` but the frontmatter still carries the last
     `owner_session`/`heartbeat`. The CURRENT.md index shows it as
     "owned" with stale heartbeat — same shape as an in-flight slice.
  3. **No "release slice" verb**: clearing `owner_session`/`heartbeat`
     requires manual frontmatter editing. `OWNER_SESSION=""` works but
     is undocumented and won't update a (new) `state` field.
  4. **Contracts/plans accumulate untracked**: 22 untracked items under
     `.agent/contracts/` + `.agent/plans/` from completed work. The
     audit trail that v0.3.x's `state/latest/diff.patch` gave us is
     lost in per-slice mode (slice handoff doesn't snapshot git state).

## Decisions

(see frontmatter `decisions:`)

## Assumptions And Questions

- assumptions:
  - The 4 items are tight enough to ship together (small surface; same
    files; one PR; one verification suite).
  - The `state` field is a closed enum for v0.4.1 — `active | closed |
    released` — extensible later (e.g. `dormant`, `archived`).
  - Auto-commit by handoff.sh is acceptable because (a) the user chose
    the strong option, (b) it ONLY acts on untracked files matching
    the slice's name prefix, (c) it refuses on a dirty working tree.
- open questions:
  - Should `--release` ALSO auto-commit the slice's contracts/plans
    (likely yes — "wrap up the slice" is the natural meaning), or
    leave that to the prior `handoff.sh <agent> <slice>` call?
    → Recommend YES: `--release` is a terminal handoff.
  - Does the existing fragmap baton get retroactively marked
    `state: closed` as part of v0.4.1's verification (one-off data
    update) or stays as-is until the next fragmap session manually
    releases it?
    → Recommend: leave fragmap alone (out of scope; the verification
    uses fixtures, not live batons).
- tradeoffs:
  - Auto-commit is strong but constrained by the "no other dirty
    changes" guard. If the guard is too strict it stays cosmetic;
    too loose it surprises users. The chosen safeguard set is
    "untracked-only, matching slice prefix, refuse on other dirt".

## Constraints

- allowed change scope (workspace + upstream template):
  - `scripts/handoff.sh` — add `--release` flag; in slice mode, after
    the frontmatter write, optionally auto-commit untracked slice
    contracts/plans (guarded). NO change to no-slice mode.
  - `.claude/hooks/stop-handoff-check.sh` — add per-slice "handoff
    not run this session" detection (heartbeat older than the session's
    start time, where "session start" is inferred via an env var the
    SessionStart hook sets OR a sentinel file under `.agent/handoffs/`).
  - `.agent/status/README.md` (workspace + upstream) — document the
    `state` field in the schema; example block shows `state: active`.
  - `scripts/status.sh` index_mode — add a `state` column to the
    CURRENT.md table; closed/released slices show distinctively
    (e.g. `closed` not `live`/iso-timestamp).
  - `tests/run-harness-concurrency.sh` — extend assertions to cover
    the 4 new behaviors (or a sibling `tests/run-harness-lifecycle.sh`
    if cleaner).
  - `.claude/skills/handoff/SKILL.md` (workspace) + `.codex/skills/
    handoff-writer/SKILL.md` (Codex mirror) — document the new flag +
    state field + auto-commit step.
  - `AGENTS.md` + `.agent/templates/AGENTS.md.example` — per-slice
    schema note bumped to include `state`.
  - `CHANGELOG.md` (upstream) — `[0.4.1]` entry.
- forbidden change scope:
  - No change to no-slice `handoff.sh <agent>` path; v0.3.x users keep
    working.
  - No reverse migration; v0.4.0 batons without `state` field stay
    valid (default = `active`).
  - No new external deps; no schema_version bump (`state` is additive).
  - No edits to existing slice batons except via the new `--release`
    verb (verification uses fixtures, not live batons).
  - No bundling of v2 deferred items (Notion handoff-log SLURM
    auto-detect, granular Decisions/Artifacts, Codex `/handoff` mirror
    of Step 5 — explicitly OUT of scope).
- external constraints:
  - Upstream is public — same scrub gate as v0.4.0 before any push
    (`grep -iE 'fragmap|mmgbsa|fksfold|slurm|notion|9nfr|/mnt/data|
    kim|sunghoon'` on `git diff main...HEAD`).
  - Workspace + upstream `status.sh` already drift (workspace has
    workspace-specific `slice_*()` scans). Both get the `state`
    column addition in their respective `index_mode()` (kept
    byte-identical between the two).

## Non-Goals

1. Notion handoff-log v2 (SLURM auto-detect, granular Decisions/
   Artifacts auto-pop, Codex mirror of Step 5).
2. Per-slice git-snapshot audit log (the deeper v0.3.x replacement —
   that's its own contract if/when needed).
3. Retroactive `state: closed` migration of live workspace batons.
4. Schema version bump or breaking changes to the v0.4.0 baton model.
5. GitHub Releases for any tag (still tag-only as in v0.1.x..v0.4.0).
6. Workspace ↔ upstream `status.sh` reunification (intentional drift).

## Done When

1. **Stop hook fixture**: a slice's heartbeat is older than this
   session's start time + the SessionStart hook had set the session
   marker → Stop hook prints `[handoff-check] session ended without
   running handoff.sh for slice <X>` to stderr.
2. **state field**: `.agent/status/README.md` documents the field;
   Stop hook rejects values outside `{active, closed, released}`;
   `status.sh index` writes a `state` column; absent field defaults
   to `active`.
3. **`--release` verb**: `./scripts/handoff.sh --release <slice>`
   sets frontmatter `state: released`, clears `owner_session`,
   `owner_label`, `heartbeat`; preserves `version`, `last_updated`,
   `remaining_actions`, `contract_pointers`, body. Idempotent:
   re-running on an already-released slice is a no-op (or just
   refreshes `last_updated`). Verified by fixture.
4. **Auto-commit**: with the active slice = `<X>`, a clean working
   tree except for untracked `.agent/contracts/<X>-*.md` and
   `.agent/plans/<X>-*.md`, running `handoff.sh <agent> <X>` results
   in those files being added + committed in a single commit titled
   `<slice>: contracts/plans auto-commit (handoff)`; if other dirty
   changes exist the auto-commit is SKIPPED with a one-line warning
   (handoff still completes). Non-fatal under all error paths.
5. **Concurrency regression**: `tests/run-harness-concurrency.sh` →
   5/5 GREEN unchanged. New lifecycle test (or appended assertions)
   pass.
6. **Workspace shipped**: workspace edits committed (one commit per
   item) under a `.agent/contracts/harness-v041-...` plan.
7. **Upstream port**: PR opened against `sun9huni/claude-codex-
   coordination:main` carrying the generic version of all 4 changes;
   scrub gate clean; template tests (skill-lint, hook-tests,
   harness-concurrency, harness-lifecycle) all PASS; CHANGELOG
   `[0.4.1]` present; `v0.4.1` tag pushed after merge.
8. **Codex mirror**: `.codex/skills/handoff-writer/SKILL.md` +
   `AGENTS.md` (workspace) + `.agent/templates/AGENTS.md.example`
   (upstream) describe the new state field + `--release` verb.

## Implementation Steps

(High level; /write-plan will decompose.)

1. `scripts/handoff.sh` slice mode: add `state` field handling
   (insert/preserve like the other 6 managed fields, default `active`
   for new batons); add `--release` flag (clears owner+heartbeat,
   sets `state: released`); add auto-commit step (untracked slice-
   prefixed contracts/plans, guarded by clean-rest-of-tree).
2. `.claude/hooks/stop-handoff-check.sh`: add session-start marker
   read (env `SESSION_START_EPOCH` set by SessionStart hook, else
   skip cleanly) + per-slice "heartbeat older than session start"
   warning. Add `state ∈ enum` validation.
3. `.agent/status/README.md` (workspace + upstream): document the
   `state` field + the new verbs.
4. `scripts/status.sh` index_mode (both workspace + upstream): add
   `state` column; closed/released slices render with their state
   instead of a heartbeat freshness annotation.
5. `tests/run-harness-concurrency.sh` extension or new
   `tests/run-harness-lifecycle.sh`: 4 new fixture assertions.
6. Codex parity: `AGENTS.md`, `.codex/skills/handoff-writer/SKILL.md`,
   `.agent/templates/AGENTS.md.example` (upstream).
7. `/handoff` skill (workspace + upstream): mention the auto-commit
   + the `state` field + `--release` in its Step text.
8. CHANGELOG (upstream): `[0.4.1]` entry.
9. Upstream port via branch + PR + scrub gate + tag.

## Verification

- workspace: `bash tests/run-harness-concurrency.sh` → 5/5 GREEN;
  new lifecycle test → 4/4 PASS (or N/N).
- workspace fixtures: handoff.sh `--release` on a temp baton → state
  flips; auto-commit on a clean tree with untracked slice contracts
  → commit created; auto-commit on a dirty tree → SKIPPED + warning.
- upstream: `bash tests/{run-skill-lint,run-hook-tests,run-harness-
  concurrency,run-harness-lifecycle}.sh` → all PASS; scrub of
  `git diff main...HEAD` clean; PR open against `main`.

## Risks

- **scope creep**: bundling 4 items invites "while I'm here" — guard
  by the "forbidden change scope" + Non-Goals list above.
- **auto-commit surprise**: if the "dirty-tree" guard is implemented
  wrong, users get unexpected commits. → fixture must include
  dirty-rest-of-tree case (expect SKIP); behavior must be visible
  (one-line message). Rollback is `git reset HEAD~1`.
- **Stop hook false-positive**: if SESSION_START_EPOCH is unset (hook
  not yet upgraded, or session started outside Claude Code), the
  check should be silent — not block, not warn. → implementation
  uses `[ -n "${SESSION_START_EPOCH:-}" ]` guard.
- **workspace ↔ upstream divergence**: `status.sh` already differs;
  index_mode must stay byte-identical between the two for the state
  column. → diff check in the verification step.
- **Codex compatibility break**: if Codex `handoff-writer` doesn't
  understand `state`, it might overwrite it during a Codex handoff.
  → Codex SKILL.md must document `state` as a preserved field
  (mirror of the 6 managed fields preservation rule).

## Rollback

- workspace: each commit is per-task; `git revert <sha>` restores
  prior behavior. Auto-commits made by handoff.sh are tagged with a
  distinctive prefix in the commit message for easy identification.
- upstream: branch + PR; if a problem surfaces post-merge, revert
  the merge commit on `main`. `v0.4.1` tag can be re-pointed or
  deleted (`git tag -d v0.4.1 && git push origin :refs/tags/v0.4.1`).
- if `state` field causes baton-incompatibility on the field, the
  defaulting rule (`absent → active`) means deleting the field from
  a single baton restores v0.4.0-shaped behavior locally.

## Progress Log

- 2026-05-29: contract drafted (status: pending). 4-item bundle for
  the per-slice safety/lifecycle gaps surfaced by the system-issues
  review. Codex parity + auto-commit included. 사용자 승인 대기.
- 2026-05-29: 사용자 "approved" → /write-plan (15 tasks) → 사용자
  "approved" → /execute-plan.
- 2026-05-29: **DONE** (15 tasks, 11 commits workspace + 5 commits
  upstream + 1 fixup each). Workspace: ac688b2..e999e6c (T1-6) →
  c0ed783..eeb3cd8 (T7-9) → 915b84b (stdin-hang fix). Upstream:
  ca0d07e..5b64f43 (T11-13) → b005cdd (stdin-hang fix) → squash f9a59b0.
  PR #2 merged; tag v0.4.1 pushed. main: f5dd897 → f9a59b0. See plan
  `.agent/plans/harness-v041-lifecycle-hotfix-20260529.md`.

## Notes

Closed the 4 follow-on gaps surfaced after v0.4.0 shipped:
(1) Stop hook now warns when a session ends without `/handoff` for a
slice it owns (per-session marker file written by SessionStart Job 1c
→ Stop compares baton heartbeat to session start epoch).
(2) `state: active|closed|released` field added to per-slice baton
schema; preserved by `handoff.sh` if present, defaults to `active` if
absent; only `handoff.sh --release` writes `released`. Rendered in
the derived `CURRENT.md` index with distinct icons (🔒/📦).
(3) `handoff.sh --release <slice>` verb — terminal handoff that clears
owner_session/owner_label/heartbeat + sets state: released, preserving
owner_agent/remaining_actions/contract_pointers/body. Idempotent.
(4) Auto-commit on handoff (both claim and release paths): untracked
`.agent/contracts/<slice>-*.md` and `.agent/plans/<slice>-*.md` files
matching the active slice are auto-committed if the working tree is
otherwise clean. Slice's own baton modification intentionally NOT
auto-committed. `--no-auto-commit` opt-out flag added. Non-fatal under
all error paths.

Bonus: discovered + fixed a stdin-hang bug during the Task 14 hard
gate. The Job 1c/missed-handoff blocks called `json.load(sys.stdin)`
guarded only by `[ ! -t 0 ]`; when stdin was connected but had no JSON
(common in `bash test.sh` invocations and CI), the read blocked
waiting for EOF. Replaced with `select.select(stdin, 0.05s)` before
the read — non-blocking, no hang. Fix landed in workspace 915b84b +
upstream b005cdd before the gate passed.

Ship: PR #2 squash-merged with both CI runners green
(ubuntu/macos ~12s each); tag v0.4.1 pushed.
https://github.com/sun9huni/claude-codex-coordination/pull/2

Codex parity included: `AGENTS.md`,
`.codex/skills/handoff-writer/SKILL.md`, and `/handoff` SKILL all
updated. EXCLUDED per scope: Notion handoff-log v2 (SLURM
auto-detect, granular Decisions/Artifacts, Codex Step-5 mirror);
deeper per-slice git-snapshot audit log; retroactive
`state: closed` migration of existing live batons (fragmap's body
says CLOSED but its frontmatter still shows `state: active` — out of
scope, a future session can run `handoff.sh --release fragmap` if
desired).
