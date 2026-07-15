---
status: done
slice: harness
topic: notion-ux-action-queues
date: 2026-06-02
owner: codex
approved_by: user approved design spec on 2026-06-02
design_spec: docs/superpowers/specs/2026-06-02-notion-navigator-action-queues-design.md
implementation_plan: docs/superpowers/plans/2026-06-02-notion-navigator-action-queues.md
decisions:
  - Navigator Home first viewport centers on separate human decision and agent execution queues.
  - Slices DB main view becomes project-row oriented for full-board scanning.
  - Notion remains a derived view of .agent; reverse sync is rejected.
  - Short queue fields are computed from existing batons first; new required status frontmatter fields are deferred.
  - Notion schema changes are approval-gated and must be applied through MCP-backed manual upserts, not daemon or headless token writes.
---

# Harness Notion UX Action Queues Contract

## Purpose

Make the Notion Navigator and Slices DB usable as a daily project operating
view. The user should immediately see what they need to decide, what agents can
execute next, and whether each project/slice row is trustworthy.

## Current State

- Approved design spec:
  `docs/superpowers/specs/2026-06-02-notion-navigator-action-queues-design.md`.
- Current Slices row generation lives in `scripts/notion_sync.py`
  `slice_to_db_row()`.
- Current implementation copies `remaining_actions[0]` into `Next Action`,
  truncating at 500 characters.
- Navigator Home exists, but current content and runbook language still mix
  setup guidance, status summaries, and derived-view instructions.
- Audit found stale or mismatched row risks for slices such as `mmgbsa` and
  `fragmap`, plus fragile YAML frontmatter parsing warnings.

## Scope

Allowed changes:

- `scripts/notion_sync.py`
- `tests/test_notion_migration.py`
- `tests/test_notion_sync_read.py` if needed for parser/audit fixtures
- `docs/notion-sync-runbook.md`
- `docs/superpowers/plans/2026-06-02-notion-navigator-action-queues.md`
- this contract and harness status handoff files

Approval-gated changes:

- Notion Slices DB schema updates
- Notion Navigator Home page update
- Any live MCP writes to Notion

Forbidden changes:

- Notion-to-`.agent` reverse sync
- daemon, cron, or headless token write path
- production service side effects
- unrelated slice baton edits
- required new frontmatter fields in every status file during the first pass

## Done When

- `slice_to_db_row()` emits short queue fields: `Headline`, `Now`,
  `Decision Needed`, `Agent Next`, `Blocker`, `Health`, `Sync Status`, and
  `Last Sync Source`.
- `home_navigator_payload()` includes an action queue model separating human
  decisions from agent execution work.
- `scripts/notion_sync.py --audit` reports stale, parser, missing, and mismatch
  findings without Notion writes.
- `--migrate slices/home` emits payloads suitable for MCP application.
- Runbook documents the action-queue flow and approval gates.
- Required verification passes or failures are documented:
  `python -m pytest tests/test_notion_migration.py tests/test_notion_sync_read.py`,
  `python scripts/notion_sync.py --audit`, `python scripts/notion_sync.py
  --migrate slices`, `python scripts/notion_sync.py --migrate home`,
  `./scripts/tool-audit.sh`, and `./scripts/verify.sh`.

## Risks

- Adding Notion properties too early could break MCP application if schema
  names do not match. Local payload proof should come first.
- Auto-summarizing long baton prose can hide nuance. Keep bounded summaries and
  preserve original baton text in `.agent/status`.
- Parser warnings can be noisy because older contracts contain complex
  frontmatter. Audit output should separate slice-status problems from
  contract ADR warnings.

## Rollback

Revert the code, test, and runbook changes from this contract. If Notion schema
changes were applied through MCP, remove or hide the new properties/views
manually in Notion after confirming with the user. No daemon or token state is
introduced, so rollback does not require service shutdown.

## Progress Log

- 2026-06-02: contract created from approved action-queue design.
- 2026-06-02 (claude takeover from codex): local implementation completed —
  Task 3 sync-trust `--audit` (commit `d96a305`), Task 4 home `action_queues`
  payload (commit `354ad57`), Task 5 runbook Navigator Action Queues section
  (commit `30abe23`). Verification PASS: pytest 14/14
  (`test_notion_migration` + `test_notion_sync_read`), `--audit` +
  `--migrate slices` + `--migrate home` exit 0, `tool-audit.sh`, `verify.sh`,
  scoped `git diff --check`. **Task 6 (Notion MCP: Slices DB 8 properties +
  Navigator home action-queue rewrite) AWAITING USER APPROVAL** — `status`
  stays `pending` until applied or declined. Real `--audit` finding (the
  trust layer working): `fragmap` baton frontmatter fails `yaml.safe_load`
  (Parser warning → `slice_to_db_row` reads empty fm → blank Notion row =
  the user's original complaint); `arl`/`vav1` Stale (unclaimed, no
  heartbeat). Cross-slice baton fixes are out of scope for this contract.
- 2026-06-02 (claude, Task 6 MCP APPLIED + verified — user approved "전체 적용"):
  Slices DB data source `01c936b7-2afd-4425-92f7-d94148cab227` gained 8 props
  via DDL (Headline/Now/Decision Needed/Agent Next/Blocker/Last Sync Source =
  RICH_TEXT; Health + Sync Status = SELECT Fresh:green/Stale:yellow/Parser
  warning:red/State mismatch:red/MCP skipped:gray). 6 active slice rows upserted
  on `Name`: harness/mmgbsa/fksfold-core = Fresh + queue fields; arl/vav1 =
  Stale; **fragmap = Parser warning marker (NOT blank-overwritten)** — the
  trust layer prevents re-introducing the user's "blank fragmap row" complaint.
  Navigator home (`28d1e76c-…131a99`) first viewport rewritten: 내가 결정할 것 /
  에이전트가 실행할 것 / 동기화 신뢰도 prepended; stale setup callout
  ("Task 19 도입 예정", manual-inline-view instruction) removed; 5 DB-linked
  sections preserved. Live fetch confirmed home + harness + fragmap rows.
  **Status → done.** Partial/deferred (non-blocking): (1) `--audit` computes
  stale/parser/missing but NOT "State mismatch"/"Notion row missing" (those
  enum values are forward-looking; full mismatch needs live-Notion compare);
  (2) legacy `Next Action` column on rows not refreshed (superseded by the new
  Now/Decision/Agent columns in the Project-Rows view); (3) home is hand-applied
  pending the Task-18 auto-renderer; (4) action-queue quality depends on baton
  hygiene — leading `remaining_action` should be the real next action with
  `DECISION:`/`AGENT:`/`BLOCKED:` markers (some batons lead with ✅-done lines).
