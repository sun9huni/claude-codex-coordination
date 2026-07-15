---
status: done
slice: harness
topic: notion-home-renderer
date: 2026-06-04
owner: claude
approved_by: user ("승인") 2026-06-04
design_spec:
implementation_plan: .agent/plans/harness-notion-home-renderer-20260604.md
decisions:
  - Render the WHOLE home body from the live payload (no drift anywhere); the static tail (Slices intro + 진행 중 슬라이스 + inline DBs + 🗄️ Archives toggle + Projects/More/Docs) lives in a fixed template file captured verbatim and concatenated after the dynamic cockpit.
  - Trigger = a manual `notion_sync.py --render-home` CLI that PRINTS the full Notion-flavored-markdown body; an agent applies it via MCP `replace_content` (no headless write). /handoff Step 5 calls it.
  - Apply uses replace_content, which preserves child pages/databases ONLY if they appear in the new body — so the tail template carries every `<page>`/`<database>` block verbatim AND `--render-home` runs a preservation preflight (refuse/warn if any current child-page/DB URL is missing from the rendered body).
  - This implements the deferred "Task-18 auto-renderer"; it does NOT change the action-queue/audit logic (already shipped) — it only FORMATS that payload into the Mission-Control layout.
---

# Harness Notion Home Auto-Renderer (Task-18)

## Purpose

Stop the Navigator home from drifting. It is hand-rendered today, so every time
a slice moves (e.g. fragmap MD-SILCS→GCMC) a human must manually re-edit the home
or it shows stale/false state — twice now this session. This renders the entire
Mission-Control home body deterministically from the live `.agent` payload, so a
single `--render-home` + one MCP apply keeps the home accurate AND styled with no
hand-editing. The dynamic content (action queues, sync health) and the styling
(banner, 2-col cards, chips, health strip) are produced from code; the stable
tail (DB views, Projects/Docs) is preserved verbatim.

## Current State

- `scripts/notion_sync.py`: `home_navigator_payload()` returns `action_queues`
  (human_decisions / agent_execution / blockers) + active_slices + the 5 sections;
  `notion_audit_payload()` returns per-slice Fresh/Stale/Regex-fallback/Parser-warning.
  `--migrate home` emits JSON only — there is NO markdown renderer.
- The live home (`28d1e76c-3b60-8069-a83b-eab69a131a99`) was hand-built this
  session: header + metrics line + 2-col gray cards (colored-text headings, status
  chips) + 🩺 sync-health strip + `---` + 🔄 Slices board (`<database>` + mention) +
  🗄️ Archives `<details>` (3 inline `<database>` blocks) + 🚀 Projects / 🗂️ More
  (`<page>` subpage links) + 📚 Docs. This exact layout is the render target.
- Home cover = `gradients_8.png`; page icon 🧭.
- The home is NOT reproduced by any command — re-rendering means re-applying the
  hand-built markdown (the drift problem this contract closes).

## Assumptions And Questions

- assumptions: the enhanced-markdown spec (callouts/columns/`<span>`/`<details>`)
  renders as used this session; `replace_content` preserves `<page>`/`<database>`
  blocks that appear in the new body; the static tail changes rarely (Projects/Docs).
- open questions: where the tail template lives (default `.agent/notion_home_tail.md`)
  — resolved at plan time; whether to also stamp the cover/icon via `--render-home`
  (default: leave cover/icon to the apply step, render body only).
- tradeoffs: full-body render = zero drift but needs the tail template kept in sync
  if Projects/Docs ever change (rare); the preservation preflight is the guardrail.

## Constraints

- allowed change scope: `scripts/notion_sync.py` (`render_home()` + `--render-home`
  + a preservation-guard helper); a new tail-template asset (default
  `.agent/notion_home_tail.md`, captured verbatim from the current home tail);
  `tests/test_notion_migration.py`; `docs/notion-sync-runbook.md`;
  `.claude/skills/handoff/SKILL.md` + `.codex/skills/handoff-writer/SKILL.md`
  (Step 5 home-render reference); optionally `.agent/notion_map.yaml`
  (`v0_5:home_page_id`); this contract + harness baton.
- forbidden change scope: headless-token / daemon / cron writes; changing the
  action-queue or audit LOGIC (format only); trashing/moving any DB or child page;
  redesigning the static tail content; editing other slices' batons.
- external constraints: Notion writes via in-session MCP only; `.agent/` is the
  source of truth; Korean-first; Notion-flavored markdown per the spec.

## Non-Goals

- Auto-applying to Notion without MCP (no headless write path).
- The Slices DB ROW updates (that is /handoff Step 5.2 — rows, not the home page).
- Re-deriving or improving the action-queue heuristic / audit (already shipped).
- A live daemon / scheduled re-render. `--render-home` is on-demand (handoff).
- Redesigning Projects/More/Docs or the Archives contents.

## Done When

- `python scripts/notion_sync.py --render-home` prints a single Notion-flavored
  markdown body = dynamic cockpit (🛰️ banner + gray metrics line + 2-col gray
  `<callout>` cards with colored-text headings + status chips + 🩺 sync-health
  strip) rendered from `home_navigator_payload()`/`action_queues`/`notion_audit_payload()`,
  then `---`, then the verbatim tail template. Exit 0, no Notion call.
- The rendered content reflects LIVE state: e.g. fragmap shows its current job
  (not a stale one); each active slice with a non-empty decision/agent item appears
  in the correct column; Stale/Regex-fallback/Fresh buckets match `--audit`; the
  metrics counts (active / running / unclaimed / blockers / findings) are correct.
- **Preservation preflight**: a helper compares the rendered body against the set of
  `<page>`/`<database>` URLs in the tail template (and, when run live, the current
  home's children); `--render-home` exits non-zero / prints a clear error if any
  would be dropped — so a bad render can never delete a child page or DB.
- Tests (no network): pytest asserts the rendered body contains the banner, both
  card headings, ≥1 chip, each active slice in the right queue, the health line,
  the metrics line, AND every tail `<page>`/`<database>` URL (preservation).
- Runbook documents `--render-home` + the `replace_content` apply + the preflight;
  `/handoff` Step 5 references `--render-home` for the home (supersedes the
  "home is hand-rendered, Task-18 pending" note).
- Verification: `python -m pytest tests/test_notion_migration.py
  tests/test_notion_sync_read.py`, `--render-home` exit 0, `./scripts/tool-audit.sh`,
  `./scripts/verify.sh`, `bash tests/run-skill-lint.sh`, scoped `git diff --check`,
  AND one live MCP `replace_content` apply + fetch confirming the home is intact
  (cockpit current + Slices board + Archives DBs + Projects/Docs all preserved).

## Implementation Steps

1. capture the current home tail verbatim into the template asset; confirm it has
   all `<page>`/`<database>` URLs
   verify: template file contains the 3 archive DBs + Slices DB + 4 Projects/More pages
2. RED test: `render_home()` output structure (banner/cards/chips/per-slice/health/
   metrics) + tail-URL preservation
   verify: pytest fails (no render_home yet)
3. implement `render_home()` (dynamic cockpit from payload) + concat tail template
   verify: the RED tests pass
4. RED test + implement the preservation preflight (drops a tail URL → guard fails)
   verify: pytest covers both pass/refuse
5. add `--render-home` CLI (prints body, runs preflight, exit code)
   verify: `--render-home` exit 0, body printed, no Notion call
6. docs: runbook `--render-home` section + /handoff Step 5 reference (both skills)
   verify: grep + skill-lint
7. live apply [APPROVAL GATE]: MCP `replace_content` the home with the rendered body; fetch + confirm intact
   verify: fetch shows current cockpit + Slices board + Archives DBs + Projects/Docs
8. verification + contract close + handoff
   verify: full suite green; baton bumped; CURRENT.md regen

## Change Discipline

- simplest adequate approach: reuse the existing payload functions; the renderer is
  pure string formatting + a fixed tail file; no new data sources.
- new abstractions introduced: `render_home()` + a preservation-guard helper + one
  template asset. No classes, no config.
- unrelated code touched: none (format-only; no logic changes to queues/audit).
- request-to-diff trace: user "B 진행 후 A 구축" → A = render the Mission-Control
  home from the payload so it stops drifting (Task-18).

## Verification

- `./scripts/verify.sh`
- task-specific: `python -m pytest tests/test_notion_migration.py tests/test_notion_sync_read.py`;
  `python scripts/notion_sync.py --render-home`; `./scripts/tool-audit.sh`;
  `bash tests/run-skill-lint.sh`
- manual check: live MCP apply + fetch — home cockpit reflects current state and
  the Slices board / Archives DBs / Projects/Docs are all still present.

## Risks

- regression risk: a wrong/incomplete tail template + `replace_content` could delete
  a child page or DB — mitigated by the mandatory preservation preflight + the test
  asserting every tail URL is present.
- integration risk: enhanced-markdown nuances (nested callout-in-column, chips) —
  already validated live this session; tests pin the structure.
- hidden dependency risk: if Projects/Docs change in Notion, the tail template goes
  stale — documented; the preflight catches dropped URLs, not added ones.

## Rollback

- revert strategy: `render_home()`/CLI/template/doc/skill changes via `git revert`.
  The live home: re-apply the current hand-built markdown snapshot (captured this
  session) via `replace_content`.
- containment strategy: zero compute / no SLURM / no /mnt/data; the preservation
  preflight prevents child-page/DB loss; nothing applied to Notion until the Step-7
  approval gate.

## Progress Log

- 2026-06-04: contract drafted via /brainstorm. Q1 = full-body render + verbatim
  tail-template file (zero drift; preservation preflight guards child pages/DBs).
  Q2 = manual `--render-home` CLI, MCP-applied, called from /handoff Step 5.
  Approval: pending.
- 2026-06-04 (DONE — /write-plan → /execute-plan, 8 tasks, user approved plan +
  the T7 MCP gate "적용"): **Status → done.** T1 captured `.agent/notion_home_tail.md`
  (verbatim tail: Slices board + Archives DBs + Projects/More pages + Docs; 8
  child URLs). T2-T3 `render_home()` — 🛰️ banner + metrics + 2-col gray Decisions/
  Agent callout cards (chips: 승인 대기, RUNNING/대기 from action text) + 🩺
  health strip from `home_navigator_payload()`+`notion_audit_payload()`, then `---`
  + verbatim tail. T4 `assert_home_preserves` preflight (reports any tail `<page>`/
  `<database>` URL missing from the body). T5 `--render-home` CLI (prints body;
  `HOME_RENDER_UNSAFE`+exit 2 if a child would drop). T6 docs (runbook §5 Task-18
  SHIPPED + 'Rendering the home'; both handoff skills Step 5 → `--render-home`).
  T7 LIVE: MCP `replace_content` applied the rendered body to the home; fetch
  confirmed the live cockpit (fragmap = GCMC 6245 RUNNING, accurate) + ALL 8
  preservation blocks (4 `<page>` + 4 `<database>`) intact. Verified pytest 21,
  --render-home/--audit/--migrate exit 0, tool-audit, verify.sh, skill-lint 14,
  scoped diff-check. The home is now regenerable via one `--render-home` →
  `replace_content`; no more hand-edit drift. Note: agent-queue shows baton-hygiene
  noise (fksfold-core migration note, harness 'no in-flight') — faithful to the
  payload; self-resolves as owners apply the leading-next-action convention.
  Possible follow-up (not in scope): a render_home agent-queue filter/cap.
