---
contract: .agent/contracts/harness-notion-cockpit-restructure-20260602.md
slice: harness
status: done
total_tasks: 14
estimated_total_min: 52
---

# Plan: Harness Notion Cockpit Restructure

> ✅ **DONE 2026-06-02** — all 14 tasks, 14 commits (`d82eb7a`…). T1-T8 code
> (parser generalization + regex fallback + audit Regex-fallback + done-line
> skip + review fix), T9-T11 docs (Step 5.2 push, runbook cockpit/archive,
> baton-hygiene), T12-T13 Notion MCP (home Archives toggle, fragmap/fksfold-core
> rows). Verification PASS (pytest 19, --audit/--migrate, skill-lint, tool-audit,
> verify.sh, scoped diff-check). See the contract Progress Log for the full
> summary + deferred follow-ups.

Realign the Notion human surface around the one reliably-live channel (Slices
board + action queues) and demote the append-logs (ADR/Experiments/Reports) to
on-demand archives, while hardening the live channel: tolerant frontmatter
parsing (so tricky batons like fragmap populate WITHOUT cross-slice edits), clean
action-queue classification (no ✅-done lines as live next-actions), and a
reliable per-handoff push of the 8 queue/trust fields. Tests interleave (red →
green) per criterion. One Notion-MCP approval gate (Task 12).

Root-cause notes (verified during planning):
- `_regex_extract_frontmatter` only treats `decisions:` as a list; `remaining_actions:`
  is dropped to an empty scalar → fragmap (yaml.safe_load-broken) gets identity
  fields but blank queue fields. Fix = generalize block-sequence parsing to any key.
- Strict `_parse_frontmatter` returns None on YAMLError; no regex fallback wired.
- `_action_queue_fields` surfaces a leading ✅-done remaining_action as live Now/Agent Next.

## Task 1: RED test — generic block-sequence list extraction

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `tests/test_notion_sync_read.py`
- **Change shape**: add a unit test calling `notion_sync._regex_extract_frontmatter`
  on a block with a non-`decisions` key (`remaining_actions:` followed by two
  `  - "..."` items, one containing an embedded `'` and `:` that breaks strict YAML).
  Assert the returned dict has `remaining_actions` as a `list` of 2 strings (quotes
  stripped). Currently fails (key dropped / not a list).
- **Verification**: `python -m pytest tests/test_notion_sync_read.py -k block_sequence -q`
  → fails with KeyError or assert (remaining_actions not a list).
- **Estimated time**: 4 min
- **Rollback (if this task only)**: remove the added test.

## Task 2: GREEN — generalize `_regex_extract_frontmatter` list handling

- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: `scripts/notion_sync.py`
- **Change shape**: generalize the `decisions:`-only list logic so ANY top-level
  `key:` with an empty value followed by `^\s+-\s+` items collects those items into
  a list (quotes stripped), folding deeper-indented continuation lines into the
  current item — exactly the existing decisions behavior, applied to all keys. The
  `^  - (.*)$` match is content-agnostic so it survives the embedded quotes/colons
  that break `yaml.safe_load`. Preserve the `decisions` output for `contract_to_adr_rows`.
- **Verification**: `python -m pytest tests/test_notion_sync_read.py -k block_sequence
  tests/test_notion_migration.py::test_contract_to_adr_rows_for_v041 -q` → all pass
  (new list test green; decisions regression still green).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py`.

## Task 3: RED test — `_parse_frontmatter` regex fallback on YAMLError

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `tests/test_notion_sync_read.py`
- **Change shape**: add a test writing a fragmap-style status file whose frontmatter
  fails `yaml.safe_load` (block-sequence item with an embedded unescaped quote) and
  asserting `notion_sync._parse_frontmatter(path)` returns a dict with
  `remaining_actions` as a non-empty list + `heartbeat` present. Currently fails
  (returns None).
- **Verification**: `python -m pytest tests/test_notion_sync_read.py -k parse_fallback -q`
  → fails (returns None).
- **Estimated time**: 4 min
- **Rollback (if this task only)**: remove the added test.

## Task 4: GREEN — wire regex fallback into `_parse_frontmatter`

- **Status**: pending
- **Prereq tasks**: 2, 3
- **Files touched**: `scripts/notion_sync.py`
- **Change shape**: in `_parse_frontmatter`, on `yaml.YAMLError`, attempt
  `_regex_extract_frontmatter(block.splitlines())`; if it yields a non-empty dict,
  return it (keep the stderr warning so the breakage is still visible); else return
  None as before. Keep the existing strict-success path unchanged.
- **Verification**: `python -m pytest tests/test_notion_sync_read.py -k parse_fallback -q`
  passes; `python scripts/notion_sync.py --migrate slices 2>/dev/null | python -c
  "import sys,json;r=[x for x in json.load(sys.stdin)['rows'] if x['Name']=='fragmap'][0];print('Agent Next' , bool(r['Agent Next']) or bool(r['Now']))"`
  → prints a populated (non-empty) fragmap queue field.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py`.

## Task 5: RED test — audit "Regex fallback" status

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `tests/test_notion_migration.py`
- **Change shape**: extend the audit test (new case) — a yaml-broken-but-regex-parseable
  status file should appear in `notion_audit_payload()` findings with
  `status == "Regex fallback"` (NOT "Parser warning", NOT absent). A truly
  unparseable file (no recoverable keys) stays "Parser warning".
- **Verification**: `python -m pytest tests/test_notion_migration.py -k regex_fallback -q`
  → fails (no "Regex fallback" status exists yet).
- **Estimated time**: 4 min
- **Rollback (if this task only)**: remove the added test case.

## Task 6: GREEN — `_frontmatter_status` distinguishes regex fallback

- **Status**: pending
- **Prereq tasks**: 2, 5
- **Files touched**: `scripts/notion_sync.py`
- **Change shape**: in `_frontmatter_status` (audit path), detect strict-yaml-fail
  separately from total-failure: try strict yaml → OK; on failure try
  `_regex_extract_frontmatter` → if non-empty dict return ("Regex fallback") with the
  parsed fm, else ("Parser warning"). `notion_audit_payload` includes "Regex fallback"
  findings (non-Fresh). Slices-row Health stays driven by heartbeat (so fragmap, now
  populated with a heartbeat, reads Fresh) — the "Regex fallback" signal lives in
  `--audit` only (no DB schema change).
- **Verification**: `python -m pytest tests/test_notion_migration.py -k regex_fallback -q`
  passes; `python scripts/notion_sync.py --audit 2>/dev/null | grep -c "Regex fallback"`
  → ≥ 1 (fragmap).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py`.

## Task 7: RED test — done-marked leading action not surfaced as live

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `tests/test_notion_migration.py`
- **Change shape**: add a test on `_action_queue_fields` with
  `remaining_actions = ["✅✅ shipped X (done summary)", "AGENT: do the real next thing"]`
  asserting `Now`/`Agent Next` == the real next thing, NOT the ✅ line; the ✅ line is
  excluded from the queues. Currently fails (✅ line chosen as agent_next/fallback).
- **Verification**: `python -m pytest tests/test_notion_migration.py -k done_line -q`
  → fails (Now/Agent Next equals the ✅ line).
- **Estimated time**: 4 min
- **Rollback (if this task only)**: remove the added test.

## Task 8: GREEN — skip done-marked lines in `_action_queue_fields`

- **Status**: pending
- **Prereq tasks**: 7
- **Files touched**: `scripts/notion_sync.py`
- **Change shape**: add a small `_is_done_line(text)` helper (leading `✅`, or
  `DONE`/`완료`/`SHIPPED`/`CLOSED`/`KILL` marker) and skip such items when selecting
  `decision`/`agent_next`/`now`/`fallback` in `_action_queue_fields` (they are
  completed notes, not queue work). If ALL items are done-lines, fall back to the
  first item (so the row is never empty for an active slice).
- **Verification**: `python -m pytest tests/test_notion_migration.py -k done_line -q`
  passes; full `python -m pytest tests/test_notion_migration.py -q` green (no
  regression in existing queue tests).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py`.

## Task 9: Wire Step 5.2 to push the 8 queue/trust fields

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `.claude/skills/handoff/SKILL.md`, `.codex/skills/handoff-writer/SKILL.md`
- **Change shape**: in the Step 5 §5.2 (Slices DB row) instructions of both mirrored
  skills, state that the `notion-update-page` MUST set the 8 new fields
  (Headline/Now/Decision Needed/Agent Next/Blocker/Health/Sync Status/Last Sync Source)
  from `slice_to_db_row(<slice>)`, not just the core liveness fields — so Health/Decision/
  Agent do not re-blank on the next handoff. No code change (payload already carries them).
- **Verification**: `bash tests/run-skill-lint.sh` → PASS; `grep -c "Decision Needed"
  .claude/skills/handoff/SKILL.md .codex/skills/handoff-writer/SKILL.md` → ≥1 each.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout .claude/skills/handoff/SKILL.md .codex/skills/handoff-writer/SKILL.md`.

## Task 10: Docs — runbook cockpit vs archives split

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `docs/notion-sync-runbook.md`
- **Change shape**: add/adjust a subsection stating the IA principle: the Navigator
  home = action queues + live Slices board; ADR/Experiments/Reports are manual
  on-demand archives (off the home, in an "Archives" toggle / Databases page),
  backfilled via `--migrate` when needed — NOT live home views. Note the
  reliability-of-a-section = stable key × push frequency rationale.
- **Verification**: `grep -n "on-demand archive" docs/notion-sync-runbook.md` → ≥1 hit
  in a section describing the home/archive split.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout docs/notion-sync-runbook.md`.

## Task 11: Docs — baton-hygiene convention (status README + AGENTS)

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `.agent/status/README.md`, `AGENTS.md`
- **Change shape**: document the lab-wide convention: `remaining_actions` MUST lead
  with the actual next action (not a ✅-done summary) and SHOULD prefix items with
  `DECISION:` / `AGENT:` / `BLOCKED:` markers for clean Navigator action-queue
  classification; and that frontmatter list items must stay valid YAML (the regex
  fallback is a safety net, not a license). Convention only — does not edit any
  slice's baton.
- **Verification**: `grep -n "DECISION:" .agent/status/README.md AGENTS.md` → ≥1 hit each.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout .agent/status/README.md AGENTS.md`.

## Task 12: Home restructure via Notion MCP — Archives toggle  [APPROVAL GATE]

- **Status**: pending
- **Prereq tasks**: 8
- **Files touched**: Notion home page `28d1e76c-3b60-8069-a83b-eab69a131a99` (MCP, no repo file)
- **Change shape**: move the three append-log sections (🧭 최근 결정 ADR / 📊 진행 중
  실험 / 📝 최근 리포트 — each an inline DB linked view) into a single collapsed
  `🗄️ Archives` toggle (keep the DB mention-links inside), so the first viewport is
  action queues + 🔄 진행 중 슬라이스 only. The 3 DBs are NOT trashed. Use
  `update_content` (search/replace the section headings into a toggle) — preserve the
  inline `<database>` blocks. STOP and confirm with the user before this write.
- **Verification**: MCP `notion-fetch` of the home page → first viewport (before the
  first `---`) contains the action queues + Slices section; the 3 archive views are
  inside the `🗄️ Archives` toggle; all 3 `<database>` blocks still present.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: re-insert the three sections at top level from the
  pre-change home snapshot (captured this session); DBs untouched.

## Task 13: Re-push affected slice rows via MCP

- **Status**: pending
- **Prereq tasks**: 4, 8, 12
- **Files touched**: Notion Slices rows `fragmap` (…675706) + `fksfold-core` (…b21197) (MCP)
- **Change shape**: regenerate `--migrate slices`; upsert the rows whose values
  changed due to the parser fallback (fragmap now Fresh + populated queue fields,
  drop the manual "Parser warning" marker → real values) and the classification fix
  (fksfold-core Agent Next no longer the ✅-done line). Other rows unchanged.
- **Verification**: MCP `notion-fetch` of the fragmap row → Health=Fresh, Now/Agent Next
  non-empty (real remaining_actions, not the ⚠ marker); fksfold-core Agent Next ≠ the
  ✅✅ OOD-rescue line.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: re-apply the prior row values (fragmap → Parser
  warning marker) from this session's record.

## Task 14: Full verification + contract close + handoff

- **Status**: pending
- **Prereq tasks**: 6, 9, 10, 11, 13
- **Files touched**: `.agent/contracts/harness-notion-cockpit-restructure-20260602.md`,
  `.agent/status/harness.md`, `.agent/handoffs/CURRENT.md`
- **Change shape**: run the full verification suite; set contract `status: done` +
  Progress Log entry; update the harness baton (remaining_actions → shipped + the
  separate-followups note: action-queue heuristic edge cases, fragmap owner's optional
  YAML tidy); `./scripts/handoff.sh claude harness`; `./scripts/status.sh index`; commit.
- **Verification**: `python -m pytest tests/test_notion_migration.py tests/test_notion_sync_read.py -q`
  green; `python scripts/notion_sync.py --audit` + `--migrate slices` + `--migrate home`
  exit 0; `./scripts/tool-audit.sh`; `./scripts/verify.sh`; `bash tests/run-skill-lint.sh`;
  scoped `git diff --check`; `head -8 .agent/status/harness.md` shows bumped version.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git revert` the close commit; contract back to approved.
