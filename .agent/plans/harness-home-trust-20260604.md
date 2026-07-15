---
contract: .agent/contracts/harness-home-trust-20260604.md
slice: harness
status: done
total_tasks: 11
estimated_total_min: 48
---

# Plan: Harness Home Trust (baton-lint + decision-first + freshness)

Root-cause the home's trust gap: **D1** a baton-lint catches malformed/noisy
batons at write time (Stop hook, non-blocking); **D2** a thin render done-skip/cap
keeps the home clean immediately for legacy batons; **D3** a decision-first layout
puts 🙋 결정 대기 full-width on top; **D4** a freshness stamp + apply-stamp +
Stop-hook staleness warning make a forgotten handoff visible. One Notion-MCP
approval gate (Task 10). Tests interleave. #2 auto-heartbeat / #3 git dashboard
are out (separate contracts).

Grounding (verified this session):
- `scripts/notion_sync.py`: `_parse_frontmatter` (L40), `_is_done_line` (L638),
  `_action_queue_fields` (L655), `_frontmatter_status` (L793, → OK/Regex
  fallback/Parser warning/Missing), `notion_audit_payload` (L855),
  `home_navigator_payload` (L969, builds `action_queues` via `_home_action_queues`),
  `render_home` (L1057, `dec_lines`/`agt_lines` → `<columns>` + 🩺 strip; tail at
  L1144), `parse_args` (L1379), `main` (L1437, `--render-home` block at L1448).
- Tests: `tests/test_notion_migration.py` (`_write_status` helper,
  `test_render_home_structure_and_tail_preservation` L295 monkeypatches
  `REPO_ROOT`, `_HOME_TAIL_PRESERVE_IDS`), `tests/test_notion_sync_read.py`
  (frontmatter fixtures).
- Stop hook: `.claude/hooks/stop-handoff-check.sh` (non-blocking, exit 0,
  `AGENT_ROOT` seam). Hook test pattern: `tests/run-harness-lifecycle.sh` style
  (set `AGENT_ROOT` to a fixture `.agent`, run, grep stderr).
- Stamp dir exists: `.agent/handoffs/state/`.

## Task 1: RED test — lint_baton on dirty/clean fixtures

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `tests/test_notion_sync_read.py`
- **Change shape**: add `test_lint_baton_flags_dirty` + `test_lint_baton_clean_silent`.
  Using `tmp_path` + the existing status-writing helper (or a local writer),
  create batons: (a) YAML-invalid frontmatter (bare apostrophe, e.g.
  `fksfold-core's …`), (b) `remaining_actions` leading with a done-line
  (`✅ SHIPPED …`), (c) an item missing a DECISION:/AGENT:/BLOCKED: prefix; assert
  `notion_sync.lint_baton(<slice>)` returns a non-empty list naming each issue
  category. A clean baton (valid YAML, AGENT:-led, all-prefixed) → returns `[]`.
- **Verification**: `python -m pytest tests/test_notion_sync_read.py -k lint_baton -q`
  → fails with `AttributeError: module 'notion_sync' has no attribute 'lint_baton'`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: remove the added tests.

## Task 2: GREEN — lint_baton() + `--lint-baton` CLI

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**: `scripts/notion_sync.py`
- **Change shape**: add `lint_baton(slice_name: str) -> list[str]` reusing
  `_frontmatter_status` (status != "OK" → "frontmatter: <status>" issue),
  `_is_done_line` (leading `remaining_actions` item is a done-line → issue), and a
  prefix check (`re.match(r'^(DECISION|AGENT|BLOCKED):', item)` per item →
  "missing DECISION:/AGENT:/BLOCKED: prefix" issue). Add `--lint-baton` (takes the
  slice via the existing `--slice`, or a positional) to `parse_args`; in `main()`
  (after the `--audit` block) print one line per issue to stderr and return 1 if
  any, else return 0 silently.
- **Verification**: `python -m pytest tests/test_notion_sync_read.py -k lint_baton -q`
  → passes; `python scripts/notion_sync.py --lint-baton fragmap; echo $?` → prints
  a frontmatter issue + exit `1` (fragmap is currently Regex fallback).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py`

## Task 3: Stop hook calls `--lint-baton` (non-blocking)

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `.claude/hooks/stop-handoff-check.sh`, `tests/run-stop-hook-tests.sh` (new)
- **Change shape**: in the hook, for each owned/claimed slice it already inspects,
  shell out to `python "$ROOT/scripts/notion_sync.py" --lint-baton <slice>` and, if
  it exits non-zero, echo its stderr under a `[baton-lint]` prefix to the hook's
  stderr. Guard with `command -v python` + the script's existence; on any error
  skip silently. MUST stay `exit 0`. Add `tests/run-stop-hook-tests.sh`: set
  `AGENT_ROOT` to a tmp fixture with one dirty baton → assert hook stderr contains
  `[baton-lint]`; a clean fixture → assert it does NOT.
- **Verification**: `bash tests/run-stop-hook-tests.sh` → prints `PASS`; manual:
  `AGENT_ROOT=$(mktemp -d)/.agent ... ` dirty → `[baton-lint]` on stderr, exit 0.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git checkout .claude/hooks/stop-handoff-check.sh; rm tests/run-stop-hook-tests.sh`

## Task 4: D2 — thin done-skip + per-slice cap in render_home queues (red→green)

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `scripts/notion_sync.py`, `tests/test_notion_migration.py`
- **Change shape**: in `render_home`, before building `dec_lines`/`agt_lines`,
  filter `decisions`/`agents` to drop any whose `text` is `_is_done_line(...)` and
  dedupe by `slice` keeping the first (≤1 line per slice). Add a render test: a
  fixture baton whose first `remaining_actions` is `✅ SHIPPED …` and second is
  `AGENT: real work` → the rendered body shows the real work, not the ✅ line, and
  the slice appears at most once in the agent queue.
- **Verification**: `python -m pytest tests/test_notion_migration.py -k render -q`
  → passes (new done-skip/cap assertion + existing structure test still green).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py tests/test_notion_migration.py`

## Task 5: D3 — decision-first full-width layout (red→green)

- **Status**: done
- **Prereq tasks**: 4
- **Files touched**: `scripts/notion_sync.py`, `tests/test_notion_migration.py`
- **Change shape**: restructure the cockpit so 🙋 Decisions is a full-width
  `<callout icon="🙋" color="gray_bg">` placed directly under the metrics line
  (above the 🤖/🩺 section); empty decisions → `✅ 결정 대기 없음` (replacing
  `*대기 없음*`). 🤖 Agent queue + 🩺 strip move below (keep 🤖 in a callout; the
  `<columns>` may be dropped or reused for 🤖/🩺). Update
  `test_render_home_structure_and_tail_preservation` for the new strings and add
  assertions: (a) empty-decisions fixture → `결정 대기 없음` present; (b)
  non-empty fixture → the 🙋 callout's index in the body is BEFORE the 🤖 Agent
  queue marker. Preservation IDs still all present.
- **Verification**: `python -m pytest tests/test_notion_migration.py -k render -q`
  → passes; `python scripts/notion_sync.py --render-home | grep -nE '🙋|🤖'` shows
  🙋 before 🤖.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py tests/test_notion_migration.py`

## Task 6: D4a — freshness stamp line in render_home (red→green)

- **Status**: done
- **Prereq tasks**: 5
- **Files touched**: `scripts/notion_sync.py`, `tests/test_notion_migration.py`
- **Change shape**: add a stamp line to the cockpit:
  `<span color="gray">🕐 렌더 <YYYY-MM-DD> · baton @ <git-short-rev> · stale N</span>`
  where date = `datetime.date.today()`, rev = `git rev-parse --short HEAD` via
  `subprocess` (fallback `"?"` on error, never raise), and N = count of audit
  findings whose status != "OK"/"Fresh" (i.e. `len(stale) + len(soft)` already
  computed). Add a render-test assertion: body contains `🕐` and `stale`.
- **Verification**: `python -m pytest tests/test_notion_migration.py -k render -q`
  → passes; `python scripts/notion_sync.py --render-home | grep -c '🕐'` → ≥1.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py tests/test_notion_migration.py`

## Task 7: D4b — `--stamp-home-applied` writes home-render.stamp

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `scripts/notion_sync.py`, `tests/test_notion_migration.py`
- **Change shape**: add `--stamp-home-applied` to `parse_args`; in `main()` write
  `REPO_ROOT/.agent/handoffs/state/home-render.stamp` containing two lines —
  `rev: <git short rev>` and `applied: <ISO-8601 UTC timestamp>` — then return 0.
  Idempotent (overwrite). Add a test (monkeypatch `REPO_ROOT` to `tmp_path`) calling
  `main(["--stamp-home-applied"])` → exit 0 and the stamp file exists with a `rev:`
  + `applied:` line.
- **Verification**: `python -m pytest tests/test_notion_migration.py -k stamp -q`
  → passes; `python scripts/notion_sync.py --stamp-home-applied; cat
  .agent/handoffs/state/home-render.stamp` → shows `rev:` + `applied:`.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py tests/test_notion_migration.py; rm -f .agent/handoffs/state/home-render.stamp`

## Task 8: D4c — Stop-hook staleness warning (non-blocking)

- **Status**: done
- **Prereq tasks**: 3, 7
- **Files touched**: `.claude/hooks/stop-handoff-check.sh`, `tests/run-stop-hook-tests.sh`
- **Change shape**: in the hook, read `$AGENT_DIR/handoffs/state/home-render.stamp`
  `applied:` time; if any `$AGENT_DIR/status/*.md` has an mtime NEWER than that
  (`file_mtime` helper already in the hook) emit a one-line `[home-stale]` warning
  ("a baton changed since the last home apply — run `--render-home` →
  replace_content"). If the stamp is missing, warn once that the home has never
  been stamped. Stays `exit 0`. Extend `tests/run-stop-hook-tests.sh`: stamp older
  than a touched status file → `[home-stale]` present; stamp newer than all status
  files → absent.
- **Verification**: `bash tests/run-stop-hook-tests.sh` → `PASS` (both the stale
  and the clean case).
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git checkout .claude/hooks/stop-handoff-check.sh tests/run-stop-hook-tests.sh`

## Task 9: Docs — runbook + both handoff skills

- **Status**: done
- **Prereq tasks**: 2, 6, 7, 8
- **Files touched**: `docs/notion-sync-runbook.md`, `.claude/skills/handoff/SKILL.md`,
  `.codex/skills/handoff-writer/SKILL.md`
- **Change shape**: runbook — document `--lint-baton` (write-time baton validation,
  surfaced by the Stop hook), the 🕐 freshness stamp, `--stamp-home-applied`, and
  the two new Stop-hook warnings (`[baton-lint]`, `[home-stale]`). Both handoff
  skills' Step 5: after the MCP `replace_content` apply, run
  `./scripts/notion_sync.py --stamp-home-applied`; mention that the Stop hook lints
  the baton + warns if the home is stale.
- **Verification**: `grep -c -E 'lint-baton|stamp-home-applied' docs/notion-sync-runbook.md
  .claude/skills/handoff/SKILL.md .codex/skills/handoff-writer/SKILL.md` → ≥1 each;
  `bash tests/run-skill-lint.sh` → PASS.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout docs/notion-sync-runbook.md .claude/skills/handoff/SKILL.md .codex/skills/handoff-writer/SKILL.md`

## Task 10: Live apply via MCP replace_content + stamp  [APPROVAL GATE]

- **Status**: done (user "harness baton 먼저 정리 후 1회 깨끗이 적용"; also cleaned .agent/status/harness.md remaining_actions per convention before the single apply — flagged + user-approved)
- **Prereq tasks**: 5, 6, 7
- **Files touched**: Notion home page `28d1e76c-3b60-8069-a83b-eab69a131a99` (MCP, no repo file); `.agent/handoffs/state/home-render.stamp`
- **Change shape**: run `--render-home`; confirm exit 0 + preflight clean; STOP and
  confirm with the user; then MCP `replace_content` the home with the rendered body;
  then run `--stamp-home-applied`. After: `notion-fetch` the home and verify the
  cockpit is decision-first (🙋 full-width on top), the queue is quiet (no ✅-led
  lines, ≤1/slice), the 🕐 stamp is present, AND all 8 preservation blocks
  (4 `<page>` + 4 `<database>`) are intact.
- **Verification**: MCP fetch shows 🙋 full-width Decisions above 🤖 + 🩺 + 🕐 stamp
  + 🔄 Slices `<database>` + 🗄️ Archives 3 `<database>` + Projects/More 4 `<page>` +
  Docs — nothing dropped; `cat .agent/handoffs/state/home-render.stamp` shows fresh rev.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: re-apply the rendered snapshot captured just
  before this task via `replace_content`; `rm -f .agent/handoffs/state/home-render.stamp`.

## Task 11: Verification + contract close + handoff

- **Status**: done
- **Prereq tasks**: 9, 10
- **Files touched**: `.agent/contracts/harness-home-trust-20260604.md`,
  `.agent/status/harness.md`, `.agent/handoffs/CURRENT.md`
- **Change shape**: run the full suite; set contract `status: done` + Progress Log;
  update harness baton (remaining_actions → home-trust shipped; note `--lint-baton`
  runs in the Stop hook, `--stamp-home-applied` runs after each home apply, and the
  home shows a 🕐 freshness stamp; lead with the convention + a clean next action);
  `./scripts/handoff.sh claude harness`; `./scripts/status.sh index`; commit.
- **Verification**: `python -m pytest tests/test_notion_migration.py
  tests/test_notion_sync_read.py -q` green; `bash tests/run-stop-hook-tests.sh` PASS;
  `python scripts/notion_sync.py --lint-baton harness` exit 0; `--render-home` exit 0;
  `./scripts/tool-audit.sh`; `./scripts/verify.sh`; `bash tests/run-skill-lint.sh`;
  scoped `git diff --check`; `head -8 .agent/status/harness.md` shows bumped version.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git revert` the close commit; contract back to approved.
