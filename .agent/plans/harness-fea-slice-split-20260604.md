---
contract: .agent/contracts/harness-fea-slice-split-20260604.md
slice: harness
status: in-progress
total_tasks: 8
estimated_total_min: 40
---

# Plan: Split FEA into its own `fea` slice

Phase 1 (T1–T6) = ADDITIVE `fea` slice registration — touches ZERO bytes of the
harness baton (asserted). Phase 2 (T7–T8) = GATED on the concurrent autopilot
session's harness claim going stale (heartbeat >30min); migrates the FEA content
out of the harness baton into `fea.md` + syncs Notion + closes.

Grounding (verified this session):
- `scripts/status.sh` L21 `SLICES="fragmap mmgbsa vav1 fksfold-core arl harness"`;
  per-slice fns (`slice_fragmap` …) + a `case` dispatch (~L507/L515).
- `.claude/skills/slice-status/SKILL.md`: arg-hint L4 + mapping table L23–28
  (last row `harness | .agent/status/harness.md | workspace root`).
- `WORKFLOW.md` §1 routing table L37–42 (last row = harness).
- `.agent/notion_map.yaml`: `slices:` L7 + `v0_5:slice_row_ids:` L33–38.
- `scripts/notion_sync.py`: `_SLICE_TO_PROJECT` L733 (`_HARNESS_PROJECT` /
  `_FKSFOLD_PROJECT`); `slice_to_db_row` L763 default `_FKSFOLD_PROJECT`.
- No `VALID_SLICES` in the stop hook (one fewer site).
- Stub template: `.agent/status/arl.md` (an existing unclaimed slice baton).

## Task 1: Create the `fea` baton stub

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/status/fea.md` (new)
- **Change shape**: write a minimal valid baton modeled on `.agent/status/arl.md`
  (read it first): all required frontmatter fields (owner_session: "" unclaimed,
  owner_agent: claude, version: 1, last_updated: today, heartbeat: "" , state:
  active), `remaining_actions` = 1–2 items, each prefixed + NOT done-led, e.g.
  `"AGENT: FEA (FKSFold Experiment Autopilot) workstream — adopt this slice on the
  next autopilot handoff; Phase 1+2a SHIPPED, Phase 2 (Stage-2 watch + mmgbsa/
  fksfold generalization) queued."` and `"DECISION: FEA Phase 2 진행 여부 (autopilot
  owner)."`; `contract_pointers` → the 3 FEA files (experiment-autopilot +
  phase1 + phase2a). Body ≤25 lines: what FEA is, that code lives in
  `scripts/fea/` + `analysis/` (NOT moved), live-truth pointers.
- **Verification**: `python scripts/notion_sync.py --lint-baton fea; echo $?` → `0`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/status/fea.md`

## Task 2: Register `fea` in status.sh + the /slice-status skill

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**: `scripts/status.sh`, `.claude/skills/slice-status/SKILL.md`
- **Change shape**: status.sh — add `fea` to the `SLICES=` list (L21) and a `case`
  arm `fea)` in the dispatch (reuse a generic/default scan if there is one, else a
  minimal `slice_fea()` that scans `.agent/status/fea.md` + `scripts/fea/` recent
  files — keep it tiny, mirroring the lightest existing slice fn). slice-status
  skill — add a mapping-table row `| `fea` | `.agent/status/fea.md` |
  `FKSFold-Boltz_Advancement/` |` and append `fea` to the arg-hint examples (L4).
- **Verification**: `./scripts/status.sh fea >/dev/null 2>&1; echo $?` → `0` (no
  "unknown slice"); `grep -c "fea" .claude/skills/slice-status/SKILL.md` → ≥1;
  `bash tests/run-skill-lint.sh` → PASS.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git checkout scripts/status.sh .claude/skills/slice-status/SKILL.md`

## Task 3: Register `fea` in WORKFLOW.md §1 routing

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `WORKFLOW.md`
- **Change shape**: add a routing-table row after the harness row (L42):
  `| FEA / experiment autopilot / scripts/fea / preflight·watch·postflight·capture | `.agent/status/fea.md` | `.agent/contracts/harness-experiment-autopilot-20260604.md` | 실험 자동화 파이프라인(advisory/gated); FEA 코드=scripts/fea+analysis. harness(Notion·조정)와 구분 |`.
- **Verification**: `grep -c 'status/fea.md' WORKFLOW.md` → ≥1.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `git checkout WORKFLOW.md`

## Task 4: `fea` in notion_map.yaml + slice_to_db_row project map

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `.agent/notion_map.yaml`, `scripts/notion_sync.py`
- **Change shape**: notion_map.yaml — add a `fea:` entry under `slices:` (mirror an
  existing slice's shape) and a placeholder `fea:` line under
  `v0_5:slice_row_ids:` (value `""` — backfilled with the real row id in Task 5).
  notion_sync.py — add `"fea": _HARNESS_PROJECT` to `_SLICE_TO_PROJECT` (FEA is
  agent-ops tooling). Optionally add a tiny test
  `test_slice_to_db_row_fea_project` asserting `slice_to_db_row("fea")["Project"]
  == "Harness / Agent Ops"`.
- **Verification**: `python -c "import sys;sys.path.insert(0,'scripts');import
  notion_sync;print(notion_sync.slice_to_db_row('fea')['Project'])"` → `Harness / Agent Ops`;
  `python -m pytest tests/test_notion_migration.py -k fea_project -q` (if test added) → passes.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout .agent/notion_map.yaml scripts/notion_sync.py`

## Task 5: Create the Notion Slices-DB `fea` row [MCP — additive insert]

- **Status**: pending
- **Prereq tasks**: 1, 4
- **Files touched**: Notion Slices DB (MCP `notion-create-pages`, no repo file); `.agent/notion_map.yaml` (backfill `slice_row_ids[fea]`)
- **Change shape**: compute `slice_to_db_row("fea")`; create ONE new page in the
  Slices data source (`v0_5:slices_db_data_source_id` 01c936b7-…) with those
  properties (Name=fea, Status=활성, Project=Harness / Agent Ops, the cockpit
  fields from the stub). STOP and confirm with the user before this MCP write
  (additive insert). Then record the new page id under
  `v0_5:slice_row_ids[fea]` in notion_map.yaml.
- **Verification**: `notion-fetch` the new row → Name=fea + Project set;
  `grep -A0 'fea:' .agent/notion_map.yaml` shows a real UUID under slice_row_ids.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete/archive the Notion `fea` row; revert the notion_map backfill.

## Task 6: Phase 1 close — assert harness untouched, regen index, verify, commit

- **Status**: pending
- **Prereq tasks**: 2, 3, 4, 5
- **Files touched**: `.agent/handoffs/CURRENT.md` (regen)
- **Change shape**: assert `git diff --stat .agent/status/harness.md` is EMPTY
  (Phase-1 additive guarantee); run `./scripts/status.sh index` (CURRENT.md now
  lists `fea`); run the verify suite; commit the Phase-1 additive changes (fea.md
  + status.sh + skill + WORKFLOW + notion_map + notion_sync + CURRENT.md).
- **Verification**: `git diff --stat .agent/status/harness.md` → empty;
  `grep -c 'fea' .agent/handoffs/CURRENT.md` → ≥1; `./scripts/verify.sh` exit 0;
  `bash tests/run-skill-lint.sh` PASS; `./scripts/tool-audit.sh` exit 0;
  `python -m pytest tests/test_notion_migration.py tests/test_notion_sync_read.py -q` green.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git revert` the Phase-1 commit.

## Task 7: PHASE 2 [GATED] — migrate FEA content harness→fea once autopilot claim stale

- **Status**: pending
- **Prereq tasks**: 6
- **Files touched**: `.agent/status/harness.md`, `.agent/status/fea.md`
- **GATE**: before doing ANYTHING here, verify the harness baton's `heartbeat` is
  >30min old (autopilot claim stale): `python3 - <<'PY'` reading
  `.agent/status/harness.md` heartbeat vs now; if <30min, STOP — do not run this
  task (report "Phase 2 still gated; autopilot claim fresh"). This is an approval/
  timing gate: /execute-plan must STOP and confirm staleness (or user "go").
- **Change shape**: move the FEA `Current status` bullet(s) + the FEA
  `remaining_actions` items from `.agent/status/harness.md` into `.agent/status/fea.md`
  VERBATIM (from the latest committed harness baton — no rewriting); leave the
  harness baton carrying only Notion/coordination-infra content. Set fea.md owner
  to the migrating session (or leave unclaimed if just relocating). Both batons
  must remain `--lint-baton` clean.
- **Verification**: `git diff .agent/status/harness.md` shows FEA removed;
  `git diff .agent/status/fea.md` shows it added; `--lint-baton harness` and
  `--lint-baton fea` both exit 0.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git checkout .agent/status/harness.md .agent/status/fea.md`

## Task 8: PHASE 2 — sync Notion + close contract + handoff

- **Status**: pending
- **Prereq tasks**: 7
- **Files touched**: `.agent/contracts/harness-fea-slice-split-20260604.md`, `.agent/status/harness.md`, `.agent/status/fea.md`, `.agent/handoffs/CURRENT.md`; Notion (MCP)
- **Change shape**: sync Notion — `--handoff-emit harness` + `--handoff-emit fea`
  → MCP `replace_content` (home) + `update_properties` (both rows) →
  `--stamp-home-applied`. Set contract `status: done` + Progress Log;
  `./scripts/handoff.sh claude harness` (+ fea if owned); `./scripts/status.sh index`; commit.
- **Verification**: Notion fetch shows harness (infra only) + fea (FEA) as
  distinct rows + the home; full suite green; CURRENT.md regen.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: re-apply prior Notion snapshot; `git revert` the close commit.
