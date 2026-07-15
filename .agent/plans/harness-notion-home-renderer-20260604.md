---
contract: .agent/contracts/harness-notion-home-renderer-20260604.md
slice: harness
status: done
total_tasks: 8
estimated_total_min: 36
---

# Plan: Harness Notion Home Auto-Renderer (Task-18)

Render the whole Mission-Control home body from the live payload so it never
drifts: dynamic cockpit (code) + `---` + verbatim static tail (template file).
Apply via MCP `replace_content`, guarded by a preservation preflight that refuses
to drop any child `<page>`/`<database>`. Tests interleave (red→green). One
Notion-MCP approval gate (Task 7).

Preservation set (must survive every render) — 4 child pages + 4 inline DB views:
- pages: FKSFold `36d1e76c3b60813095bbd653bfa4ff54`, Harness `36d1e76c3b60817ba426f522cd52e6d4`,
  Databases `36d1e76c3b6081948701dcc3b1c5c69c`, SDLs `28d1e76c3b6080949d12d5d7668bef14`
- DB views: Slices `3721e76c3b6080dc9a46c0e9074d3caf`, ADR `3721e76c3b608035b17aee8ea1996ac0`,
  Experiments `3721e76c3b608077a1bbfae049c58fde`, Reports `1413ac2108f04defb6af98f096920feb`

## Task 1: Capture the static tail into a template asset

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `.agent/notion_home_tail.md` (new)
- **Change shape**: write the current home's static tail VERBATIM (from the
  `---` after the sync-health strip through the trailing `<empty-block/>`): the
  Slices-board intro line + `# 🔄 진행 중 슬라이스` + its `<database>`+mention +
  the `<details>` 🗄️ Archives toggle (3 inline `<database>` + mentions) +
  `# 🚀 Projects` columns (`<page>`×2) + `## 🗂️ More` columns (`<page>`×2) +
  `# 📚 Docs & Standards`. Source = the home fetch captured this session.
- **Verification**: `grep -c -E '3721e76c3b6080dc|3721e76c3b608035|3721e76c3b608077|1413ac2108f0|36d1e76c3b608130|36d1e76c3b60817b|36d1e76c3b608194|28d1e76c3b608094' .agent/notion_home_tail.md`
  → 8 (all preservation URLs present).
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm .agent/notion_home_tail.md`

## Task 2: RED test — render_home() structure + tail preservation

- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: `tests/test_notion_migration.py`
- **Change shape**: add a test that monkeypatches `REPO_ROOT` to a tmp dir with a
  couple of status fixtures (one active w/ decision, one w/ agent action, one
  unclaimed) + copies the real `.agent/notion_home_tail.md` into the tmp tree, then
  calls `notion_sync.render_home()` and asserts the string contains: the 🛰️ banner,
  both card headings (Decisions / Agent queue), ≥1 chip (`` `승인 대기` `` or
  `` `RUNNING` ``/`` `대기` ``), each active slice's name, a `🩺 Sync health` line,
  a metrics line, the `---` separator, AND every preservation URL from the tail.
- **Verification**: `python -m pytest tests/test_notion_migration.py -k render_home -q`
  → fails (`AttributeError: ... render_home`).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: remove the added test.

## Task 3: GREEN — implement render_home()

- **Status**: pending
- **Prereq tasks**: 2
- **Files touched**: `scripts/notion_sync.py`
- **Change shape**: add `render_home() -> str`. Build the dynamic cockpit from
  `home_navigator_payload()` (`action_queues`: human_decisions / agent_execution /
  blockers + `running_experiments`) and `notion_audit_payload()`: 🛰️ purple banner
  + gray metrics line (active / running-jobs / unclaimed / blockers / findings
  counts) + `<columns>` of two `gray_bg` `<callout>`s (🙋 orange-text Decisions,
  🤖 blue-text Agent queue) with `- ` items `` `chip` **slice** — text`` (decision
  chip = `승인 대기`; agent chip = `RUNNING` if the slice has a running experiment
  else `대기`; text truncated ~90 chars) + 🩺 gray sync-health strip bucketing
  active slices 🟢 Fresh / 🟡 Stale / 🟠 Regex-fallback·Parser-warning. Then append
  `\n---\n` + the verbatim contents of `.agent/notion_home_tail.md`.
- **Verification**: `python -m pytest tests/test_notion_migration.py -k render_home -q`
  → passes.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py`

## Task 4: Preservation preflight (red→green)

- **Status**: pending
- **Prereq tasks**: 3
- **Files touched**: `scripts/notion_sync.py`, `tests/test_notion_migration.py`
- **Change shape**: add `_home_preserved_urls(tail_text) -> set[str]` (extract
  `<page url=...>` + `<database url=...>` ids from the tail) and
  `assert_home_preserves(body, tail_text) -> list[str]` returning the list of
  MISSING preservation ids (empty = ok). Add a test: a body that includes the tail
  → no missing; a body with one `<database>` block deleted → that id reported
  missing.
- **Verification**: `python -m pytest tests/test_notion_migration.py -k preserve -q`
  → passes (both the ok and the missing case).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py tests/test_notion_migration.py`

## Task 5: Add `--render-home` CLI

- **Status**: pending
- **Prereq tasks**: 3, 4
- **Files touched**: `scripts/notion_sync.py`
- **Change shape**: add `--render-home` to `parse_args`; in `main()` (after the
  `--audit` block) render the body, run `assert_home_preserves(body, tail)`; if any
  id is missing, print `HOME_RENDER_UNSAFE: dropped <ids>` to stderr and return 2;
  else print the body to stdout and return 0. No Notion call.
- **Verification**: `python scripts/notion_sync.py --render-home >/tmp/home.md; echo $?`
  → `0`; `grep -c -E '🛰️|🙋|🤖|🩺' /tmp/home.md` ≥ 4; `grep -c -E '3721e76c3b6080dc|1413ac2108f0|28d1e76c3b608094' /tmp/home.md` ≥ 3.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py`

## Task 6: Docs — runbook + /handoff Step 5 reference

- **Status**: pending
- **Prereq tasks**: 5
- **Files touched**: `docs/notion-sync-runbook.md`, `.claude/skills/handoff/SKILL.md`,
  `.codex/skills/handoff-writer/SKILL.md`
- **Change shape**: runbook §Section 5 — document `--render-home` (full-body
  render + preservation preflight + apply via MCP `replace_content`); supersede the
  "home is hand-rendered, Task-18 pending" wording. Both handoff skills: add to
  Step 5 that the home is refreshed via `--render-home` → `replace_content` (the
  preflight guards child pages/DBs).
- **Verification**: `grep -c render-home docs/notion-sync-runbook.md .claude/skills/handoff/SKILL.md .codex/skills/handoff-writer/SKILL.md`
  → ≥1 each; `bash tests/run-skill-lint.sh` → PASS.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout docs/notion-sync-runbook.md .claude/skills/handoff/SKILL.md .codex/skills/handoff-writer/SKILL.md`

## Task 7: Live apply via MCP replace_content  [APPROVAL GATE]

- **Status**: pending
- **Prereq tasks**: 5
- **Files touched**: Notion home page `28d1e76c-3b60-8069-a83b-eab69a131a99` (MCP, no repo file)
- **Change shape**: run `--render-home`; confirm exit 0 + preflight clean; then MCP
  `replace_content` the home with the rendered body. STOP and confirm with the user
  before this write. After: `notion-fetch` the home and verify the cockpit reflects
  live state AND all 8 preservation blocks (4 `<page>` + 4 `<database>`) are present.
- **Verification**: MCP fetch shows 🛰️ banner + 2 cards + 🩺 strip (current data) +
  🔄 Slices `<database>` + 🗄️ Archives 3 `<database>` + Projects/More 4 `<page>` +
  Docs — nothing dropped.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: re-apply the current hand-built home snapshot
  (captured this session) via `replace_content`.

## Task 8: Verification + contract close + handoff

- **Status**: pending
- **Prereq tasks**: 6, 7
- **Files touched**: `.agent/contracts/harness-notion-home-renderer-20260604.md`,
  `.agent/status/harness.md`, `.agent/handoffs/CURRENT.md`
- **Change shape**: run the full suite; set contract `status: done` + Progress Log;
  update harness baton (remaining_actions → renderer shipped; note `--render-home`
  is now the home-refresh path, tail template must track Projects/Docs changes);
  `./scripts/handoff.sh claude harness`; `./scripts/status.sh index`; commit.
- **Verification**: `python -m pytest tests/test_notion_migration.py tests/test_notion_sync_read.py -q`
  green; `python scripts/notion_sync.py --render-home` exit 0; `./scripts/tool-audit.sh`;
  `./scripts/verify.sh`; `bash tests/run-skill-lint.sh`; scoped `git diff --check`;
  `head -8 .agent/status/harness.md` shows bumped version.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git revert` the close commit; contract back to approved.
