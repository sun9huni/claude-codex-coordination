---
contract: .agent/contracts/harness-notion-redesign-20260529.md
slice: harness
status: done
total_tasks: 28
estimated_total_min: 145
---

# Plan — Harness v0.5 Notion IA Redesign

워크스페이스 전용 (업스트림 포트 없음). 4 phase 큰 변경:
**A. Foundation** (백업 + DB 생성/재구조화 + 코드 stub + tests RED)
**B. Backfill** (5 slices + 12+ contracts + 30+ SLURM + 인계 reports)
**C. Navigator + Automation** (홈 + /handoff Step 5 + Codex + runbook + AGENTS)
**D. Verify + Release** (4 시나리오 walk-through + spot-check + finalize)

⚠️ **사용자 휴식 지점** (USER PAUSE markers): 각 phase 끝에 자연스러운 break-point.
사용자가 spot-check 후 다음 phase 시작. /execute-plan은 이 break-point에 STOP하고 사용자 confirm 요청.

📐 **데이터 흐름 (목표 상태)**:
- contract status: pending → approved → done → ADR Status: Proposed → Accepted → Implemented
- SLURM job sacct → Experiments DB row update (status/end/duration/exit/metrics)
- `.agent/status/<slice>.md` heartbeat 갱신 → Slices DB row property update
- 홈 = 5 linked views (Active Slices / Recent ADRs / Running Experiments / Recent Reports / Docs)

---

## Phase A — Foundation

### Task 1: Notion 워크스페이스 백업 (in-session MCP dump)

- **Status**: done (2026-05-29, commit ad0f22f; 18 JSON files, 92KB, all valid; 홈+2 project hubs+5 slice hubs+3 DB schemas+2 live Weekly Digests+3 placeholders)
- **Prereq tasks**: none
- **Files touched**: `/home/ubuntu/.agent/scratch/notion_backup_20260529/` (new directory, JSON/MD files)
- **Change shape**: Fetch via Notion MCP the key entities and dump as JSON/markdown into the backup directory:
  - 홈 (28d1e76c-...) → home.json
  - 2 project hubs (FKSFold + Harness) → projects.json
  - 5 slice hubs (fragmap/mmgbsa/vav1/fksfold-core/harness) → hubs/<slice>.json
  - Reports DB rows (all current) → reports_db.json
  - Decisions DB rows (5 curated) → decisions_db.json
  - Artifacts DB rows (if any) → artifacts_db.json
  - 5 Weekly Digest rows (per slice, 2026-W22) → weekly_digests/<slice>.json
  Each file = the notion-fetch result raw text.
- **Verification**: `ls /home/ubuntu/.agent/scratch/notion_backup_20260529/ | wc -l` >= 10; `grep -l '_id' /home/ubuntu/.agent/scratch/notion_backup_20260529/*.json | wc -l` >= 5 (각 dump가 Notion ID 포함 확인). Spot-check: hubs/harness.json에 `〔sync〕` 또는 `Sync` summary 포함.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `rm -rf /home/ubuntu/.agent/scratch/notion_backup_20260529/`

### Task 2: notion_map.yaml — placeholder for new DB IDs

- **Status**: done (2026-05-29, commit 1d3ca1c; v0_5 section additive with TBD placeholders + 3 status enums; YAML valid; existing v1 keys untouched)
- **Prereq tasks**: none
- **Files touched**: `/home/ubuntu/.agent/notion_map.yaml`
- **Change shape**: Add a `v0_5:` section with placeholders for new DB IDs. Initial values `TBD-<DB_NAME>` to be filled by Tasks 5/6/7. Keys: `slices_db_id`, `slices_db_data_source_id`, `decisions_db_data_source_id` (unchanged but reference v0.5 schema), `experiments_db_id`, `experiments_db_data_source_id`. Do NOT delete existing v1 hub IDs or DB IDs — both v1 and v0.5 IDs coexist during migration.
- **Verification**: `grep -A2 'v0_5:' /home/ubuntu/.agent/notion_map.yaml` shows the new section with TBD placeholders.
- **Estimated time**: 2 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout .agent/notion_map.yaml`

### Task 3: notion_sync.py — new function stubs

- **Status**: done (2026-05-29, commit 311ec42; 7 stubs added (4 helpers + 3 migrate entries), all callable, all raise NotImplementedError pointing to future plan tasks; existing 15 tests still GREEN)
- **Prereq tasks**: 2
- **Files touched**: `/home/ubuntu/scripts/notion_sync.py`
- **Change shape**: Add 4 new function stubs (after `classify_event`): `contract_to_adr_rows(contract_path)`, `slurm_to_experiment_row(job_id)`, `slice_to_db_row(slice_name)`, `home_navigator_payload()`. Each stub: docstring linking to this contract + `raise NotImplementedError("v0.5 — see harness-notion-redesign-20260529 plan Task <N>")`. Also add 3 migration entries: `migrate_slices()`, `migrate_contracts()`, `migrate_slurm_history()` (also stubs).
- **Verification**: `/home/ubuntu/miniconda3/bin/python -c "import sys; sys.path.insert(0,'/home/ubuntu/scripts'); import notion_sync; assert callable(notion_sync.contract_to_adr_rows); assert callable(notion_sync.slurm_to_experiment_row); assert callable(notion_sync.slice_to_db_row); assert callable(notion_sync.home_navigator_payload); print('OK')"` → `OK`.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout scripts/notion_sync.py`

### Task 4: tests/test_notion_migration.py — RED tests for all stubs

- **Status**: done (2026-05-29, commit 0d0b951; 4 RED tests w/ NotImplementedError; total 19 tests = 15 GREEN + 4 RED; no pytest.raises wrapping (let stubs error naturally))
- **Prereq tasks**: 3
- **Files touched**: `/home/ubuntu/tests/test_notion_migration.py` (new)
- **Change shape**: New test file with RED tests for each stub:
  - `test_contract_to_adr_rows_for_v041()` — given the harness-v041 contract path, expect list of ≥5 ADR dicts with `{title, status, slice, context, decision, consequences}`.
  - `test_slurm_to_experiment_row_for_5754()` — given job_id 5754 (live SLURM history), expect dict with `{run_id, slice, status, start, end, duration, exit, metrics, artifacts}`.
  - `test_slice_to_db_row_for_harness()` — given "harness", expect dict with all Slices DB properties.
  - `test_home_navigator_payload_structure()` — expect dict with 5 keys: `active_slices`, `recent_decisions`, `running_experiments`, `recent_reports`, `docs`. Each a list.
  All tests should FAIL with NotImplementedError.
- **Verification**: `cd /home/ubuntu && /home/ubuntu/miniconda3/bin/python -m pytest tests/test_notion_migration.py -q 2>&1 | tail -5` → expected 4 FAILED tests (NotImplementedError); pre-existing 15 tests in test_notion_handoff_log.py still GREEN.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `rm /home/ubuntu/tests/test_notion_migration.py`

### Task 5: Create Slices DB (Notion MCP)

- **Status**: done (2026-05-29, commit e3c6332; DB 3435079f-... DS 01c936b7-... under Databases subpage; 10 properties per spec; Linked Experiments deferred to Task 7 ALTER. Note: contract said Project as relation→2 hubs but hubs are pages not DBs — pragmatically used SELECT with 2 hardcoded options.)
- **Prereq tasks**: 1,2
- **Files touched**: `/home/ubuntu/.agent/notion_map.yaml` (update placeholder with real ID)
- **Change shape**: Via Notion MCP `notion-create-database`, create a new "Slices" database under 홈 (or under Databases subpage). Properties: `Name` (title), `Status` (select: 활성 / 완료 / 릴리즈 / 휴면), `Owner Agent` (select: claude/codex/cursor/human), `Owner Session` (text, UUID), `Last Heartbeat` (datetime), `Last Updated` (date), `Project` (relation → 2 project hubs), `Next Action` (text), `State Body` (text, optional), `Linked Decisions` (relation → Decisions DB), `Linked Experiments` (relation → Experiments DB; left empty until Task 7). NO rows seeded yet. Update notion_map.yaml's `v0_5:slices_db_id` with the real UUID.
- **Verification**: `notion-fetch` the new DB ID → DB exists, has Properties matching spec; `grep 'slices_db_id:' /home/ubuntu/.agent/notion_map.yaml` shows a real UUID (not TBD).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: notion-update-database to archive the DB (Notion soft-delete); revert notion_map.yaml.

### Task 6: Restructure Decisions DB (ADR Properties)

- **Status**: done (2026-05-29; 7 ADR properties added via notion-update-data-source: ADR ID (unique_id PREFIX 'ADR'), Status (Proposed/Accepted/Rejected/Implemented/Superseded), Date, Slice (relation→Slices), Deciders, Linked Contract, Supersedes/Superseded By self-relation pair. 5 existing curated rows preserved. Old "Decision Status" enum kept for backward-compat. No workspace commit — notion_map.yaml's decisions_data_source_id was already set in Task 2.)
- **Prereq tasks**: 1,5
- **Files touched**: `/home/ubuntu/.agent/notion_map.yaml` (note: Decisions data source ID unchanged, just schema update)
- **Change shape**: Via Notion MCP `notion-update-data-source`, add ADR Properties to the existing Decisions DB (data source `b11ae976-...`): `ADR ID` (text/auto, e.g. ADR-NNNN), `Status` (select: Proposed/Accepted/Rejected/Implemented/Superseded), `Date` (date), `Slice` (relation → Slices DB, created in Task 5), `Deciders` (text or people), `Linked Contract` (URL), `Supersedes` (self-relation), `Superseded By` (self-relation). Existing 5 curated rows stay (will be retagged in Phase B). Update notion_map.yaml's `v0_5:decisions_data_source_id` (same UUID, but mark as v0.5-schema).
- **Verification**: `notion-fetch` the Decisions DB → shows all new ADR Properties; existing 5 rows still present.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: notion-update-data-source to remove the new Properties (Notion preserves data).

### Task 7: Create Experiments DB (replace/extend Artifacts DB)

- **Status**: done (2026-05-29, commit 34547e2; DB 949a3553-... DS b1a7f410-... under Databases subpage; 12 properties per spec; Slices DB Linked Experiments column added (deferred from Task 5); legacy Artifacts DB left read-only.)
- **Prereq tasks**: 5
- **Files touched**: `/home/ubuntu/.agent/notion_map.yaml`
- **Change shape**: Via Notion MCP, either (a) restructure the existing Artifacts DB by renaming to "Experiments" and adding Properties, OR (b) create a new Experiments DB and archive Artifacts. Decision: (b) is cleaner — create fresh Experiments DB next to Artifacts DB. Properties: `Run ID` (title), `Slice` (relation → Slices DB), `Phase` (text), `Status` (select: Queued/Running/Completed/Failed/Cancelled), `Start` (datetime), `End` (datetime), `Duration` (formula: End - Start), `Exit Code` (text), `Parameters` (text, JSON snapshot), `Metrics` (text, pass_rate / scores key:val pairs), `Artifact Path` (URL or text), `Linked Decision` (relation → Decisions). Update notion_map.yaml with the new DB ID. Existing Artifacts DB stays read-only.
- **Verification**: `notion-fetch` new Experiments DB → exists, all Properties present; `grep 'experiments_db_id:' notion_map.yaml` shows real UUID.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: notion-update-database to archive Experiments DB; revert notion_map.yaml.

### USER PAUSE A — Phase A foundation verification

Phase A 끝. 4 새 함수 stub + RED tests + 3 DB 생성/재구조화 + 백업. 사용자가 Notion 홈에서 새 DB들 보이는지, RED test가 4 FAILED인지 확인. /execute-plan은 여기서 STOP, 사용자 confirm 후 Phase B 시작.

---

## Phase B — Backfill

### Task 8: slice_to_db_row() impl + GREEN

- **Status**: done (2026-05-29, commit 8faf5ea; 9-key semantic dict, state/project mapping; 22/25 GREEN (3 still RED for Tasks 11/13/17); known nit: Last Heartbeat renders as Python datetime str — Task 23 normalizes)
- **Prereq tasks**: 3,4,5
- **Files touched**: `/home/ubuntu/scripts/notion_sync.py`
- **Change shape**: Implement `slice_to_db_row(slice_name)` — reads `.agent/status/<slice>.md`, parses frontmatter (owner_session/owner_label/owner_agent/version/last_updated/heartbeat/state/remaining_actions[0]/contract_pointers), returns dict for Slices DB row creation. `Status` mapped from `state:` field (active→활성, closed→완료, released→릴리즈, dormant→휴면). `Project` mapped from slice name (harness→Harness, others→FKSFold).
- **Verification**: `/home/ubuntu/miniconda3/bin/python -m pytest tests/test_notion_migration.py::test_slice_to_db_row_for_harness -q 2>&1 | tail -3` → PASS.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout scripts/notion_sync.py`

### Task 9: Seed 5 슬라이스 → Slices DB rows (in-session MCP)

- **Status**: done (2026-05-29, commit d0645c0; 6 rows created — fragmap/mmgbsa/vav1/fksfold-core/harness/arl. arl included (present on FS). All properties match spec. Dormant slices (vav1/fksfold-core/arl) Status=활성 (default) since no `state:` field; consistent with v0.4.1's default-active rule and contract Non-Goal.)
- **Prereq tasks**: 5,8
- **Files touched**: none (Notion-side via MCP)
- **Change shape**: For each of 5 slices, compute `slice_to_db_row()` payload + `notion-create-pages` into Slices DB. Add `arl` as 6th row optionally (in dormant state — note: contract said arl promotion is OOS; only seed if existing `.agent/status/arl.md` has content). For each row, also create a child page mirror of the slice's current hub content (or link to existing hub via mention-page; preserve hub URLs).
- **Verification**: `notion-fetch` Slices DB data source → exactly 5 (or 6) rows; `notion-fetch` one row (harness) → properties match expected slice_to_db_row output.
- **Estimated time**: 8 min
- **Rollback (if this task only)**: notion-delete or archive the 5 rows from Slices DB.

### Task 10: Reparent existing 5 slice hub pages under Slices DB rows

- **Status**: done (2026-05-29; 5 hubs moved under their respective Slices DB row pages; URLs preserved (ID-based); content preserved; ancestor-path verified for harness — 홈 → Databases → Slices DB → harness row → harness hub. No workspace commit needed.)
- **Prereq tasks**: 9
- **Files touched**: none (Notion-side via MCP)
- **Change shape**: For each of 5 existing slice hub pages (fragmap, mmgbsa, vav1, fksfold-core, harness), `notion-move-pages` to under the corresponding Slices DB row's child page area. CRITICAL: page URL is ID-based in Notion, so the URL itself is preserved by `notion-move-pages`. The old project hubs (FKSFold-Boltz, Harness/Agent Ops) keep a `<mention-page>` reference (not the actual page child). External links continue to work via stable page ID URLs.
- **Verification**: For each slice, `notion-fetch <hub_id>` → ancestor-path now includes the Slices DB row's child page; page URL unchanged from notion_map.yaml. Spot-check by fetching `harness` hub URL.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `notion-move-pages` back to original project hub parents.

### Task 11: contract_to_adr_rows() impl + GREEN

- **Status**: done (2026-05-29, commit 90c4ef0; YAML safe_load + regex fallback for colon-rich decisions; v041 → 5 ADRs Implemented; 23/25 tests GREEN)
- **Prereq tasks**: 3,4
- **Files touched**: `/home/ubuntu/scripts/notion_sync.py`
- **Change shape**: Implement `contract_to_adr_rows(contract_path)` — parses frontmatter, extracts `decisions:` list, for each decision item creates an ADR dict: `{title: first-50-chars-of-decision, status: <contract status to ADR Status mapping>, slice: <from frontmatter>, date: <today or contract date>, deciders: <owner field>, context: <auto-extracted from Purpose section>, decision: <the decision text>, consequences: "<see linked contract>", linked_contract: <contract path>}`. Status mapping: contract.pending → ADR.Proposed, contract.approved → ADR.Accepted, contract.done → ADR.Implemented. Use contract title + decision index for ADR ID (e.g. "ADR-harness-v041-3" for the 3rd decision of v041 contract).
- **Verification**: `/home/ubuntu/miniconda3/bin/python -m pytest tests/test_notion_migration.py::test_contract_to_adr_rows_for_v041 -q 2>&1 | tail -3` → PASS; payload for harness-v041 has ≥5 ADR dicts.
- **Estimated time**: 7 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout scripts/notion_sync.py`

### Task 12: Backfill 12+ contracts → ADR rows (in-session MCP, batched)

- **Status**: done (2026-05-29, commit 5e3bcf5; 102 ADRs from 16 contracts (10 had no decisions:); existing 5 curated preserved → total 107 in Decisions DB; rollback page-id mapping in adr_created_batch{1,2}.json + 148-line seed log; 5 MCP calls)
- **Prereq tasks**: 6,11
- **Files touched**: none (Notion-side via MCP)
- **Change shape**: Glob `.agent/contracts/*.md` (excluding `_template.md`). For each contract, run `contract_to_adr_rows()` then `notion-create-pages` batch into Decisions DB. Throttle to ~3 calls/sec for Notion rate limit. Reparent or replace the 5 existing curated decisions (not duplicate). Track which contracts produced which ADRs in `.agent/scratch/notion_backup_20260529/adr_seed_log.txt`.
- **Verification**: `notion-fetch` Decisions DB → row count ≥ 60; `adr_seed_log.txt` lists all source contracts.
- **Estimated time**: 12 min (includes MCP wait)
- **Rollback (if this task only)**: From the seed log, batch-delete the new ADR rows (preserves the 5 curated).

### Task 13: slurm_to_experiment_row() impl + GREEN

- **Status**: done (2026-05-29, commit 6c75e23; sacct + heuristic slice/phase/metrics; 24/25 GREEN; known limitation: 5754 job_name doesn't glob-match output dir — metrics empty pending T14/T15 explicit dir override)
- **Prereq tasks**: 3,4
- **Files touched**: `/home/ubuntu/scripts/notion_sync.py`
- **Change shape**: Implement `slurm_to_experiment_row(job_id)` — uses `subprocess.run(['sacct', '-j', str(job_id), '--format=JobID,State,Start,End,Elapsed,ExitCode,Account,Partition', '-n', '-P'])` to query SLURM. Parses output, returns dict for Experiments DB row. For metrics, look up the job's standard output dir (heuristic: search common mmgbsa output base under `/mnt/data/users/ubuntu/mmgbsa_outputs/*`) and parse `ready_for_mmpbsa_prod.tsv` row count / first column as pass_rate. Slice inferred from job name heuristic (e.g. `norm143_ab_seed16_stage1` → mmgbsa). Robust to missing data (fields default empty).
- **Verification**: `/home/ubuntu/miniconda3/bin/python -m pytest tests/test_notion_migration.py::test_slurm_to_experiment_row_for_5754 -q 2>&1 | tail -3` → PASS; manual: `python -c "from notion_sync import slurm_to_experiment_row; print(slurm_to_experiment_row(5754))"` → dict with status: Completed, exit: 0:0.
- **Estimated time**: 8 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout scripts/notion_sync.py`

### Task 14: Backfill SLURM history → Experiments rows (in-session MCP)

- **Status**: done (2026-05-29, commit 22e69af; 240 SLURM jobs from sacct 2026-04-01..now → 240 Experiments DB rows (8× target); 10 chunked MCP calls, 1 transient empty-Slice validation error self-recovered; breakdown mmgbsa=117 / fragmap=6 / vav1=3 / Unclassified=114; rollback page-id mapping in experiments_created{,_chunk*}.json)
- **Prereq tasks**: 7,13
- **Files touched**: none (Notion-side)
- **Change shape**: Query `sacct -S 2026-04-01 -E now --format=JobID -P -n | grep -E '^[0-9]+$'` → list of job IDs in the relevant window. For each (~30+ mmgbsa jobs), `slurm_to_experiment_row()` + `notion-create-pages` into Experiments DB. Throttled to ~3 calls/sec. Skip jobs that don't have a slice mapping (heuristic-fallback to "Unclassified"). Log seed in `.agent/scratch/notion_backup_20260529/experiments_seed_log.txt`.
- **Verification**: `notion-fetch` Experiments DB → row count ≥ 30; verify spot-check: row for run_id=5754 has Status=Completed, Exit=0:0, Slice=mmgbsa.
- **Estimated time**: 15 min (includes MCP + sacct query wait)
- **Rollback (if this task only)**: Batch-delete Experiments DB rows from the seed log.

### Task 15: Seed fragmap Phase 1..10 → Experiments rows (manual, in-session MCP)

- **Status**: done (2026-05-29, commit 87fad95; 12 fragmap Phase rows, 1 per contract; Status mapping done/approved/pending→Completed/Running/Queued; Experiments DB total now 252 (240 SLURM + 12 fragmap Phase); Linked Decision deferred to manual cross-link)
- **Prereq tasks**: 14
- **Files touched**: none (Notion-side)
- **Change shape**: fragmap Phase events are not SLURM jobs; they're tied to the fragmap contracts. For each fragmap contract (`fragmap-*.md`), create 1 Experiments DB row with `Phase` field set to the contract topic (e.g. "AB 139-batch", "DC50 overfit scan"), Slice=fragmap, Status=Completed (if contract status: done) or Running. Run ID = contract slug. Metrics empty (or extracted if contract has them). Linked Decision = first ADR from that contract.
- **Verification**: `notion-fetch` Experiments DB filter by Slice=fragmap → ~5-7 phase rows; spot-check one row.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: Delete the fragmap phase rows.

### Task 16: Reports DB cleanup — separate Weekly Digest vs Operational reports

- **Status**: done (2026-05-29; no changes needed — Reports DB schema already has rich 6-value `Report Type` enum (Weekly Digest / Meeting Brief / Research Update / Experiment Closeout / E2E Verification / Operational Update) + Status enum + Slice select. Existing rows verified cleanly typed. Task 18 home Navigator can filter by Report Type without further restructuring.)
- **Prereq tasks**: 1
- **Files touched**: none (Notion-side; small property change)
- **Change shape**: Reports DB currently has Weekly Digest rows + Operational Update + inaugural reports mixed. Add a `Subtype` Property if needed, OR use existing `Report Type` more strictly. Spot-check the 5 existing Weekly Digest rows (one per slice) — Report Type should be exactly "Weekly Digest"; inaugural reports — "Operational Update" or new "Inaugural". Ensure linked views in 홈 can filter cleanly.
- **Verification**: `notion-fetch` Reports DB → no row has empty Report Type; `notion-search` "harness 2026-W22" → only the Weekly Digest row matches.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: Revert Report Type values; remove Subtype if added.

### USER PAUSE B — Phase B backfill verification

Phase B 끝. 5 슬라이스 Slices DB + 60+ ADR rows + 40+ Experiments rows + Reports cleanup 다 적용됨. 사용자가 Notion에서 새 DB들 채워진 모습 확인. Spot-check 권장 (예: harness-v041 contract의 ADR rows가 정확히 5+ 있는지, mmgbsa 5754 Experiments row metrics 정확한지). /execute-plan STOP, 사용자 confirm 후 Phase C.

---

## Phase C — Navigator + Automation

### Task 17: home_navigator_payload() impl + GREEN

- **Status**: done (2026-06-01, commit 1de3cbc; 5-section payload + 3 private helpers (_filename_date/_active_slice_names/_running_slurm_ids) + _FILENAME_DATE_RE; reuses slice_to_db_row/contract_to_adr_rows/slurm_to_experiment_row; robust to squeue/sacct (empty list, no raise); test_home_navigator_payload_structure GREEN, full notion suite 19/19. /code-review APPROVE_WITH_NITS — nits: array-job ids dropped in _running_slurm_ids, "never raises" docstring wording, docs[] omits runbook/HARNESS_USAGE (Task 18 defines rendered list).)
- **Prereq tasks**: 8,11,13
- **Files touched**: `/home/ubuntu/scripts/notion_sync.py`
- **Change shape**: Implement `home_navigator_payload()` returning a dict with 5 sections:
  ```python
  {
      "active_slices": [...slice_to_db_row(s) for s in active_slices],
      "recent_decisions": [...ADRs from .agent/contracts/, filtered by last 7d],
      "running_experiments": [...slurm_to_experiment_row(id) for id in active SLURM ids],
      "recent_reports": [contract+plan paths from last 7d],
      "docs": [{"name": "AGENTS.md", "path": "AGENTS.md"}, ...],
  }
  ```
  Each list is the data the Navigator home page would render.
- **Verification**: `python -m pytest tests/test_notion_migration.py::test_home_navigator_payload_structure -q` → PASS; manual: `python -c "from notion_sync import home_navigator_payload; import json; print(json.dumps(home_navigator_payload(), indent=2, ensure_ascii=False)[:500])"` → JSON with 5 keys.
- **Estimated time**: 7 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout scripts/notion_sync.py`

### Task 18: Rewrite 홈 페이지 as Navigator (in-session MCP)

- **Status**: done-with-caveat (2026-06-01, no commit — Notion-side; user-approved gate). Home page 28d1e76c rewritten via replace_content into the v0.5 Navigator: 🧭 callout + 5 sections (🔄 진행 중 슬라이스→Slices / 🧭 최근 결정→Decisions / 📊 진행 중 실험→Experiments / 📝 최근 리포트→live inline Reports view / 📚 Docs). All 5 child pages preserved (FKSFold/Harness/Databases/SDLs/로드세이프AI); canonical DBs NOT moved (stay under Databases subpage). CAVEAT: Notion content API rejects creating NEW inline linked-views from data-source-url ("data source not found" for 01c936b7/b11ae976/b1a7f410, despite those data sources fetching fine) — only the pre-existing Reports linked-view block (1413ac21) works. So Slices/Decisions/Experiments are clickable <mention-database> links, not embedded filtered views. FOLLOW-UP (manual Notion UI, ~3min): add 3 "Linked view of database" blocks with filters 활성 / 최근7일 Accepted·Implemented / Running. Minor: AGENTS/CLAUDE/WORKFLOW auto-linkified to http://.
- **Prereq tasks**: 5,6,7,9,17
- **Files touched**: none (Notion-side, 홈 page content replace)
- **Change shape**: Via Notion MCP `notion-update-page` with command `replace_content`, rewrite the 홈 page body. Structure:
  ```
  <callout icon="🏠" color="gray_bg">
    Research Lab Home — 한 페이지 reorient.
  </callout>
  
  # 🔄 지금 진행 중
  <database url="<slices_db>" inline="true" data-source-url="collection://<slices_data_source>"></database>
  (linked view filter: Status = 활성)
  
  # 🧭 최근 결정 (last 7d)
  <database url="<decisions_db>" inline="true" data-source-url="collection://<decisions_data_source>"></database>
  (linked view filter: Date >= today-7d, Status ∈ {Accepted, Implemented})
  
  # 📊 진행 중 실험
  <database url="<experiments_db>" inline="true" data-source-url="collection://<experiments_data_source>"></database>
  (linked view filter: Status = Running)
  
  # 📝 최근 리포트 (last 7d)
  <database url="<reports_db>" inline="true" data-source-url="collection://<reports_data_source>"></database>
  
  # 📚 Docs & Standards
  - AGENTS.md / CLAUDE.md / WORKFLOW.md (mentions)
  - docs/notion-sync-runbook.md
  - HARNESS_USAGE.md
  ```
  Preserve any user-curated content via insert (not destructive replace) — actually `replace_content` is fine since the new content covers all functions.
- **Verification**: `notion-fetch` 홈 page → 5 sections present, each with a database inline view; manual: open the home URL and confirm 5 lists render.
- **Estimated time**: 8 min
- **Rollback (if this task only)**: `notion-update-page replace_content` with old home content from Task 1's backup.

### Task 19: /handoff SKILL Step 5 v0.5 rewrite

- **Status**: done (2026-06-01, commit 696aa62; +65/-38, Step 5 only. v0.5 7-point flow: compute via --handoff-log/--migrate → MCP-update Slices row (slice_row_ids[<slice>], state→Status) → conditional ADR rows on contract status transition → optional Experiments upsert on SLURM completion → 〔sync〕 hub toggle → change-gated Weekly Digest callout → NON-BLOCKING. Preserves v0.4.2 best-effort/Claude-only/chg-digest gate; MCP-only compute-then-apply (no headless write); cited flags (--handoff-log/--migrate) + functions verified real. skill-lint PASS:14. /code-review APPROVE.)
- **Prereq tasks**: 9,17
- **Files touched**: `/home/ubuntu/.claude/skills/handoff/SKILL.md`
- **Change shape**: 3rd rewrite of Step 5. New behavior:
  1. Get payload (same as v0.4.2 + new fields from `home_navigator_payload`-related sources).
  2. Update Slices DB row for the active slice (using `slice_to_db_row(<slice>)` + notion MCP update_page on the row).
  3. If this `/handoff` was triggered by a contract status transition (pending→approved or approved→done), trigger `contract_to_adr_rows()` and create/update ADR rows.
  4. Optionally trigger SLURM scan if new mmgbsa jobs completed since last handoff.
  5. Update slice hub child page's 〔sync〕 toggle (existing v0.4.2 logic).
  6. Update Weekly Digest row body callout (existing v0.4.2 logic).
  7. NON-BLOCKING (preserved).
- **Verification**: `grep -q 'Slices DB' /home/ubuntu/.claude/skills/handoff/SKILL.md && grep -q 'ADR' /home/ubuntu/.claude/skills/handoff/SKILL.md && grep -q 'Experiments' /home/ubuntu/.claude/skills/handoff/SKILL.md && bash /home/ubuntu/tests/run-skill-lint.sh 2>&1 | tail -3 | grep -q 'PASS: 14'` → all match.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout .claude/skills/handoff/SKILL.md`

### Task 20: Codex handoff-writer mirror

- **Status**: done (2026-06-01, commit 57221b7; +99/-41, Notion section only. Mirrors Claude Step 5 v0.5 (Slices row + ADR + Experiments + 〔sync〕 toggle + Weekly Digest, MCP-only compute-then-apply) into .codex/skills/handoff-writer/SKILL.md. Codex-hardened warn-only: if Codex Notion MCP unavailable or any sub-step errors → one-line warning + SKIP, never blocks/fails handoff. Flags/functions verified real, no raw UUIDs. /code-review APPROVE.)
- **Prereq tasks**: 19
- **Files touched**: `/home/ubuntu/.codex/skills/handoff-writer/SKILL.md`
- **Change shape**: Mirror Task 19's changes to Codex SKILL. Defensive on Codex Notion MCP availability — warn-only if unavailable. Same Slices/ADR/Experiments DB schema usage.
- **Verification**: `grep -q 'Slices DB\|Slices\|ADR' /home/ubuntu/.codex/skills/handoff-writer/SKILL.md && grep -qE 'best-effort|warn-only|non-blocking' /home/ubuntu/.codex/skills/handoff-writer/SKILL.md`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout .codex/skills/handoff-writer/SKILL.md`

### Task 21: docs/notion-sync-runbook.md — v0.5 full rewrite

- **Status**: done (2026-06-01, commit d333d2e; 410 lines, 8 sections: 3-pattern overview / Slices DB schema+frontmatter auto-update / Decisions ADR registry+status transitions / Experiments DB+SLURM ingestion (sacct history vs squeue live) / Navigator home maint / --migrate backfill CLI / preserved v0.4.2 toggle-hub+event-callout / chg→last_change_digest. All DB ids + code symbols cross-checked real; Tasks 18/19 automation flagged pending (honesty). /code-review APPROVE_WITH_NITS (nit: home id not in notion_map.yaml).)
- **Prereq tasks**: 5,6,7,17
- **Files touched**: `/home/ubuntu/docs/notion-sync-runbook.md`
- **Change shape**: Full rewrite covering v0.5 IA:
  - Section 1: 3-pattern overview (Engineering Wiki + ADR + W&B).
  - Section 2: Slices DB schema + auto-update from slice frontmatter.
  - Section 3: Decisions ADR registry + status transition rules.
  - Section 4: Experiments DB + SLURM ingestion.
  - Section 5: Navigator 홈 maintenance.
  - Section 6: Backfill procedures (`--migrate` CLI).
  - Section 7: Existing v0.4.2 sections (toggle hub + event callout) preserved as the slice-hub-child-page format.
  - Section 8: chg 마커 handling (where it lives now).
- **Verification**: `grep -q 'v0.5\|Slices DB\|ADR registry\|Experiments DB' /home/ubuntu/docs/notion-sync-runbook.md`; word count >= 200 lines.
- **Estimated time**: 10 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout docs/notion-sync-runbook.md`

### Task 22: AGENTS.md + AGENTS.md.example v0.5 IA section

- **Status**: done (2026-06-01, commit 00efc49; +57 lines, 2 files. AGENTS.md "## Notion IA (v0.5)" (~30 lines, between Agent Handoff Protocol + Quick Router): 3-DB model + Navigator home + state/ADR mappings (verified vs _STATE_TO_STATUS/_CONTRACT_STATUS_TO_ADR), pointers to notion_map.yaml/runbook (no raw UUIDs), Tasks 19/18 flagged not-shipped. Template version generic+portable (no real ids/slice names/Korean). Additive only. /code-review APPROVE.)
- **Prereq tasks**: 21
- **Files touched**: `/home/ubuntu/AGENTS.md`, `/home/ubuntu/.agent/templates/AGENTS.md.example`
- **Change shape**: Add a "Notion IA (v0.5)" section to AGENTS.md describing the 3 DBs + Navigator home + lifecycle conventions. Add same to the template. ~30 lines each.
- **Verification**: `grep -q 'Notion IA\|Slices DB\|ADR\|Experiments DB' /home/ubuntu/AGENTS.md && grep -q 'Notion IA' /home/ubuntu/.agent/templates/AGENTS.md.example`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout AGENTS.md .agent/templates/AGENTS.md.example`

### Task 23: notion_sync.py — wire migration entries + --migrate CLI mode

- **Status**: done (2026-06-01, commit 293f95b; 4 migrate_* fns + shared _emit_migration upsert-keyed envelope + --migrate {slices,contracts,slurm,home,all} argparse choices; prints JSON for manual MCP, zero Notion/network writes; migrate_slurm_history backfills via new _history_slurm_ids (sacct, last 30d, mirrors Task 14 — 107 rows) NOT squeue; _running_slurm_ids reserved for home live experiments. /code-review: REQUEST_CHANGES→fixed (slurm history) →APPROVE; suite 19/19 GREEN. Idempotency = stable upsert_key per target (Name/adr_id/Run ID/home).)
- **Prereq tasks**: 8,11,13,17
- **Files touched**: `/home/ubuntu/scripts/notion_sync.py`
- **Change shape**: Add `migrate_slices()`, `migrate_contracts()`, `migrate_slurm_history()`, `migrate_home()` orchestration functions that call the lower-level `_to_*_row()` helpers + the appropriate MCP wrapper (or print payloads for manual MCP application). Add a `--migrate <target>` CLI mode where `<target>` is one of `slices|contracts|slurm|home|all`. Each migrate function is idempotent (re-running doesn't duplicate rows — check by row Title/ID).
- **Verification**: `python /home/ubuntu/scripts/notion_sync.py --migrate home 2>/dev/null | head -5` outputs the Navigator payload JSON; `python /home/ubuntu/scripts/notion_sync.py --help 2>&1 | grep -q 'migrate'`.
- **Estimated time**: 8 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout scripts/notion_sync.py`

### USER PAUSE C — Phase C automation verification

Phase C 끝. 홈 Navigator + /handoff Step 5 v0.5 + Codex mirror + runbook + AGENTS 다 적용. 사용자가 Notion 홈에서 5 섹션 보이고 클릭 가능한지 확인. 다음 /handoff 호출 시 새 자동 흐름이 작동하는지 light verify. /execute-plan STOP, 사용자 confirm 후 Phase D.

---

## Phase D — Verify + Release

### Task 24: 시나리오 walk-through 문서 작성

- **Status**: done (2026-06-01, commit 6ed6e06; 162 lines, 4 시나리오 in X→Y→Z shape grounded in shipped v0.5 state with real notion_map.yaml IDs (home/Slices DB+3 rows/Decisions DS/Experiments DB) + verified internal symbols (_CONTRACT_STATUS_TO_ADR/_SACCT_STATE_TO_STATUS/_STATE_TO_STATUS) + upsert keys (adr_id/Run ID/home). Both honesty caveats stated §0 + re-flagged per scenario; no invented metrics (counts 6/107/252=240+12 match plan). /code-review APPROVE.)
- **Prereq tasks**: 18,19,23
- **Files touched**: `/home/ubuntu/.agent/handoffs/notion-redesign-walkthrough.md` (new)
- **Change shape**: Document 4 시나리오 (from contract Q1 design) — mmgbsa Stage 1 완료, harness v0.4.1 ship cycle, fragmap Phase 10 closure, 새 세션 reorient — actual current Notion state로 walk-through. 각 시나리오: "사용자가 X를 하면 → 시스템이 Y를 자동 → 사용자가 홈에서 Z를 본다". Notion URL 직접 인용 (홈, Slices DB, 각 슬라이스 row).
- **Verification**: `wc -l /home/ubuntu/.agent/handoffs/notion-redesign-walkthrough.md` >= 80; `grep -c '시나리오' notion-redesign-walkthrough.md` >= 4.
- **Estimated time**: 8 min
- **Rollback (if this task only)**: `rm /home/ubuntu/.agent/handoffs/notion-redesign-walkthrough.md`

### Task 25: Cold-start 시나리오 시뮬레이션

- **Status**: done (2026-06-01, commit e5a6c60; +68 lines appended as `## Cold-start 시뮬레이션` section. 4 numbered click steps (홈 click0 → Slices DB click1 → mmgbsa row click2 → child 상세 click3) with real URLs + what's seen each step. Explicit 에이전트(.agent/ batons per CLAUDE.md 3-step ritual) vs 휴먼(Navigator 홈) cold-start distinction — no claim agents read Notion at SessionStart. pre-v0.5 ~5-click path framed as documented prior path, comparison table. caveat 1 carried forward. /code-review APPROVE.)
- **Prereq tasks**: 24
- **Files touched**: append to `/home/ubuntu/.agent/handoffs/notion-redesign-walkthrough.md`
- **Change shape**: Simulate a "fresh agent / 휴가 후 사용자" path: SessionStart → 홈 fetch → 5 섹션 보기 → 슬라이스 1개 클릭 → 상세 보기. Document exact click path + Notion URLs + what they see. Compare against pre-v0.5 path (5 clicks).
- **Verification**: walkthrough.md has "Cold-start" section with ≥3 click steps documented.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: revert walkthrough.md edits.

### Task 26: 사용자 spot-check pause

- **Status**: done (2026-06-01; spot-check checklist (홈 5섹션 / Slices 6 rows / Decisions 107 ADR / Experiments 252 rows / live auto-flow items 5-6) presented with real Notion URLs. 사용자 응답 "Finalize 진행" → gate 통과, finalize 승인. items 5-6 (end-to-end auto-flow)은 follow-up으로 명시.)
- **Prereq tasks**: 24,25
- **Files touched**: none
- **Change shape**: Explicit STOP. Present a checklist to user:
  - [ ] 홈 페이지에서 5 섹션 다 보임 / 클릭 가능
  - [ ] Slices DB에 5 (또는 6) rows 보임, 각 row property 정확
  - [ ] Decisions DB에 60+ ADR rows 보임, Status enum 적용
  - [ ] Experiments DB에 40+ rows 보임, mmgbsa 5754/5809 metrics 정확
  - [ ] /handoff 한 번 더 호출 시 (예: harness slice) Slices DB row 자동 갱신됨
  - [ ] 새 컨트랙트 draft → ADR Proposed rows 자동 생성됨
- **Verification**: user explicit "OK to finalize" or list of issues to fix.
- **Estimated time**: 5 min (user time)
- **Rollback (if this task only)**: n/a (verification gate)

### Task 27: Finalize — contract+plan status, baton update

- **Status**: done (2026-06-01; contract status: approved→done + 3 progress-log entries (Phase A·B / C / D SHIPPED + 2 documented follow-ups); plan status: in-progress→done; baton remaining_actions[0] rewritten to v0.5 SHIPPED summary. contract_pointers already include the contract. Verification grep all green.)
- **Prereq tasks**: 26
- **Files touched**: `/home/ubuntu/.agent/contracts/harness-notion-redesign-20260529.md`, `/home/ubuntu/.agent/plans/harness-notion-redesign-20260529.md`, `/home/ubuntu/.agent/status/harness.md`
- **Change shape**: Set contract + plan `status: done` with Notes / progress log entries. Update harness baton's `remaining_actions[0]` with v0.5 SHIPPED summary. Bump `contract_pointers` to include the new contract. (Don't run `/handoff` yet — that's Task 28.)
- **Verification**: `grep -q 'status: done' /home/ubuntu/.agent/contracts/harness-notion-redesign-20260529.md && grep -q 'status: done' /home/ubuntu/.agent/plans/harness-notion-redesign-20260529.md && grep -q 'v0.5' /home/ubuntu/.agent/status/harness.md`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout .agent/contracts/harness-notion-redesign-20260529.md .agent/plans/harness-notion-redesign-20260529.md .agent/status/harness.md`

### Task 28: /handoff (final) + status.sh index

- **Status**: done (2026-06-01; `./scripts/handoff.sh claude harness` → baton v12→13, owner_session 64afe121, heartbeat 2026-06-01T11:24:01Z, auto-commit SKIPPED (dirty tree, expected). `./scripts/status.sh index` → CURRENT.md regen (6 slices). **Step 5 v0.5 1차 실거동**: slice_to_db_row("harness") payload → MCP update_properties on harness Slices row 36f1e76c-...755f → Owner Session/Last Heartbeat(2026-06-01T11:24Z)/Last Updated/Next Action(v0.5 SHIPPED) updated + fetch-verified. Step 5.2 (Slices-row update) LIVE-VERIFIED; 5.3 (ADR)/5.4 (Experiments) remain as follow-up (b).)
- **Prereq tasks**: 27
- **Files touched**: status frontmatter rewrite (auto by handoff.sh), CURRENT.md regen (auto by status.sh index)
- **Change shape**: Run `./scripts/handoff.sh claude harness` (auto-commit may SKIP due to dirty tree — expected). Run `./scripts/status.sh index`. This triggers /handoff Step 5 v0.5 (a real end-to-end test of the new system — Slices DB row update should happen + ADR rows for this contract should land + maybe Experiments rows update).
- **Verification**: `head -10 /home/ubuntu/.agent/status/harness.md` shows bumped version + today's date + fresh heartbeat. `notion-fetch` Slices DB harness row → Last Heartbeat updated. Decisions DB → new ADR rows for harness-notion-redesign contract.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: n/a (operational state change).
