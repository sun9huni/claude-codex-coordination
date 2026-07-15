---
contract: .agent/contracts/harness-concurrent-handoff-20260526.md
slice: harness
status: done
total_tasks: 16
estimated_total_min: 78
replan: "v2 2026-05-26 — full re-plan (option B) after Task 1 inventory revealed the active_slice/CURRENT.md consumer surface (29 files) was under-decomposed. Tasks 1-6 done verbatim; 7-16 re-derived for complete coverage, migration ordered AFTER all consumers are index-aware."
---

# Plan v2 — Concurrent-session handoff (per-slice batons + derived index)

Phase order: Setup(1) → Schema(2-3) → Tests-red(4) → Core scripts(5-6) →
Consumer adaptation: hooks(7-8) + skills(9-11) + harness docs(12-14) →
Migration(15) → Verify(16). **Migration runs only after every live consumer
of `active_slice`/CURRENT.md is index-aware**, so flipping CURRENT.md to the
derived index never breaks a reader.

Consumer surface from Task 1 inventory (`.agent/scratch/concurrent_handoff_inventory.txt`):
- **OUT OF SCOPE** (contract Non-Goal #2, Codex mirror): `AGENTS.md`,
  `.agent/templates/AGENTS.md.example`.
- **OUT OF SCOPE** (point-in-time records, not live behavior): Section C
  historical fragmap/mmgbsa contracts' "edit CURRENT.md" Done-When steps.
  `_template.md` Done-When is already generic — no change.

---

## Task 1: Snapshot CURRENT.md + inventory active_slice dependents

- **Status**: done (2026-05-26; no commit — outputs are transient state/+scratch artifacts. backup byte-identical, inventory = 29 files / 83 lines, code break-risk = 2 hooks only)
- **Files touched**: `.agent/handoffs/state/CURRENT.md.pre-concurrent-bak`, `.agent/scratch/concurrent_handoff_inventory.txt`
- **Verification**: backup exists + inventory non-empty → PASS (125)

## Task 2: Document status frontmatter schema in status/README.md

- **Status**: done (2026-05-26, commit 0e70157; code-review APPROVE, +44 lines doc-only)
- **Files touched**: `.agent/status/README.md`
- **Verification**: `grep -A2 'Frontmatter schema' .agent/status/README.md | grep -q owner_session` → PASS

## Task 3: Initialize frontmatter on all 5 status files

- **Status**: done (2026-05-26, commit 7a5312b for vav1/fksfold-core/arl; fragmap+mmgbsa frontmatter on disk, commit deferred to Task 15 to avoid burying pending Step 3/4 edits. code-review APPROVE)
- **Files touched**: 5 `.agent/status/*.md`
- **Verification**: 5/5 frontmatter parse → PASS

## Task 4: Test harness with 5 red assertions

- **Status**: done (2026-05-26, commit 1c7d57a; 5/5 FAIL exit 1, hermetic. code-review APPROVE. Side effect: early subagent runs of AGENT_ROOT-unaware handoff.sh bumped live CURRENT.md version 15→20 + 5 spurious state/sessions/2026-05-27-* snapshots — self-healing/superseded by Task 15+16)
- **Files touched**: `tests/run-harness-concurrency.sh`
- **Verification**: harness runs, 5 FAIL, exit 1 → PASS (red baseline)

## Task 5: handoff.sh per-slice baton + AGENT_ROOT seam → assertion 1 green

- **Status**: done (2026-05-26, commit ed1cf1d; assertion 1 PASS. AGENT_ROOT seam + slice mode, no-slice backward-compat preserved. code-review APPROVE)
- **Files touched**: `scripts/handoff.sh`
- **Verification**: `assertion 1: PASS`

## Task 6: status.sh index mode → assertions 2+4 green

- **Status**: done (2026-05-26, commit bd43aa0; assertions 2+4 PASS. index mode + AGENT_ROOT seam, atomic no-clobber. code-review APPROVE)
- **Files touched**: `scripts/status.sh`
- **Verification**: `assertion 2: PASS`, `assertion 4: PASS`

---

## Task 7: SessionStart hook → claim-check + index-aware bootstrap → assertion 3 green

- **Status**: done (2026-05-26, commit e533706; assertion 3 PASS, 1-4 green / 5 FAIL. code-review APPROVE_WITH_NITS — embedded ritual "source of truth" text deferred to Task 14)
- **Prereq tasks**: 4, 5, 6
- **Files touched**: `.claude/hooks/session-start-decay-check.sh`
- **Change shape**: Two coordinated changes to one file. (a) **Claim-check**: honor env `AGENT_ROOT` + `ENTERING_SLICE` + `OWNER_SESSION`; if the entered slice's `status/<slice>.md` has a heartbeat < 30 min under a *different* owner_session, print a "live claim" warning (greppable: `live claim|claimed`), stale/same-owner → silent. (b) **Job 2 bootstrap de-scalar**: stop parsing `active_slice`/`owner_agent` from CURRENT.md (lines 85-86); instead source the bootstrap context from the per-slice status frontmatter + the derived index — robust to BOTH old-format (pre-migration) and index-format (post-migration) CURRENT.md, since per-slice frontmatter (Task 3) is the authority. Keep graceful when fields empty.
- **Verification**: `bash tests/run-harness-concurrency.sh 2>&1 | grep 'assertion 3'` → PASS; AND a manual fixture check that Job 2 still emits a sensible bootstrap (no bare `active_slice: ?`) when fed per-slice frontmatter.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git checkout .claude/hooks/session-start-decay-check.sh`

## Task 8: Stop hook validates active-slice frontmatter → assertion 5 green

- **Status**: done (2026-05-26, commit 0d87863; **all 5 assertions GREEN exit 0**. per-slice validation, README.md edge case handled, non-blocking. code-review APPROVE)
- **Prereq tasks**: 3, 4
- **Files touched**: `.claude/hooks/stop-handoff-check.sh`
- **Change shape**: Repoint from validating CURRENT.md frontmatter to validating the active slice's `status/<slice>.md` frontmatter (honor `AGENT_ROOT` + `ENTERING_SLICE`). Required fields become per-slice (`owner_session`/`owner_agent`/`version`/`heartbeat`/no `<placeholder>`); drop the CURRENT.md `active_slice` scalar requirement (lines 129-140). Preserve single-session backward-compat: a valid populated slice exits 0.
- **Verification**: `bash tests/run-harness-concurrency.sh 2>&1 | grep 'assertion 5'` → PASS
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout .claude/hooks/stop-handoff-check.sh`

## Task 9: /handoff skill + skills/README → per-slice handoff model

- **Status**: done (2026-05-26, commit 9dacff7; code-review APPROVE. landed via subagent)
- **Prereq tasks**: 5, 6
- **Files touched**: `.claude/skills/handoff/SKILL.md`, `.claude/skills/README.md`
- **Change shape**: Rewrite the /handoff skill steps: instead of "fill/edit CURRENT.md fields", instruct "update the active slice's `status/<slice>.md` frontmatter (owner_session/heartbeat/remaining_actions) then run `scripts/handoff.sh <agent> <slice>`; CURRENT.md is regenerated by `status.sh index`, never hand-edited." Update `skills/README.md` /handoff one-liner to match. No `<...>`-in-CURRENT.md instruction remains.
- **Verification**: `grep -q 'status/<slice>.md\|per-slice' .claude/skills/handoff/SKILL.md && ! grep -q 'edit CURRENT.md\|Fill or update CURRENT.md' .claude/skills/handoff/SKILL.md`
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git checkout .claude/skills/handoff/SKILL.md .claude/skills/README.md`

## Task 10: Read-consumer skills (slice-status, meeting-report, route) → index/per-slice source

- **Status**: done (2026-05-26, commit b598048; code-review APPROVE. subagent delegation BLOCKED by .claude/skills/ self-mod guard → applied by direct Edit after user authorization)
- **Prereq tasks**: 6
- **Files touched**: `.claude/skills/slice-status/SKILL.md`, `.claude/skills/meeting-report/SKILL.md`, `.claude/skills/route/SKILL.md`
- **Change shape**: Update each to read `active_slice`/owner/remaining_actions from the per-slice status frontmatter or the derived index, not the CURRENT.md `active_slice` scalar. meeting-report (line 39) sources per-slice; slice-status (48,59) reads the slice's own status frontmatter; route (3) description points at the index for the "who owns what" view.
- **Verification**: `! grep -l 'CURRENT.md.*active_slice\|active_slice.*CURRENT.md' .claude/skills/{slice-status,meeting-report,route}/SKILL.md`; spot-read each updated reference is coherent.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git checkout .claude/skills/{slice-status,meeting-report,route}/SKILL.md`

## Task 11: Incidental CURRENT.md references (contract-check, debug, write-plan) → index model

- **Status**: done (2026-05-26, commit fd6afe1; code-review APPROVE. debug via subagent; contract-check/write-plan via direct Edit after self-mod guard block + authorization)
- **Prereq tasks**: 6
- **Files touched**: `.claude/skills/contract-check/SKILL.md`, `.claude/skills/debug/SKILL.md`, `.claude/skills/write-plan/SKILL.md`
- **Change shape**: Minor reference fixes. contract-check (16): `cat CURRENT.md` → read active slice status + index. debug (28): `CURRENT.md.failure_log` → per-slice status `failure_log` field. write-plan (45): docs-phase example "CURRENT.md update" → "status/<slice>.md update (CURRENT.md regenerated)".
- **Verification**: spot-read 3 references coherent with index model; `grep -c 'CURRENT.md' .claude/skills/{contract-check,debug,write-plan}/SKILL.md` reviewed (no stale scalar/edit instruction).
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout .claude/skills/{contract-check,debug,write-plan}/SKILL.md`

## Task 12: CLAUDE.md + WORKFLOW.md ritual → index model

- **Status**: done (2026-05-26, commit c82540d; code-review APPROVE. CLAUDE.md edit flagged as self-mod by harness → user explicit "go" after diff review)
- **Prereq tasks**: 9, 10, 11
- **Files touched**: `CLAUDE.md`, `WORKFLOW.md`
- **Change shape**: Update the 3-step ritual (CLAUDE.md 9-13, 47, 52; WORKFLOW 14-17, 66): CURRENT.md is a DERIVED index (read it to see who owns which slice); per-slice working state lives in `status/<slice>.md`; a session claims a slice (owner_session + heartbeat); end-of-session updates the slice file + `handoff.sh <agent> <slice>` (no hand-edit of CURRENT.md). Keep the "SSOT" framing but point it at per-slice + index.
- **Verification**: `grep -q 'derived index\|파생 인덱스' CLAUDE.md && grep -q 'owner_session\|status/<slice>.md' WORKFLOW.md`; no stale "edit/update CURRENT.md frontmatter by hand" instruction.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git checkout CLAUDE.md WORKFLOW.md`

## Task 13: handoff.md + takeover-prompt.md → per-slice fields + liveness model

- **Status**: done (2026-05-26, commit e0d39b6; code-review APPROVE, no security flag — .agent/handoffs/ outside guarded path)
- **Prereq tasks**: 9
- **Files touched**: `.agent/handoffs/handoff.md`, `.agent/handoffs/takeover-prompt.md`
- **Change shape**: handoff.md (20,29,47,52): "CURRENT.md fields that MUST be filled" → "per-slice status frontmatter fields (owner_session/heartbeat/remaining_actions)". takeover-prompt.md (16,45,48,56): replace binary `owner_agent ≠ you → takeover` with per-slice liveness (heartbeat fresh under other owner_session → coordinate; stale → take over); entry view = the index.
- **Verification**: `grep -q owner_session .agent/handoffs/handoff.md && grep -q 'heartbeat\|liveness' .agent/handoffs/takeover-prompt.md`
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout .agent/handoffs/handoff.md .agent/handoffs/takeover-prompt.md`

## Task 14: Remaining harness docs (handoffs/README, hooks/README, policies, status/README)

- **Status**: done (2026-05-26, commit 69c4649; code-review APPROVE. harness 5/5 green, bash -n ok. resolves Task 7 hook-bootstrap nit. direct Edit — self-mod authorized)
- **Prereq tasks**: 7, 8
- **Files touched**: `.agent/handoffs/README.md`, `.claude/hooks/README.md`, `.agent/policies.md`, `.agent/status/README.md`, `.claude/hooks/session-start-decay-check.sh`
- **Change shape**: handoffs/README (12,17,21,23): CURRENT.md = derived index, working updates go to per-slice. hooks/README (10,14): update the SessionStart + Stop hook row descriptions to the new behaviors (claim-check; per-slice validation). policies.md (65): handoff requirement → per-slice + index. status/README (5): reconcile the "CURRENT.md tracks the single in-progress task" line with the new derived-index reality (already added the schema section in Task 2; fix the lead-in line). **Task 7 nit**: the SessionStart hook's *embedded* bootstrap text still says "CURRENT.md is the source of truth" + ritual step 1 "re-read CURRENT.md frontmatter" — refine to the index model (CURRENT.md = derived index entry view; per-slice files authoritative).
- **Verification**: `grep -q 'claim\|per-slice\|derived' .claude/hooks/README.md`; spot-read the 4 files coherent; no stale "hand-edit CURRENT.md" remains in harness docs.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git checkout .agent/handoffs/README.md .claude/hooks/README.md .agent/policies.md .agent/status/README.md`

## Task 15: Migrate fragmap+mmgbsa state + regenerate CURRENT.md index → leak resolved

- **Status**: done (2026-05-27; CO-EXECUTED by concurrent sessions using my committed scripts. fragmap.md self-migrated by the fragmap claude session (handoff.sh claude fragmap + status.sh index, version 6); CURRENT.md → derived index; mmgbsa.md frontmatter migrated by me (post-5627 actionable items). Codex mirror (AGENTS.md etc., Non-Goal #2) done independently by a parallel codex session. **Leak RESOLVED** (0 mmgbsa refs in fragmap index section). Concurrency gate honored — ran only after fragmap idle + codex stale.)
- **Prereq tasks**: 7, 8, 9, 10, 11, 12, 13, 14
- **Files touched**: `.agent/status/fragmap.md`, `.agent/status/mmgbsa.md`, `.agent/handoffs/CURRENT.md`
- **Change shape**: The migration proper (runs only after all consumers are index-aware). Move fragmap remaining_actions (Step 4 done / Step 5 / Step 6) from old CURRENT.md into `status/fragmap.md` frontmatter; move mmgbsa items (Stage 2-4; 5627 → COMPLETED, closing the stale "RUNNING") into `status/mmgbsa.md` frontmatter; also commits the Task-3 frontmatter for these two files (deferred). Then run `scripts/status.sh index` against the live `.agent` to regenerate CURRENT.md as the derived index. **CONCURRENCY GATE**: per contract §Rollback, run only when other sessions are idle — execute-plan will pause and confirm before this task.
- **Verification**: `bash tests/run-harness-concurrency.sh 2>&1 | grep 'assertion 4'` → PASS; `grep -c 'Stage 2-4\|node disambig' .agent/status/fragmap.md` → 0; live CURRENT.md begins with the GENERATED index header; live SessionStart hook (Task 7) emits a sensible bootstrap against it.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: restore `state/CURRENT.md.pre-concurrent-bak`, `git checkout .agent/status/{fragmap,mmgbsa}.md`

## Task 16: Full green + bash -n + single-session regression + handoff snapshot

- **Status**: done (2026-05-27; harness 5/5 GREEN, bash -n all 4 hooks/scripts OK, no-slice handoff backward-compat OK (version 3→4 vs temp AGENT_ROOT), leak RESOLVED. Independently corroborated by codex: 5/5 + skill-lint 14/14 + skills-sync + tool-audit PASS. plan + contract finalized.)
- **Prereq tasks**: 15
- **Files touched**: none (verification) + plan/contract status updates
- **Change shape**: Run full harness (5/5 green), `bash -n` on every modified hook/script, a single-session no-slice `handoff.sh` regression (against a temp AGENT_ROOT, not live), confirm contract Done-When 1-7. Then set plan `status: done`, contract `Status: done` + Notes, and run a real per-slice `handoff.sh claude fragmap` to snapshot.
- **Verification**: `bash tests/run-harness-concurrency.sh; echo $?` → `0`; `for s in scripts/handoff.sh scripts/status.sh .claude/hooks/*.sh; do bash -n "$s" || echo BAD $s; done` → no BAD
- **Estimated time**: 5 min
- **Rollback (if this task only)**: n/a (verification only)
