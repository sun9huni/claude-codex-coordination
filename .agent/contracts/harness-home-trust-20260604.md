---
status: done
slice: harness
topic: home-trust
date: 2026-06-04
owner: claude
approved_by: user ("승인") 2026-06-04
design_spec:
implementation_plan: .agent/plans/harness-home-trust-20260604.md
supersedes: .agent/contracts/harness-notion-home-freshness-ux-20260604.md
decisions:
  - "D1 (baton-lint = root-cause fix, REPLACES former 'A' render filter as the primary mechanism): new `notion_sync.py --lint-baton <slice>` reuses `_parse_frontmatter` + `_is_done_line` to report (a) YAML-invalid frontmatter (the regex-fallback / parser-warning case — e.g. fragmap's bare apostrophe), (b) a remaining_actions list whose LEADING item is a done-line, (c) items missing a DECISION:/AGENT:/BLOCKED: prefix. The Stop hook calls it for the active slice and emits a NON-blocking warning. Fixes noise/YAML-breaks at WRITE time (the one place a human can act) instead of only masking them at render time."
  - "D2 (thin render guard = the kept, minimal part of former 'A', as a bridge): render_home()'s agent + decisions queues still skip `_is_done_line` items and cap to ONE live line per slice. Rationale: lint only fixes batons written AFTER it lands; the ~3 already-dirty batons (fragmap regex-fallback, fksfold-core migration-led) and any non-Claude (codex/cursor) writer won't self-heal, so a thin render-time skip keeps the home clean IMMEDIATELY. Format-only; does not change action_queues / audit LOGIC."
  - "D3 (B decision-first layout): 🙋 결정 대기 is lifted out of the 2-col cards into a full-width callout directly under the 🛰️ banner; renders '✅ 결정 대기 없음' when empty; 🤖 agent queue + 🩺 sync-health move below."
  - "D4 (C freshness, visible + reminded — NOT true auto): (1) render_home embeds a stamp line '🕐 렌더 <ts> · baton @ <git-rev> · stale N' (N = non-Fresh slice count from notion_audit_payload). (2) new `--stamp-home-applied` writes .agent/handoffs/state/home-render.stamp (git rev + timestamp), run by the agent right AFTER the MCP apply. (3) the existing stop-handoff-check.sh Stop hook (non-blocking, exit 0) warns when a .agent/status/*.md changed since the stamp but the home was not re-applied this session."
  - "OUT (separate follow-up contracts, NOT here): #2 mechanical-liveness auto-heartbeat (Stop hook auto-refreshing heartbeat + git rev so a forgotten /handoff loses only narrative, not liveness); #3 an always-fresh git-side dashboard as the MCP-independent fallback view. True headless/cron Notion auto-write is impossible (MCP-only write path) and is not attempted."
---

# Harness — Home Trust (baton-lint + decision-first + freshness)

## Purpose

The Notion home is only as trustworthy as the batons behind it, and the system's
accuracy is bounded at two manual points: (1) someone must remember to re-render
at `/handoff`, and (2) someone must hand-write each baton to schema. The
shipped auto-renderer (Task-18) fixed content drift but not these. This contract
attacks the ROOT: a **baton-lint** catches a malformed/noisy baton at write time
(where a human can fix it), a **thin render guard** keeps the home clean
immediately for legacy batons lint can't retro-fix, a **decision-first layout**
puts "what must I decide" at the top, and a **freshness signal** makes a
forgotten handoff visible and reminded. Mechanical-liveness auto-capture and an
MCP-independent fallback dashboard are deferred to separate contracts.

## Current State

- `scripts/notion_sync.py`: `_parse_frontmatter` (strict-YAML then regex
  fallback), `_frontmatter_status` (OK / Regex fallback / Parser warning /
  Missing), `_is_done_line` (word-boundary ✅/DONE/SHIPPED/CLOSED/완료),
  `_action_queue_fields` (already skips done lines for the Slices-DB row),
  `notion_audit_payload()` (per-slice Fresh/Stale/Regex-fallback/Parser-warning),
  `render_home()` (🛰️ banner + metrics + 2-col 🙋/🤖 callouts + 🩺 strip + `---`
  + verbatim tail), `assert_home_preserves` (preflight). `render_home`'s queue
  reads each baton's leading `remaining_actions` item verbatim — done/migration
  -led batons show as live agent work. There is no baton VALIDATOR and no record
  of when the home was last applied.
- `.agent/status/README.md` documents the baton hygiene rules (lead with the
  real next action; DECISION:/AGENT:/BLOCKED: prefix; valid YAML) — but nothing
  ENFORCES them, so fragmap is `Regex fallback` and several batons lead with ✅.
- `.claude/hooks/stop-handoff-check.sh`: NON-blocking Stop hook (exit 0; stderr
  shown to Claude) warning on stale CURRENT.md / unbumped version / invalid slice
  frontmatter; has an `AGENT_ROOT` test seam.

## Assumptions And Questions

- assumptions: lint can reuse `_parse_frontmatter`/`_is_done_line` (no new parse
  logic); the Stop hook can shell out to `notion_sync.py --lint-baton` cheaply;
  `git rev-parse --short HEAD` is available in the render context; a full-width
  `<callout>` renders above `<columns>`; the tail (8 `<page>`/`<database>` URLs)
  is untouched (lint/B/C touch the cockpit + frontmatter validation only).
- open questions (resolve at plan time): does lint run from the Stop hook only, or
  also from `handoff.sh` (default: Stop hook, the natural per-session enforcement
  point, matching where C's staleness warning lives); exact staleness signal
  (git-tracked baton change since the stamped rev vs newest status mtime — prefer
  the simplest that does not false-warn on a clean session).
- tradeoffs: lint is non-blocking (warn-only) — it nags, it does not force; the
  thin render guard is the immediate clean-up while lint heals the source over
  the next session or two. Freshness is visible + reminded, never truly auto
  (MCP-only) — accepted per the user's "표시 + 경고" choice.

## Constraints

- allowed change scope: `scripts/notion_sync.py` (`--lint-baton` + a lint
  function; thin queue skip/cap in `render_home`; decision-first layout; the
  freshness-stamp line; a `--stamp-home-applied` flag);
  `.claude/hooks/stop-handoff-check.sh` (call lint for the active slice + the
  non-blocking staleness warning); `tests/test_notion_migration.py` +
  `tests/test_notion_sync_read.py` (lint / layout / stamp tests) + the hook's
  test harness if present; `docs/notion-sync-runbook.md`;
  `.claude/skills/handoff/SKILL.md` + `.codex/skills/handoff-writer/SKILL.md`
  (Step 5: run `--stamp-home-applied` after the MCP apply; mention lint);
  this contract + harness baton. `.agent/notion_home_tail.md` ONLY if the
  decision-first layout needs a tail tweak (expected: NOT needed).
- forbidden change scope: headless-token / daemon / cron writes; changing
  `action_queues` / `notion_audit_payload` LOGIC (format + filter only); a
  BLOCKING Stop hook (must stay exit 0); editing OTHER slices' batons (lint may
  REPORT them, never rewrite them); trashing/moving any DB or child page;
  redesigning the static tail; building #2 auto-heartbeat or #3 git dashboard
  (separate contracts).
- external constraints: Notion writes via in-session MCP only; `.agent/` is the
  source of truth; Korean-first; Notion-flavored markdown per the spec; a session
  writes only its own slice's baton.

## Non-Goals

- True automatic / headless / scheduled Notion re-rendering (impossible under
  MCP-only).
- A hard Stop-gate that blocks the session (lint + staleness are warn-only).
- #2 mechanical-liveness auto-heartbeat (separate contract).
- #3 always-fresh git-side fallback dashboard (separate contract).
- Auto-fixing other slices' dirty batons (lint reports; owners fix).
- Changing the Slices-DB row path (Step 5.2) or the action-queue heuristic.

## Done When

- **D1 — baton-lint**: `python scripts/notion_sync.py --lint-baton <slice>` exits
  non-zero and prints a clear per-issue report for a fixture baton that (a) has
  YAML-invalid frontmatter, (b) leads `remaining_actions` with a done-line, or
  (c) has an item missing a DECISION:/AGENT:/BLOCKED: prefix; exits 0 silent on a
  clean baton. The Stop hook calls it for the active slice and surfaces the report
  as a NON-blocking (exit 0) warning. Verified by pytest fixtures + a hook test.
- **D2 — thin render guard**: `render_home()`'s 🤖 agent queue and 🙋 decisions
  queue skip `_is_done_line` items and show at most ONE live line per slice; a
  done-led fixture baton no longer appears as live work. Verified by a render test.
- **D3 — decision-first**: the rendered body places 🙋 결정 대기 as a full-width
  callout ABOVE the 🤖/🩺 row; empty → `✅ 결정 대기 없음`; ≥1 → each decision
  slice listed (chip `승인 대기` + slice + short text). Verified by empty/non-empty
  layout tests (the "없음" string; each decision slice above the agent-queue marker).
- **D4 — freshness**: `--render-home` body contains a stamp line matching `🕐`
  + a date + `stale` + the non-Fresh slice count from `notion_audit_payload()`;
  `--stamp-home-applied` writes `.agent/handoffs/state/home-render.stamp` (git rev
  + timestamp), exit 0, idempotent; `stop-handoff-check.sh` warns (exit 0) when a
  `.agent/status/*.md` changed since the stamp without a fresh apply, and stays
  SILENT on a clean session. Verified by a hook test via `AGENT_ROOT`.
- **Preservation intact**: `assert_home_preserves` still passes; all 8
  `<page>`/`<database>` URLs survive a render.
- Docs: runbook documents `--lint-baton`, the freshness stamp, the post-apply
  stamp step, and the new Stop-hook warnings; both handoff skills' Step 5 add
  "run `--stamp-home-applied` right after the MCP `replace_content`".
- Verification: `python -m pytest tests/test_notion_migration.py
  tests/test_notion_sync_read.py`; `--lint-baton` + `--render-home` exit as
  specified; the Stop-hook test; `./scripts/tool-audit.sh`; `./scripts/verify.sh`;
  `bash tests/run-skill-lint.sh`; scoped `git diff --check`; AND one live MCP
  `replace_content` apply + `--stamp-home-applied` + fetch confirming
  decision-first / quiet queue / 🕐 stamp / 8 preservation blocks.

## Implementation Steps

1. inspect render_home, the Stop hook, `_parse_frontmatter`/`_is_done_line`;
   confirm reuse points + the `AGENT_ROOT` seam
   verify: read-only notes
2. D1a: add a lint function + `--lint-baton <slice>` (red→green)
   verify: pytest — dirty fixtures (yaml-invalid / done-led / missing-prefix) →
   non-zero+report; clean → exit 0 silent
3. D1b: Stop hook calls `--lint-baton` for the active slice (non-blocking)
   verify: hook test via AGENT_ROOT — dirty baton → warning on stderr, exit 0
4. D2: thin done-skip + per-slice cap in render_home queues (red→green)
   verify: pytest done-led fixture → first live action (or omitted), ≤1/slice
5. D3: lift 🙋 Decisions to a full-width callout above 🤖/🩺; empty → "없음"
   verify: pytest empty/non-empty layout assertions
6. D4a: add the `🕐 렌더 … · baton @ <rev> · stale N` stamp line
   verify: `--render-home` | grep 🕐 + stale count matches `--audit`
7. D4b: add `--stamp-home-applied` writing home-render.stamp (git rev + ts)
   verify: run → stamp exists with rev+ts; idempotent; exit 0
8. D4c: extend stop-handoff-check.sh with the non-blocking staleness warning
   verify: hook test — baton changed since stamp → warns; clean → silent
9. docs + both handoff skills Step 5 + runbook (lint + freshness)
   verify: grep + `bash tests/run-skill-lint.sh`
10. live apply [APPROVAL GATE]: `--render-home` → MCP replace_content →
    `--stamp-home-applied`; fetch + confirm decision-first / quiet queue / 🕐 /
    8 preservation blocks
    verify: fetch shows new layout + stamp + Slices board + Archives + Projects/Docs
11. verification + contract close + handoff
    verify: full suite green; baton bumped; CURRENT.md regen

## Change Discipline

- simplest adequate approach: lint reuses `_parse_frontmatter`/`_is_done_line`;
  freshness reuses `notion_audit_payload` + the existing stamp directory + the
  existing Stop hook; the only new artifacts are a lint fn, a stamp file, two CLI
  flags, and two hook warning blocks. No new data sources, no classes, no config.
- new abstractions introduced: `lint_baton()` + `--lint-baton`; a queue
  dedupe/cap helper; `--stamp-home-applied`; two Stop-hook checks. Nothing else.
- unrelated code touched: none (queue/audit logic unchanged; tail unchanged;
  #2/#3 explicitly out).
- request-to-diff trace: user "handoff 깜박 → 최신성 문제 + 너 개선안 적용" then
  "현실적으로 더 개선 + 너의 추천대로 재조정" → lint (root-cause, replaces A) +
  thin render guard (bridge) + B (decision-first) + C (visible freshness);
  #2/#3 split out.

## Verification

- `./scripts/verify.sh`
- task-specific: `python -m pytest tests/test_notion_migration.py
  tests/test_notion_sync_read.py`; `python scripts/notion_sync.py --lint-baton
  <slice>`; `python scripts/notion_sync.py --render-home`; the Stop-hook test;
  `./scripts/tool-audit.sh`; `bash tests/run-skill-lint.sh`
- manual check: live MCP apply + `--stamp-home-applied` + fetch — cockpit is
  decision-first, queue quiet, 🕐 stamp present, tail/preservation intact.

## Risks

- regression risk: a layout change + `replace_content` could drop a child page/DB
  — mitigated by the unchanged `assert_home_preserves` preflight + the preservation
  test (lint/B/C touch only the cockpit + frontmatter validation, not the tail).
- false-warning risk: lint or the staleness check nags on a clean session —
  mitigated by tests asserting SILENCE on clean input; both stay non-blocking
  (exit 0) so a wrong warning can never break a session.
- hidden dependency risk: `git rev-parse` or `notion_sync.py` unavailable in the
  hook context → the hook degrades to a timestamp-only stamp / skips lint silently
  (documented; never raises, never blocks).

## Rollback

- revert strategy: `git revert` the notion_sync.py / hook / doc / skill changes;
  delete `.agent/handoffs/state/home-render.stamp`. The live home: re-apply the
  rendered snapshot captured at the Step-10 gate via `replace_content`.
- containment strategy: zero compute / no SLURM / no /mnt/data; the Stop hook
  stays exit 0 (non-blocking); `assert_home_preserves` prevents child-page/DB
  loss; nothing applied to Notion until the Step-10 approval gate.

## Progress Log

- 2026-06-04: drafted via /brainstorm (round 1) as harness-notion-home-freshness-
  ux: Q1 freshness = "표시 + 경고"; Q2 = one contract (A queue-filter + B
  decision-first + C freshness).
- 2026-06-04: RE-ADJUSTED (round 2, user "너의 추천대로 재조정"). Root-cause
  reframe: former A (render-time filter) PROMOTED/REPLACED by D1 baton-lint
  (write-time validation — fixes the source, not just the view), with D2 keeping a
  THIN render done-skip as the legacy/cross-agent bridge. B (D3) + C (D4) kept.
  #2 mechanical-liveness auto-heartbeat and #3 MCP-independent git dashboard split
  OUT to separate follow-up contracts. This file supersedes
  harness-notion-home-freshness-ux-20260604.md. Approval: pending.
- 2026-06-04 (DONE — /write-plan → /execute-plan, 11 tasks, user approved plan +
  the T10 MCP gate "harness baton 먼저 정리 후 1회 깨끗이 적용"): **Status → done.**
  Commits `0defbec`(T1 RED lint test) `aa7defd`(T2 lint_baton + --lint-baton)
  `fa3ba20`(T3 Stop-hook [baton-lint] + run-stop-hook-tests.sh) `e9b89e1`(T4 D2
  render_home done-skip + per-slice cap) `6f80f82`(T5 D3 decision-first full-width
  layout) `86b95e5`(T6 D4a 🕐 freshness stamp) `5642007`(T7 D4b --stamp-home-applied
  + home-render.stamp) `a1565cd`(T8 D4c Stop-hook [home-stale]) `1643717`(T9 docs:
  runbook + both handoff skills). T10 LIVE: cleaned the harness baton's
  remaining_actions per the convention (lint then exit 0), MCP `replace_content`
  applied the rendered home, `--stamp-home-applied` recorded it (rev 1643717),
  fetch confirmed decision-first 🙋 on top + 🕐 stamp + quiet harness queue + ALL 8
  preservation blocks (4 `<page>` + 4 `<database>`) intact + fragmap = GCMC 6245
  RUNNING accurate. Verified pytest 27, run-stop-hook-tests.sh PASS, --lint-baton
  harness / --render-home exit 0, tool-audit, verify.sh, skill-lint 14, scoped
  diff-check CLEAN. The home now self-reports freshness (🕐 stamp) and a forgotten
  handoff surfaces as a non-blocking `[home-stale]` warning; malformed batons are
  caught at write time as `[baton-lint]`. Follow-ups #2 (auto-heartbeat) / #3 (git
  fallback dashboard) remain available as separate contracts.
