---
status: done
slice: harness
topic: notion-cockpit-restructure
date: 2026-06-02
owner: claude
approved_by: user ("진행") 2026-06-02
design_spec:
implementation_plan: .agent/plans/harness-notion-cockpit-restructure-20260602.md
decisions:
  - Home first viewport = action queues + live Slices board ONLY; the ADR / Experiments / Reports inline DB views move into a collapsed "Archives" toggle (links to the DBs, not front-loaded live views).
  - All three archive DBs (Decisions / Experiments / Reports) are PRESERVED (no trash); they become manual on-demand archives, backfilled via --migrate when the user wants them current, never a per-handoff push burden.
  - The one reliable push channel (Slices DB, key = Name, every /handoff) is the investment target — Step 5.2 must push the 8 new queue/trust fields so Health/Decision/Agent do not re-blank next handoff.
  - Action-queue classification quality is improved so a baton whose leading remaining_action is a ✅-done line is NOT surfaced as the live "Agent Next"/"Now"; the real next action is chosen.
  - Baton hygiene is codified as a lab-wide CONVENTION (status README + AGENTS): remaining_actions lead with the actual next action and use DECISION:/AGENT:/BLOCKED: markers — documentation only, NOT editing other slices' batons.
  - The fragmap (and any tricky) row is fixed by HARDENING the harness parser (_parse_frontmatter falls back to the regex extractor on yaml.safe_load failure) so the row populates WITHOUT touching the cross-slice baton.
  - Notion stays a derived, one-way (read-only mirror of .agent) view; reverse-sync is rejected.
---

# Harness Notion Cockpit Restructure (archive demotion + reliable push)

## Purpose

Make the Notion human surface match what is *reliably maintained*, so the user
can track per-slice progress at a glance instead of chasing sections that never
update. Today only the Slices DB updates reliably (stable key `Name`, pushed
every `/handoff`); the ADR / Experiments / Reports home views depend on manual,
keyless, routinely-skipped MCP pushes and so sit stale on the home — the exact
"전혀 업데이트 안 됨" the user reported. This contract realigns the home around
the one live channel and demotes the append-logs to on-demand archives, then
hardens the two things that make the live channel trustworthy (push wiring +
parser robustness + clean action-queue classification).

## Current State

- `scripts/notion_sync.py`: `slice_to_db_row()` emits 8 queue/trust fields
  (Headline/Now/Decision Needed/Agent Next/Blocker/Health/Sync Status/Last Sync
  Source); `home_navigator_payload()` emits `action_queues`; `notion_audit_payload()`
  + `--audit` flag report stale/parser/missing. (Shipped 2026-06-02, contract
  harness-notion-ux-action-queues.)
- `_parse_frontmatter()` uses `yaml.safe_load` and returns None on any YAML error
  → `slice_to_db_row` reads empty fm → blank+Stale row. `_regex_extract_frontmatter()`
  (the tolerant extractor `status.sh` already relies on) exists but is NOT used as
  a fallback here. Live consequence: fragmap's baton fails yaml.safe_load → its
  Notion row is blank/Parser-warning while `status.sh` reads it fine.
- `_clean_action_marker()` classifies the leading remaining_action even when it is
  a ✅-done summary → the home "에이전트가 실행할 것" shows done lines (e.g.
  fksfold-core's ✅✅ OOD-rescue) as if they were next actions.
- Notion home `28d1e76c-…131a99`: first viewport now = action queues + Slices
  board (this session), but still also front-loads inline linked views of
  Decisions (7d) / Experiments (Running) / Reports (7d) that are stale because
  their push is manual + keyless. Decisions DB `ADR ID` is an auto_increment_id,
  so there is NO writable upsert key matching the payload's `adr_id` string.
- `/handoff` Step 5.2 (SKILL.md + .codex mirror) pushes the Slices row but does
  NOT yet push the 8 new fields → they risk re-blanking next handoff.
- `.agent/notion_map.yaml`: slices_db_data_source_id `01c936b7…` (8 props added
  this session); home page id `28d1e76c…`; archive DBs decisions `b11ae976…`,
  experiments `b1a7f410…`, reports `94d8277f…`.

## Assumptions And Questions

- assumptions: the 8 Slices properties already exist (added this session); the
  regex extractor parses fragmap-style frontmatter the strict YAML rejects; the
  home inline views can be moved into a Notion toggle without deleting the DBs.
- open questions: exact "Archives" presentation (collapsed toggle of links vs a
  single "Databases" mention) — resolved at plan time, default = collapsed toggle
  with DB mention-links; whether `--audit` should downgrade a regex-fallback parse
  from "Parser warning" to a softer "Regex fallback" status (default: yes, so a
  populated-via-fallback row is not falsely red).
- tradeoffs: parser fallback hides strict-YAML breakage (mitigated by keeping a
  distinct audit status so it is still visible); demoting archives off the home
  trades discoverability for trustworthiness (mitigated by the Archives toggle +
  Databases page).

## Constraints

- allowed change scope: `scripts/notion_sync.py`; `tests/test_notion_migration.py`
  (+ `tests/test_notion_sync_read.py` if a parser-fallback fixture fits there);
  `.claude/skills/handoff/SKILL.md` + `.codex/skills/handoff-writer/SKILL.md`
  (Step 5.2 wording to push the 8 fields); `docs/notion-sync-runbook.md`;
  `AGENTS.md`; `.agent/status/README.md` (baton-hygiene convention + marker
  guidance); the Notion home page (MCP rewrite) + archive-row backfill via MCP;
  this contract + the harness baton.
- forbidden change scope: trashing/deleting any of the 3 archive DBs; reverse
  sync (Notion→.agent); editing any non-harness slice's `.agent/status/<slice>.md`
  (fragmap YAML tidy stays the fragmap owner's OPTIONAL follow-up — the parser
  fallback removes the dependency); headless-token / daemon / cron writes;
  redesigning the ADR content model or per-DB schemas (props already added).
- external constraints: Notion writes via in-session MCP only (no headless token);
  `.agent/` remains the single source of truth; Korean-first narrative.

## Non-Goals

- Trashing or deleting the Decisions / Experiments / Reports DBs (all preserved).
- Reverse-sync (Notion → `.agent`).
- Directly editing other slices' batons to fix their frontmatter (handled by
  harness-side parser hardening; the fragmap owner may still tidy their YAML).
- ADR entry verbosity / decision-content remodeling, and a live auto-refreshing
  decisions view (explicitly rejected — archives are on-demand, not live).

## Done When

- **Home realigned:** an MCP fetch of `28d1e76c-…131a99` shows the first viewport
  = action queues (내가 결정할 것 / 에이전트가 실행할 것 / 동기화 신뢰도) + the
  live Slices board; the Decisions/Experiments/Reports inline views are inside a
  collapsed "🗄️ Archives" toggle (DB mention-links), NOT front-loaded as live
  filtered views.
- **Reliable push:** `/handoff` Step 5.2 (SKILL + Codex mirror + runbook) pushes
  the 8 queue/trust fields; documented + a test asserts the Step-5.2 row payload
  (`slice_to_db_row`) carries all 8. A re-run does not blank Health/Decision/Agent.
- **Clean classification:** a baton whose leading remaining_action is a ✅-done
  line does not surface as live "Now"/"Agent Next" — `_clean_action_marker` (or a
  selection guard) skips done-marked lines; covered by a new pytest case (red→green).
- **Parser hardened:** `_parse_frontmatter` falls back to `_regex_extract_frontmatter`
  on `yaml.safe_load` failure; `python scripts/notion_sync.py --migrate slices`
  shows `fragmap` with POPULATED fields (not blank); `--audit` reports a distinct
  "Regex fallback" (not silent, not falsely "Fresh"); new pytest fixture covers it.
- **Convention codified:** `.agent/status/README.md` + `AGENTS.md` document the
  baton-hygiene rule (lead with the real next action; DECISION:/AGENT:/BLOCKED:
  markers); runbook + AGENTS state "Slices = live cockpit; ADR/Experiments/Reports
  = manual on-demand archives off the home."
- **Verification:** `python -m pytest tests/test_notion_migration.py
  tests/test_notion_sync_read.py` green; `--audit` + `--migrate slices/home`
  exit 0; `./scripts/tool-audit.sh`; `./scripts/verify.sh`; scoped `git diff --check`.

## Implementation Steps

1. inspect: confirm `_regex_extract_frontmatter` parses fragmap's baton; confirm
   the home toggle markdown shape via the enhanced-markdown spec
   verify: a scratch call shows regex-fallback yields fragmap fields; spec fetched
2. parser hardening + audit "Regex fallback" status (red test first)
   verify: pytest fixture (yaml-broken frontmatter) populates via fallback; --audit shows the new status
3. action-queue classification: skip ✅/DONE-marked leading lines (red test first)
   verify: pytest case (✅-led remaining_actions → done line not chosen as Now/Agent Next)
4. Step 5.2 push wiring: SKILL + Codex mirror + runbook push the 8 fields; test asserts payload carries them
   verify: skill-lint pass; test asserts 8 fields present in slice_to_db_row payload
5. home restructure via MCP: move ADR/Experiments/Reports inline views into a collapsed Archives toggle
   verify: fetch shows first viewport = queues + Slices; archives in toggle; DBs intact
6. docs: runbook + AGENTS (cockpit vs archives) + status README (baton-hygiene convention)
   verify: grep shows the convention + the cockpit/archive split
7. full verification + baton + contract close + /handoff + index
   verify: pytest/audit/migrate/tool-audit/verify all green; baton bumped; CURRENT.md regen

## Change Discipline

- simplest adequate approach: reuse the existing regex extractor as a fallback
  (no new parser); reuse `slice_to_db_row` for the push (no new payload); the home
  change is a layout move (toggle), not new content.
- new abstractions introduced: none expected (a small selection guard + a status
  enum value at most).
- unrelated code touched: none — strictly harness slice files + Notion home/rows.
- request-to-diff trace: user "최대 재설계 + 3 DB 보존" → realign home to the live
  channel, demote archives, harden the live channel (push + parser + classification).

## Verification

- `./scripts/verify.sh`
- task-specific: `python -m pytest tests/test_notion_migration.py tests/test_notion_sync_read.py`;
  `python scripts/notion_sync.py --audit`; `python scripts/notion_sync.py --migrate slices`;
  `python scripts/notion_sync.py --migrate home`; `./scripts/tool-audit.sh`;
  `bash tests/run-skill-lint.sh`
- manual check: MCP fetch home (first viewport = queues + Slices; archives toggled)
  + fragmap row (populated via fallback, audit = Regex fallback).

## Risks

- regression risk: parser fallback could accept malformed frontmatter that strict
  YAML would catch — mitigated by the distinct "Regex fallback" audit status.
- integration risk: home toggle markdown via MCP may need spec-exact syntax —
  inspected in step 1; the pre-change home content is snapshotted this session for
  rollback.
- hidden dependency risk: Step 5.2 wording lives in two mirrored skills (Claude +
  Codex) — both must stay in sync (skill-lint guards mirror drift).

## Rollback

- revert strategy: Notion home — re-insert the inline views from the snapshot
  captured this session (the DBs are untouched, nothing to restore there). Code +
  docs + skills — `git revert`/`git checkout`. Parser fallback — revert the patch
  (fragmap returns to Parser-warning, no data lost).
- containment strategy: zero compute / no SLURM / no /mnt/data; all archive DBs
  preserved (no trash) so the worst case is a layout revert, not data loss.

## Progress Log

- 2026-06-02: contract drafted via /brainstorm (scope = max archive restructure;
  3 DBs preserved as manual archives; IN = home realign + Step 5.2 push wiring +
  action-queue classification + parser hardening + docs; OUT = DB trash,
  reverse-sync, cross-slice baton edits). Approval: pending.
- 2026-06-02 (DONE — /write-plan → /execute-plan, 14 tasks, 14 commits
  d82eb7a…, user approved plan + the T12 MCP gate "진행"): **Status → done.**
  Code (T1-T8 + review fix): `_regex_extract_frontmatter` generalized to parse
  ANY key's block sequence into a list (line-oriented, survives the embedded
  quotes/colons that break yaml); `_parse_frontmatter` regex fallback so
  fragmap-style batons populate instead of going blank; audit `_frontmatter_status`
  distinguishes "Regex fallback" vs "Parser warning" (strict-yaml-first);
  `_action_queue_fields` skips ✅/DONE-marked leading lines (word-boundary
  `_is_done_line`, independent-review fix for 'closedown'/'완료되지 않음' false
  positives). Docs (T9-T11): handoff Step 5.2 (Claude+Codex) pushes the 8 cockpit
  fields; runbook §Cockpit-vs-Archives; status README + AGENTS baton-hygiene
  convention (DECISION:/AGENT:/BLOCKED:, valid-YAML). Notion MCP (T12-T13):
  home first viewport = action queues + live Slices board; ADR/Experiments/Reports
  moved into a collapsed 🗄️ Archives toggle (3 DBs preserved, NOT trashed);
  fragmap row re-pushed (now Fresh + populated via fallback, was ⚠ marker),
  fksfold-core Agent Next reclassified (no ✅-done line); home sync-health
  reconciled (fragmap = Regex fallback). Verification PASS: pytest 19/19,
  --audit/--migrate exit 0, skill-lint 14/14, tool-audit, verify.sh, scoped
  diff-check. Deferred follow-ups (non-blocking): fragmap owner's baton YAML
  tidy (parser fallback removes the dependency; the fragmap row's surfaced Now
  is a migration note because its baton leads with ✅-done/migration lines =
  baton hygiene, now documented); Slices Health enum has no "Regex fallback"
  option (that signal lives in --audit only, by design); home is hand-rendered
  pending the Task-18 auto-renderer.
