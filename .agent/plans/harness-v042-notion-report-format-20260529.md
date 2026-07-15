---
contract: .agent/contracts/harness-v042-notion-report-format-20260529.md
slice: harness
status: done
total_tasks: 9
estimated_total_min: 32
---

# Plan — Harness v0.4.2 Notion report format

워크스페이스 전용 변경 (업스트림 템플릿은 Notion 파일이 없어서 v0.4.2 포트 없음).
모든 commit은 master 브랜치 직접 (v0.4.1과 같은 패턴).

Phase order: **Test 1 (RED) → Impl 1 (GREEN) → Test 2 (RED) → Impl 2 (GREEN)
→ Docs (runbook + Claude SKILL + Codex SKILL) → Live smoke → Finalize**.

이벤트 분류 매핑 (고정, 이번 contract 기준):

| 한글 라벨 | 색 (Notion bg) | 이모지 | 키워드 (우선순위 순) |
|---|---|---|---|
| 차단 | red_bg | ⚠️ | blocker, blocked, 차단, FAIL, stuck |
| 출시 | green_bg | 🚀 | ship, shipped, released, "tag v", "PR #" + merged, MERGED |
| 수정 | orange_bg | 🐛 | fix, fixed, bug, 수정, hotfix |
| 결정 | purple_bg | ✅ | decided, 결정, "agreed on", 확정 |
| 설계 | gray_bg | 📝 | contract, approved, planning, spec, drafted |
| 작업 (default) | blue_bg | 🛠 | DONE, completed, implementing, 작업 |

우선순위: 차단 > 출시 > 수정 > 결정 > 설계 > 작업. 첫 매치 즉시 반환.

---

## Task 1: Red — classify_event unit tests

- **Status**: done (2026-05-29, commit a68e367; 8 tests RED w/ AttributeError; 6 existing tests still GREEN; code-review APPROVE)
- **Prereq tasks**: none
- **Files touched**: `/home/ubuntu/tests/test_notion_handoff_log.py`
- **Change shape**: Append a new test class or test functions covering `classify_event(conclusion)` (which does NOT exist yet — these are RED until Task 2 lands). Cover all 6 event types + priority resolution + default. Cases:
  (a) `"✅ Template v0.4.1 SHIPPED ... PR #2 merged"` → `event_type == "출시"`, color `"green_bg"`, emoji `"🚀"`.
  (b) `"⚠️ Blocked on SLURM queue — stuck waiting"` → `event_type == "차단"`, color `"red_bg"`, emoji `"⚠️"`.
  (c) `"🐛 Fixed stdin-hang in hook"` → `event_type == "수정"`, color `"orange_bg"`, emoji `"🐛"`.
  (d) `"결정: AB Stage 1 통과로 Stage 2 진행"` → `event_type == "결정"`, color `"purple_bg"`, emoji `"✅"`.
  (e) `"Contract approved, /write-plan next"` → `event_type == "설계"`, color `"gray_bg"`, emoji `"📝"`.
  (f) `"Implementing the run-harness-lifecycle test"` (no specific keyword from higher tiers) → default `event_type == "작업"`, color `"blue_bg"`, emoji `"🛠"`.
  (g) Priority resolution: `"v0.4.1 SHIPPED — bonus stdin-hang fix"` (출시 + 수정 둘 다 매치) → `event_type == "출시"` (출시 우선).
  (h) Priority resolution: `"Blocker hit during v0.4.1 release"` (차단 + 출시) → `event_type == "차단"` (차단 가장 높음).
  Import the function from `scripts.notion_sync` (or however the module is structured). The test file's existing imports give the pattern.
- **Verification**: `cd /home/ubuntu && /home/ubuntu/miniconda3/bin/python -m pytest tests/test_notion_handoff_log.py -q 2>&1 | tail -10` — expect failures pointing to `ImportError: cannot import name 'classify_event'` or `AttributeError`. RED baseline confirmed.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout tests/test_notion_handoff_log.py`

## Task 2: Green — classify_event() impl in notion_sync.py

- **Status**: done (2026-05-29, commit 2a4e1d4; priority-ordered keyword match; 14/14 tests GREEN; code-review APPROVE)
- **Prereq tasks**: 1
- **Files touched**: `/home/ubuntu/scripts/notion_sync.py`
- **Change shape**: Add `classify_event(conclusion: str) -> dict` after `iso_week()`. Returns `{"event_type": str, "event_emoji": str, "event_color": str}`. Implementation: a single list-of-tuples lookup ordered by priority (차단 first), each tuple = `(event_type, emoji, color, keyword_list)`. Iterate; first keyword match wins. Match is case-insensitive substring (`keyword.lower() in conclusion.lower()`). Default = the last tuple (작업/🛠/blue_bg) — no keywords, falls through. Compact, ~25-line function. Add module docstring note linking to the contract.
- **Verification**: `cd /home/ubuntu && /home/ubuntu/miniconda3/bin/python -m pytest tests/test_notion_handoff_log.py -q 2>&1 | tail -5` — expect Task 1's tests PASS (8/8 or however many). No new failures.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout scripts/notion_sync.py`

## Task 3: Red — payload extension test

- **Status**: done (2026-05-29, commit 184af0c; new test FAILs on missing event_type key (RED); 14 existing tests still GREEN; code-review APPROVE)
- **Prereq tasks**: 2
- **Files touched**: `/home/ubuntu/tests/test_notion_handoff_log.py`
- **Change shape**: Add one test that calls `handoff_log_payload("harness")` (or a fixture slice) against the live `.agent/status/<slice>.md` (the existing test pattern in this file may already use a temp fixture — match that). Assert the returned dict contains keys `event_type`, `event_emoji`, `event_color` AND the values match expected `classify_event` output for that conclusion. Until Task 4, this fails (`KeyError`).
- **Verification**: `cd /home/ubuntu && /home/ubuntu/miniconda3/bin/python -m pytest tests/test_notion_handoff_log.py -q 2>&1 | tail -5` — expect 1 FAIL on the new test.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout tests/test_notion_handoff_log.py`

## Task 4: Green — extend handoff_log_payload with event_type fields

- **Status**: done (2026-05-29, commit 894ecdf; payload.update(classify_event(...)) before return; 15/15 GREEN; live harness payload returns event_type "출시"; documented scope expansion to also relax pre-existing strict-equality test assertion (required by all-tests-green verification); code-review APPROVE_WITH_NITS)
- **Prereq tasks**: 3
- **Files touched**: `/home/ubuntu/scripts/notion_sync.py`
- **Change shape**: At the end of `handoff_log_payload()` (just before `return payload`), call `classify_event(payload["conclusion"])` and merge its 3 keys into the dict. Backward-compatible — existing keys unchanged.
- **Verification**: (a) `cd /home/ubuntu && /home/ubuntu/miniconda3/bin/python -m pytest tests/test_notion_handoff_log.py -q` — ALL tests GREEN. (b) `/home/ubuntu/miniconda3/bin/python /home/ubuntu/scripts/notion_sync.py --handoff-log --slice harness 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('event_type'), d.get('event_color'), d.get('event_emoji'))"` → expect output `출시 green_bg 🚀` (because harness's current `remaining_actions[0]` is the v0.4.1 SHIPPED message).
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout scripts/notion_sync.py`

## Task 5: Runbook — Handoff lab-log section rewrite

- **Status**: done (2026-05-29, commit b950c8e; section body fully rewritten to v0.4.2 (7 subsections); 5 preserved sections at original line numbers; code-review APPROVE)
- **Prereq tasks**: 4
- **Files touched**: `/home/ubuntu/docs/notion-sync-runbook.md`
- **Change shape**: Rewrite the "Handoff lab-log (weekly digest)" section (currently around line 78+). New content covers: (1) toggle hub template (`<details color="<slice_bg>">` + `<summary>` + 4-row inline table: 상태/진행 중/다음/갱신); (2) event-typed callout template per Weekly Digest entry (`<callout icon="..." color="..._bg">` with bold Korean label + identifier line + body lines + `<span color="gray">chg:<digest></span>` footer); (3) the event classification mapping table (the 6-row table from the plan header above, copy-paste); (4) the priority order rule; (5) gate behavior unchanged (chg substring); (6) backfill policy (다른 슬라이스는 다음 handoff에서 자동 전환, 수동 backfill 없음). Keep the existing "Why MCP-driven" / "Routine" / "Idempotency" / "v1 scope" / "Notion IDs" sections untouched.
- **Verification**: `grep -q '이벤트 분류 매핑' /home/ubuntu/docs/notion-sync-runbook.md && grep -q '출시.*green_bg.*🚀' /home/ubuntu/docs/notion-sync-runbook.md && grep -q '<details color=' /home/ubuntu/docs/notion-sync-runbook.md && echo RUNBOOK_OK` — expect `RUNBOOK_OK`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout docs/notion-sync-runbook.md`

## Task 6: Claude /handoff SKILL — Step 5 rewrite

- **Status**: done (2026-05-29, commit 70cca00; Step 5 body v0.4.2 — toggle + event callout + Korean-first; skill-lint 14/14; code-review APPROVE)
- **Prereq tasks**: 5
- **Files touched**: `/home/ubuntu/.claude/skills/handoff/SKILL.md`
- **Change shape**: Rewrite "## Step 5 — Notion lab-log (best-effort, non-blocking)" (currently around line 98). New content: (1) v0.4.2 format — toggle hub + 이벤트 타입별 callout; (2) payload now includes `event_type` / `event_emoji` / `event_color` from `notion_sync.py --handoff-log`; (3) Korean labels for narrative + English identifiers preserved (file paths, CLI flags, version SHA, etc.); (4) point to `docs/notion-sync-runbook.md` § Handoff lab-log for templates; (5) gate behavior unchanged; (6) non-blocking + best-effort behavior unchanged. Keep the step explicitly Claude-only with a one-line note about Codex parity (covered in v0.4.2's Codex mirror).
- **Verification**: `grep -q 'event_type' /home/ubuntu/.claude/skills/handoff/SKILL.md && grep -q '한글\|Korean' /home/ubuntu/.claude/skills/handoff/SKILL.md && bash /home/ubuntu/tests/run-skill-lint.sh 2>&1 | tail -3 | grep -q 'PASS' && echo SKILL_OK` — expect `SKILL_OK`. Skill-lint must still PASS.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout .claude/skills/handoff/SKILL.md`

## Task 7: Codex handoff-writer — add Notion Step 5 mirror

- **Status**: done (2026-05-29, commit 9d6b6b3; new section appended, parity by design, defensive on MCP availability; code-review APPROVE)
- **Prereq tasks**: 6
- **Files touched**: `/home/ubuntu/.codex/skills/handoff-writer/SKILL.md`
- **Change shape**: Add a new section (or extend Workflow) documenting Codex's Notion lab-log step — same v0.4.2 format (toggle + event callout), conditional on Codex's Notion MCP being configured. Defensive: if MCP unavailable, warn-only / skip (same pattern as Claude). Point to the same `docs/notion-sync-runbook.md` § Handoff lab-log + classification table. Code: payload from `scripts/notion_sync.py --handoff-log --slice <slice>`, then MCP writes mirror Claude's. Keep the existing Codex handoff-writer Workflow / Guardrails / Output contract sections intact — append the new Notion section.
- **Verification**: `grep -q 'event_type\|Notion lab-log\|이벤트' /home/ubuntu/.codex/skills/handoff-writer/SKILL.md && grep -q 'best-effort\|warn-only\|non-blocking' /home/ubuntu/.codex/skills/handoff-writer/SKILL.md && echo CODEX_OK` — expect `CODEX_OK`. Codex skills are not currently lint-tested by workspace tests/run-skill-lint.sh (which lints `.claude/skills/`), so no skill-lint check here.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout .codex/skills/handoff-writer/SKILL.md`

## Task 8: Live smoke — payload + simulate event classification on real slices

- **Status**: done (2026-05-29; harness=출시🚀green_bg as expected; mmgbsa=작업🛠 (default, "AB Stage 2 MD RUNNING" lacks priority-tier keywords — reasonable); fragmap=작업🛠 (default, "CLOSED/HELD" not in keyword list — possible v0.4.3 lexicon addition); 15/15 tests GREEN)
- **Prereq tasks**: 4
- **Files touched**: none (verification + smoke)
- **Change shape**: Run the payload generator against 3 live slices and assert each gets a meaningful event classification. NO Notion writes; NO file edits — just validate the local payload is correct. (Live Notion write verification will happen organically on the next /handoff call after this contract lands.)
- **Verification**: All three commands below must produce expected event_type:
  - `/home/ubuntu/miniconda3/bin/python /home/ubuntu/scripts/notion_sync.py --handoff-log --slice harness 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['event_type']=='출시', d; print('harness:', d['event_type'])"` → `harness: 출시`.
  - `/home/ubuntu/miniconda3/bin/python /home/ubuntu/scripts/notion_sync.py --handoff-log --slice mmgbsa 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('mmgbsa:', d['event_type'])"` → reasonable event_type (likely 작업 or 결정, depending on current conclusion).
  - `/home/ubuntu/miniconda3/bin/python /home/ubuntu/scripts/notion_sync.py --handoff-log --slice fragmap 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('fragmap:', d['event_type'])"` → reasonable event_type (likely 결정 or 작업 — fragmap conclusion is "✅ CLOSED ...").
  - Re-run full test suite: `cd /home/ubuntu && /home/ubuntu/miniconda3/bin/python -m pytest tests/test_notion_handoff_log.py -q` → ALL GREEN.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: n/a (verification only)

## Task 9: Finalize — contract+plan done, baton update, handoff

- **Status**: done (2026-05-29; contract+plan status: done w/ Notes; harness baton v9→v10 w/ v0.4.2 SHIPPED summary as remaining_actions[0]; handoff.sh + status.sh index ran clean; auto-commit correctly SKIPPED (other dirty changes in workspace tree); CURRENT.md harness row reflects new conclusion)
- **Prereq tasks**: 1,2,3,4,5,6,7,8
- **Files touched**: `/home/ubuntu/.agent/contracts/harness-v042-notion-report-format-20260529.md`, `/home/ubuntu/.agent/plans/harness-v042-notion-report-format-20260529.md`, `/home/ubuntu/.agent/status/harness.md`
- **Change shape**: Set contract + plan `status: done` with Notes / progress log. Update harness baton's `remaining_actions[0]` with v0.4.2 completion summary. Bump `contract_pointers` to include the new contract. Run `./scripts/handoff.sh claude harness` + `./scripts/status.sh index` to refresh frontmatter + regenerate the lab-wide index (the latter renders the new state column from v0.4.1).
- **Verification**: `head -10 /home/ubuntu/.agent/status/harness.md` shows bumped version (e.g. v10 → v11), today's `last_updated`, fresh heartbeat. `grep -q 'status: done' /home/ubuntu/.agent/contracts/harness-v042-notion-report-format-20260529.md && grep -q 'status: done' /home/ubuntu/.agent/plans/harness-v042-notion-report-format-20260529.md && echo FINALIZED`. `head -5 /home/ubuntu/.agent/handoffs/CURRENT.md` shows the index regenerated with today's `generated_at`.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout .agent/contracts/harness-v042-notion-report-format-20260529.md .agent/plans/harness-v042-notion-report-format-20260529.md .agent/status/harness.md` (note: handoff.sh's frontmatter writes would also need reverting; in practice, just edit the files back).
