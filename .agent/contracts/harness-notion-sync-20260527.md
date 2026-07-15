---
status: done
slice: harness
topic: notion-sync
date: 2026-05-27
owner: claude
approved_by: user (2026-05-27, "approved" after 5-question brainstorm; token prereq pending)
decisions:
  - Direction = ONE-WAY push `.agent/` (machine SSOT) → Notion (derived human view). No reverse sync.
  - Execution model = REVISED 2026-05-27 to (나) AGENT-INVOKED via the claude.ai Notion MCP. The headless (가) path was BLOCKED: the user lacks workspace-owner/admin permission to create a Notion internal integration ("사용 가능한 워크스페이스가 없습니다"). The claude.ai MCP already has write access to this workspace (it built the IA), so the sync write half runs as an agent routine via MCP, NOT a token script. `notion_sync.py --dump` (the deterministic read layer) is reused as the payload source; an agent applies it via MCP (idempotent by slug/title search). Semi-automatic (runs at handoff / on demand), not headless cron.
  - Auth = claude.ai Notion MCP session OAuth (no token file needed). The `.agent/.secrets/` scaffold + `--check-env` from T1-3 are kept (harmless) so a future owner-provided token can enable the headless (가) path as a bonus.
  - Dependency = `notion-client` (pip) in the miniconda env (the one with pandas/gemmi).
  - v1 sync surface = (a) per-slice `.agent/status/<slice>.md` frontmatter → that slice's Notion hub conclusion callout (upsert by FIXED hub page ID); (b) contract `decisions:` → Decisions DB rows (upsert by STABLE slug).
  - Idempotent UPSERT — second run is a no-op; no duplicate Notion records. `--slice <name>` and `--all`.
  - Prerequisite gate (USER): create the Notion internal integration + share the `홈` page (and its subtree) with it + provide the token. Implementation cannot run end-to-end until this is done.
---

# Notion sync — keep the Notion human-view true to `.agent/` SSOT

## Purpose

The Notion reporting IA (hubs + Reports/Decisions/Artifacts DBs) currently holds
**hand-written snapshots** — the slice-hub conclusions and the project-hub
"지금 한 줄" were typed by an agent and immediately start drifting from the
machine SSOT in `.agent/status/<slice>.md` + `.agent/contracts/`. This change
adds a one-way push so the Notion view stays true to source without manual
double-maintenance.

## Current State

- Notion IA live (built 2026-05-27): `홈` → 2 project hubs + 5 slice hubs
  (fixed page IDs below) + `📚 Databases` subpage holding Reports/Decisions/
  Artifacts (+ legacy 프로젝트기록). Linked views + charts wired.
- Slice hub page IDs: fragmap `36d1e76c-3b60-8136-8921-ee505191976d`,
  mmgbsa `36d1e76c-3b60-8178-aa35-e69e2be57dc4`, vav1 `36d1e76c-3b60-810e-8aa5-e9e4706c8b8a`,
  fksfold-core `36d1e76c-3b60-81e5-94a3-fddefcca6e40`, harness `36d1e76c-3b60-813d-ab19-cc9b41e69d4a`.
- Data sources: Reports `collection://94d8277f-bf77-4bc4-8acc-8b37701b830b`,
  Decisions `collection://b11ae976-472b-46dd-98d9-b42ebe2e8b7b`,
  Artifacts `collection://2e47ef6d-0511-44c7-a55f-a9eb5bfe864f`.
- `.agent/status/<slice>.md` now carry per-slice frontmatter
  (owner_session/owner_agent/version/last_updated/heartbeat/remaining_actions/
  contract_pointers) — the sync source. Contracts carry `decisions:` in frontmatter.
- The Notion writes so far were via the interactive claude.ai MCP (session OAuth) —
  unusable from a headless cron. Hence the internal-integration token requirement.

## Assumptions And Questions

- assumptions:
  - Notion `notion-client` (official SDK) can update page content (callout block) +
    create/update data-source rows with an internal-integration token.
  - Slice hub conclusion lives in a single, findable callout block on the hub page
    (sync rewrites that block; a stable marker — e.g. a leading `〔sync〕` token or
    a known block position — identifies it).
  - Contract `decisions:` entries are stable enough to slug (topic+date+index).
- open questions:
  - Exact upsert key for Decisions rows: a hidden "Key" rich-text property vs match-by-Title.
    Resolve in /write-plan; recommend a "Key" property = `<slice>:<contract-topic>:<n>`.
  - Whether the hub conclusion is one callout or a small set of blocks (one-line +
    remaining_actions list). v1: a single callout containing the one-liner + up to 3 actions.
- tradeoffs:
  - Headless token = real automation but a secret to guard + a 1-time user setup.
  - Rewriting a callout block each run is simple but loses any manual Notion edits to it
    (acceptable — Notion is derived).

## Constraints

- allowed change scope:
  - `scripts/notion_sync.py` (new) — the sync engine.
  - `scripts/notion_sync.sh` (new, optional) — cron wrapper that loads `.agent/.secrets/notion.env`.
  - `.agent/notion_map.yaml` (new) — slice→hub-page-id + DS-id mapping (no secrets).
  - `.gitignore` — add `/.agent/.secrets/`.
  - `requirements`/env note — `notion-client` install.
  - A short `docs/` or skill note on running it (optional).
- forbidden change scope:
  - No reverse (Notion → `.agent/`) writes.
  - No edits to `.agent/status/*` content (read-only source) or the existing skills.
  - Token value never written to any tracked file.
  - No use of the claude.ai MCP from the script.
- external constraints:
  - Notion internal-integration token (user-provided) with access to the `홈` subtree.
  - `notion-client` available in the chosen python env.
  - Rate limits: batch + backoff; `--all` stays under Notion API limits.

## Non-Goals

1. Bidirectional sync (Notion → `.agent/`).
2. Legacy `프로젝트기록` migration/sync.
3. Real-time / webhook triggers (cron or manual only).
4. Artifacts DB auto-population (deferred to v2).
5. claude.ai MCP path (session-only; not for the headless script).
6. Full slice-body mirroring (only frontmatter conclusion + decisions).

## Done When

1. **Prereq met**: user has created the Notion internal integration, shared `홈`,
   and placed the token in `.agent/.secrets/notion.env` (gitignored).
2. `python scripts/notion_sync.py --slice fragmap` updates the fragmap hub's
   conclusion callout to reflect `.agent/status/fragmap.md` and creates any new
   Decisions rows from its contracts.
3. **Idempotent**: an immediate second run is a no-op (no duplicate Decisions rows,
   callout unchanged) — verified by row-count before/after.
4. `--all` syncs all 5 slices; a slice with missing/broken frontmatter is skipped
   with a warning, not a hard failure.
5. Token never appears in `git status`/tracked files; `.gitignore` covers `.agent/.secrets/`.
6. A dry-run mode (`--dry-run`) prints intended changes without writing.
7. Verification: a documented command sequence proving 2-4 + a fetch-back of the
   fragmap hub callout matching the status file.

## Implementation Steps

1. Confirm prereq + env: `notion-client` installed; `.agent/.secrets/notion.env` present (gitignored). verify: import + token-loaded smoke (no write).
2. `.agent/notion_map.yaml`: slice→hub_page_id + DS ids (from §Current State). verify: yaml parses, 5 slices mapped.
3. `notion_sync.py` read layer: parse `.agent/status/<slice>.md` frontmatter + linked contracts' `decisions:`. verify: prints structured dict per slice, no Notion calls.
4. Hub callout upsert: find+rewrite the slice hub's conclusion callout (stable marker). verify: `--slice fragmap` changes callout; fetch-back matches.
5. Decisions upsert: create/update Decisions rows keyed by stable slug. verify: first run creates, second run no-op (row count stable).
6. `--all`, `--dry-run`, graceful-skip, backoff. verify: `--all --dry-run` lists all; broken slice skipped.
7. Cron wrapper `notion_sync.sh` (loads secrets env) + docs/skill note. verify: `bash -n`; manual wrapper run.
8. Status/handoff update + contract → done.

## Change Discipline

- simplest adequate approach: read frontmatter → upsert 2 targets (callout + Decisions). No framework, single script + a yaml map.
- new abstractions introduced: `notion_map.yaml` (mapping), a stable-slug keying scheme.
- unrelated code touched: none.
- request-to-diff trace: 사용자 "고도화 논의" → brainstorm 방향 A (드리프트 제거) → headless one-way sync spec.

## Verification

- `python scripts/notion_sync.py --slice fragmap --dry-run` → intended changes, no write.
- `python scripts/notion_sync.py --slice fragmap` then re-run → 2nd run no-op (Decisions row count unchanged; callout identical).
- `notion-fetch` fragmap hub → conclusion callout matches `.agent/status/fragmap.md`.
- `git status` → no token / `.agent/.secrets/` tracked.
- `bash -n scripts/notion_sync.sh`.

## Risks

- secret leak: token in a tracked file → mitigated by `.gitignore` + env-only load + dry-run default-safe. HIGH severity, low likelihood with the gitignore guard.
- upsert dup: wrong key → duplicate Decisions rows. Mitigated by stable-slug "Key" property + idempotency test in Done-When.
- Notion API drift: schema/property-name changes break writes → map file centralizes IDs; fail loud with clear error.
- destructive overwrite: callout rewrite loses manual Notion edits → acceptable (derived view), documented.
- rate limits on `--all` → batch + backoff.

## Rollback

- revert strategy: remove cron entry, `git revert` the script + map + gitignore line.
- containment: Notion records pushed are NOT removed by git revert → manual cleanup of any wrong Decisions rows; revoke the integration token in Notion if leaked. Script is read-only by default in `--dry-run`.

## Progress Log

- 2026-05-27: /brainstorm 완료 (방향 A 선택; success=headless idempotent upsert; out-of-scope 6; constraints=token env + notion-client; rollback; triggers=Notion write+secret+script → contract 필요). status: pending, 사용자 승인 + 토큰 발급 대기.
- 2026-05-27: 사용자 "approved". status: approved → /write-plan. 토큰 발급(사전조건)은 실행 전 별도 진행.
- 2026-05-27: /execute-plan T1-6 완료 (foundation: gitignore, map, skeleton, read layer, test, dry-run — 6 commits, token-independent). T1-6 dry-run으로 push 미리보기 검증.
- 2026-05-27: TOKEN GATE에서 차단 발견 — 사용자가 워크스페이스 owner/admin 아니라 internal integration 생성 불가. 사용자 결정: 실행모델 (가)headless → (나)MCP-driven 전환. write 절반(T7-10) MCP routine으로 재계획. T1-6 재사용.
- 2026-05-27: **v1 DONE (MCP-driven)**. 3 active slice hub(fragmap/mmgbsa/harness)에 〔sync〕 결론 callout 동기화(claude.ai Notion MCP) + Decisions DB에 슬라이스당 curated row 1개(fragmap Decided/mmgbsa Deferred/harness Decided). vav1/fksfold-core dormant→skip. 반복 routine = `docs/notion-sync-runbook.md` (read via notion_sync.py --dump, apply via MCP find-or-update, idempotent). 커밋 0749c33..5386dc4. v2 deferred: granular-decision + Artifacts auto-pop. status: done.

## Notes

Drift-killer for the human-read surface is live: each active slice's Notion hub
now carries a `〔sync〕` conclusion callout sourced from `.agent/status/<slice>.md`,
re-runnable idempotently via the runbook. Execution model is (나) agent-invoked
via the claude.ai Notion MCP (headless-token path blocked by workspace
permissions; scaffold kept for a future owner-provided token). v1 = callouts +
1 curated Decision/slice; granular contract-decision and Artifacts auto-population
deferred to v2 (needs a curation rule). Plan: `.agent/plans/harness-notion-sync-20260527.md`.
