---
status: done
slice: harness
topic: notion-handoff-log
date: 2026-05-27
owner: claude
approved_by: user (2026-05-27, "approved" after 5-question brainstorm)
builds_on: .agent/contracts/harness-notion-sync-20260527.md
decisions:
  - Model B — weekly rollup + daily entries. handoff → (1) overwrite slice hub 〔sync〕 callout (current state, no accumulation) + (2) upsert a (slice, ISO-week) "Weekly Digest" Report row, recording today's dated entry.
  - Research-meaningful change gate (NOT every handoff) — a daily entry is written ONLY when the slice conclusion OR its decision-set changed vs the last logged entry. Routine no-change handoffs refresh the callout only, add no log entry. (SLURM/experiment auto-detection = v2, needs a structured `experiments` field first.)
  - Trigger = the Claude `/handoff` SKILL (agent + claude.ai Notion MCP), best-effort / NON-BLOCKING (a Notion failure warns but never blocks handoff). handoff.sh (bash) is NOT modified.
  - "Last logged" state is READ FROM NOTION (the weekly row's latest entry) — no local state file.
  - Week key = ISO year-week (e.g., 2026-W22); weekly row keyed by (slice, week).
  - Scope = Claude `/handoff` only for v1. Codex handoff-writer mirror = separate/later.
  - Two layers kept distinct: this auto per-slice lab-log (daily, change-gated) vs the curated PROJECT weekly digest (meeting-to-notion, human-triggered) — the latter is out of scope here.
  - Reuses notion-sync v1 infra: scripts/notion_sync.py (read), .agent/notion_map.yaml, docs/notion-sync-runbook.md, the live DBs/hubs.
---

# Notion handoff log — per-slice weekly lab-notebook, change-gated

## Purpose

A drug-discovery research group's activity record should read like a lab
notebook: per week, the meaningful research events (verdicts, conclusions,
results), not every file save. notion-sync v1 keeps each slice's *current*
conclusion fresh (hub callout) but has no *history*. This adds an automatic,
change-gated weekly log: every Claude `/handoff` refreshes the slice's current
callout and, only when something research-meaningful changed, appends a dated
one-liner to that slice's weekly digest — so Notion gains a clean, bounded
lab-notebook timeline (1 weekly row/slice, ~52/year) without per-handoff noise.

## Current State

- notion-sync v1 (done, contract harness-notion-sync-20260527): `〔sync〕`
  conclusion callouts live on fragmap/mmgbsa/harness hubs; Decisions DB seeded;
  `scripts/notion_sync.py --dump` reads per-slice {conclusion, remaining_actions,
  decisions}; routine in `docs/notion-sync-runbook.md`; MCP-driven (no token).
- Reports DB (`94d8277f-…`) has a `Report Type` select incl. "Weekly Digest".
- The Claude `/handoff` skill (`.claude/skills/handoff/SKILL.md`) already writes
  the active slice's `.agent/status/<slice>.md` — the natural sync trigger point.
- No history/log in Notion yet; git `.agent/handoffs/state/` holds raw snapshots.

## Assumptions And Questions

- assumptions:
  - The `/handoff` skill runs in a session with the Notion MCP (Claude ✓; Codex
    has its own, out of scope here).
  - The slice conclusion (= status remaining_actions[0]) + decision-set are a good
    proxy for "research-meaningful change" for v1 (SLURM-level events fold into
    conclusion changes; explicit experiment logging is v2).
  - Reading the weekly row's latest entry from Notion is reliable enough to gate
    (no local state needed).
- open questions:
  - Weekly row identity: match by Title (`<slice> <YYYY-Www> Weekly Digest`) vs a
    `Key` property. Recommend Title-match for v1 (add Key in v2 if needed).
  - Day-entry storage: bullets in the weekly Report page body, "today" = a bullet
    led by the ISO date; same-day re-run updates that bullet.
- tradeoffs:
  - Reading-from-Notion gate = one extra fetch per handoff; acceptable (handoff is
    not hot-path).
  - Change-gate via conclusion/decision delta may miss a same-conclusion experiment
    (accepted; v2 SLURM logging covers it).

## Constraints

- allowed change scope:
  - `.claude/skills/handoff/SKILL.md` — add a best-effort "Notion lab-log" step.
  - `scripts/notion_sync.py` — add a `--handoff-log --slice X` mode emitting the
    entry payload {date, week, conclusion, decision_digest, evidence} (read-only).
  - `docs/notion-sync-runbook.md` — document the weekly-digest entry routine + gate.
  - (No new top-level files required; reuse v1 map/infra.)
- forbidden change scope:
  - `handoff.sh` (bash) unchanged — MCP is agent-only.
  - No reverse sync; no project-level digest auto-gen; no SLURM auto-detection (v2);
    no Codex mirror (separate); no granular-decision/Artifacts auto-pop (v2).
  - Sync must NEVER block or fail a handoff (best-effort, warn-only).
- external constraints:
  - claude.ai Notion MCP session OAuth (no token). Reports DB / hub IDs from
    `.agent/notion_map.yaml`.

## Non-Goals

1. Project-level weekly digest auto-generation (that's meeting-to-notion, human-triggered).
2. SLURM/experiment auto-detection for entries (v2 — needs a structured `experiments` field).
3. Granular contract-decision / Artifacts DB auto-population (v2).
4. Reverse sync (Notion → `.agent/`).
5. Backfilling past weeks from git history (start fresh from now).
6. Modifying `handoff.sh`; Codex handoff-writer mirror (separate).

## Done When

1. Running the Claude `/handoff` lab-log step for slice X **overwrites** X's hub
   `〔sync〕` callout with the current conclusion (current-state, no accumulation).
2. It **upserts a (X, ISO-week) "Weekly Digest" Report row** (creates if absent)
   and, **only if X's conclusion or decision-set changed vs the last logged entry**,
   appends/updates **today's dated entry** in that row's body (one-liner +
   evidence pointer, e.g. contract/SLURM id from the status).
3. **No-change gate**: a handoff where conclusion+decisions are unchanged vs the
   last entry refreshes the callout but adds NO new/changed day entry.
4. **Idempotent**: re-running same day with no change → 1 weekly row, today's entry
   unchanged, zero duplicates.
5. **Non-blocking**: with the MCP unavailable, the handoff completes; only a stderr
   warning is emitted (no exception, no block).
6. Verification: a documented sequence + a Notion fetch-back showing the weekly row
   with dated entries on changed days only; project-level digest remains a separate
   meeting-to-notion action.

## Implementation Steps

1. `notion_sync.py --handoff-log --slice X` (read-only): emit JSON {date, iso_week, conclusion, decision_digest, evidence}. verify: prints payload for fragmap, no Notion calls.
2. Change-gate helper (in the runbook routine): given a weekly row's latest entry text + current payload, decide WRITE (conclusion/decision changed) vs SKIP. verify: identical payload → SKIP; changed → WRITE (unit-testable on strings).
3. Weekly-row upsert routine (MCP, in runbook): find Reports row Title `<slice> <YYYY-Www> Weekly Digest` (notion-search) → create if absent (Report Type=Weekly Digest, Project, Slice, Date=week start) → set/append today's bullet in body (update_content on today's bullet, else insert). verify: first handoff creates row+entry; same-day no-change re-run = idempotent.
4. Wire into `.claude/skills/handoff/SKILL.md`: after the slice status write, a best-effort "Notion lab-log" step (overwrite callout + weekly-entry gate) with explicit "non-blocking; warn on MCP failure". verify: skill text present; no-MCP path documented as non-blocking.
5. Runbook update + a small test for the gate (string-level). verify: gate test passes.
6. Finalize: status/harness.md + contract/plan done; one live end-to-end on the harness slice.

## Change Discipline

- simplest adequate approach: reuse v1 read layer + MCP; add a week-key + change-gate; no new infra.
- new abstractions: ISO-week key, weekly-digest day-entry, change-gate.
- request-to-diff trace: 사용자 "handoff마다 반영되면 Notion 지저분" → 연구집단 랩노트북 모델 → 주간 롤업 + 변화 게이트.

## Verification

- `python scripts/notion_sync.py --handoff-log --slice fragmap` → payload JSON, no Notion call.
- Gate test: identical-vs-changed payload → SKIP/WRITE.
- Live: simulate a handoff lab-log for harness → weekly row created + today's entry; re-run no-change → idempotent (1 row, same entry); Notion fetch-back confirms.
- Non-blocking: unset/break MCP → lab-log step warns, handoff still completes.

## Risks

- gate false-negative: a meaningful experiment that doesn't change the conclusion gets no entry (accepted; v2 SLURM logging). 
- gate false-positive: cosmetic conclusion edits create a spurious entry → minor; entries are 1 line/day.
- Notion read-for-gate adds latency to handoff → small; best-effort + non-blocking caps the downside.
- skill self-modification flagged by the harness guard → user-authorized edit (as in prior harness work).

## Rollback

- revert strategy: `git revert` the `/handoff` skill + notion_sync.py + runbook changes → lab-log step gone; v1 callout sync (runbook) still available manually.
- containment: Notion weekly-digest rows are NOT removed by git revert → manual cleanup if undesired. The step is best-effort, so reverting cannot have broken handoff.

## Progress Log

- 2026-05-27: /brainstorm 완료 (model B 주간롤업+일일엔트리; research-meaningful 변화 게이트=결론/decision delta, SLURM v2; trigger=/handoff 스킬 best-effort non-blocking; last-logged=Notion read; ISO week key; Claude-only). status: pending, 사용자 승인 대기.
- 2026-05-27: 사용자 "approved". status: approved → /write-plan.
- 2026-05-27: **DONE** (7 tasks, commits 4ded374..ec6a5e3). `--handoff-log` payload + pure `gate_should_write` + 7-test suite; runbook "Handoff lab-log" routine; `/handoff` Step 5 (best-effort non-blocking, Claude-only). Live: "harness 2026-W22 Weekly Digest" Reports row + 05-27 bullet. **Idempotency bug found at live T6 + fixed**: gate now keys on a mangle-proof `change_digest = n:sha1(conclusion+slugs)` hex marker (`· chg:<digest>`) instead of raw-conclusion substring — Notion re-renders markdown on read-back, so only the hex marker survives. gate proven False (SKIP) on no-change re-run, True (WRITE) on changed digest. allowed-tools widening blocked by classifier (non-essential). status: done.

## Notes

Per-handoff change-gated weekly lab-log live for the harness slice (model B):
`/handoff` Step 5 overwrites the slice hub `〔sync〕` callout + appends a dated
bullet to the `<slice> <iso_week> Weekly Digest` Reports row ONLY when the
research conclusion or decision-set changed (mangle-proof `chg:` hex gate),
best-effort/non-blocking. Routine: `docs/notion-sync-runbook.md` § Handoff
lab-log. Curated PROJECT-level weekly digest stays a separate meeting-to-notion
action. v2 deferred: SLURM/experiment auto-detection (needs a structured
`experiments` field) + granular-decision/Artifacts auto-pop. Plan:
`.agent/plans/harness-notion-handoff-log-20260527.md`.
