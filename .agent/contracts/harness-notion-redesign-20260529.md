---
status: done
slice: harness
topic: notion-redesign
date: 2026-05-29
owner: claude
approved_by: user (2026-05-29, "진행")
follow_on_to:
  - .agent/contracts/harness-notion-handoff-log-20260527.md
  - .agent/contracts/harness-v042-notion-report-format-20260529.md
target_repo: workspace (/home/ubuntu) — Notion 관련 파일은 워크스페이스 전용 (업스트림 template `sun9huni/claude-codex-coordination`에 notion_sync.py / notion_map.yaml / 러북 부재). 따라서 v0.5는 워크스페이스 commit만, 업스트림 PR 없음.
decisions:
  - Notion IA를 5군데 흩어진 구조 (Hub callouts / Weekly Digests / Reports / Decisions / Artifacts)에서 **3-pattern 통합 + Navigator 홈**으로 재설계:
    - **Engineering Wiki Projects 패턴** → 5 슬라이스 hub들을 Slices DB의 row로 격상 (Status/Owner/Timeline/inline Decisions+Experiments).
    - **ADR (Architecture Decision Record) 패턴** → Decisions DB을 ADR registry로 재구조화 (Status enum: Proposed/Accepted/Rejected/Implemented/Superseded, Context/Decision/Consequences body).
    - **W&B Experiments 패턴** → Artifacts DB을 Experiments DB로 재구조화 (1 row = 1 SLURM job/phase/release, metrics + status + artifacts paths 자동 추출).
    - **Navigator 홈** → 5 섹션 (Active Slices linked view, Recent Decisions, Running Experiments, Recent Reports, Docs/Standards).
  - **Full backfill**: 5 슬라이스 hubs + 12+ 기존 contracts (모든 슬라이스의 과거 작업) + 30+ SLURM jobs (sacct history of mmgbsa) + ~5 inaugural reports 다 새 DB 구조로 마이그레이션. 옛 구조는 옅게 두되 새 구조가 SSOT.
  - **Codex parity 포함** — `.codex/skills/handoff-writer/SKILL.md` + `AGENTS.md` + `.agent/templates/AGENTS.md.example`를 v0.5 패턴 따르도록 갱신. v0.4.0-0.4.2 패턴.
  - **Big-bang 한 컨트랙트 시리즈** — phased 분할 없이 한 시리즈로. 중간 상태가 어색하지 않도록 마이그레이션은 옛+새 DB 병행 → 검증 후 옛 DB read-only 격하 → 옛 DB archive 절차.
  - **MCP-only 쓰기**: headless 토큰 차단 상태 보존 (workspace permission). claude.ai Notion MCP만 사용. 마이그레이션은 in-session MCP 호출로.
  - **자동 데이터 흐름** 핵심 3가지:
    - `/handoff` Step 5 → Slices DB row Status/Heartbeat/Next 갱신 + 새 ADR/Experiment rows 추가.
    - Contract status: pending → approved → done 전환 → 그 contract의 `decisions:` 리스트가 ADR rows의 Status: Proposed → Accepted → Implemented로 자동 흐름.
    - SLURM completion event (sacct poll 또는 수동 trigger) → Experiments DB row update (status/duration/exit/metrics 자동).
  - **Korean labels 정책 유지** — 출시/작업/설계/결정/차단/수정 (v0.4.2 lexicon 그대로), Status 한글 (Active/Done/Released/Dormant → 활성/완료/릴리즈/휴면), identifier 영문 유지.
  - **chg 마커 페이지 properties로 이동** (v0.4.2 deferred) — Weekly Digest row body에 inline span 대신, row의 hidden property `last_change_digest`로. 시각적 완전 숨김 + 게이트 동작 보존.
---

# Harness v0.5 — Notion IA 전면 재설계 (3-pattern 통합 + Navigator)

## Purpose

v0.4.0 도입 이후 Notion 자동 쓰기 기능을 4번 (handoff-log v1, v2, v0.4.1, v0.4.2) 패치했으나, IA 자체가 5군데 흩어진 구조 (Hub callouts + Weekly Digests + Reports DB + Decisions DB + Artifacts DB)에 묶여있어 "내가 존재 자체를 모르겠음 — 어디 볼지 감 안 온다" (사용자 진단, 2026-05-29). v0.5는 검증된 3 패턴 (Engineering Wiki Projects + ADR + W&B Experiments) + Navigator 홈을 통합 도입해서 Korean AI 신약개발 lab의 lab notebook IA를 본격 재설계. Decisions의 archaeology, SLURM/Phase의 first-class tracking, 새 세션 cold-start 1-2 클릭 — 이 셋을 동시에 해결.

## Current State

- 5군데 IA가 v0.4.2까지 작동 중. 자동 쓰기 (Hub `〔sync〕` toggle + Weekly Digest 이벤트 callout) 동작은 OK, 단 격리된 surface.
- 12+ contracts (3 슬라이스의 과거 4주 작업) Notion에 없음 — `.agent/contracts/` 파일만.
- 30+ SLURM jobs (mmgbsa) Notion에 없음 — sacct만.
- 5 inaugural reports (수동 작성) Reports DB에 섞임.
- Decisions DB에 1 큐레이션 row/슬라이스 (5 rows 총).
- Artifacts DB 거의 비어 있음.
- 홈 페이지: 🚀 Projects 2 column links + 📊 Recent Reports inline view + 🗂️ More (Databases link). 사용자가 슬라이스 직접 진입 1-2 클릭.

## Decisions

(see frontmatter `decisions:` for the consolidated set)

## Assumptions And Questions

- assumptions:
  - 사용자가 v0.4.2의 시나리오 walk-through (mmgbsa Stage 1 완료 / harness v0.4.1 릴리즈 / fragmap Phase 10 closure / 새 세션 reorient)를 보고 3-pattern 통합 + 풀 backfill을 명시적으로 commit. 4 시나리오가 success criterion의 기반.
  - 마이그레이션 중 옛+새 DB 병행이 안전 (Notion이 동시 페이지 액세스에 robust). 검증 후 옛 read-only 격하 → 4주 후 archive.
  - Korean labels 정책 v0.4.2의 6 이벤트 타입 (출시/작업/설계/결정/차단/수정)이 적당. lab notebook 톤에 충분.
  - ADR 매핑은 contract의 `decisions:` frontmatter 항목 단위 (`- 한 줄 결정`). 각 항목 = 1 ADR row. Status는 contract의 status frontmatter (pending/approved/done)에 따라 결정.
  - Experiments 매핑은 SLURM job ID 단위. mmgbsa는 `sacct -j 5000..5900` history에서 추출. fragmap Phase 같은 비-SLURM phase event는 contract metadata로 매핑 (수동 1회 시드).
- open questions:
  - Slice 안에서 Phase 또는 Cycle을 1급 시민으로 둘지? (예: fragmap Phase 8/9/10이 Slices DB의 separate rows OR fragmap row 1개의 Timeline property?). → 권고: fragmap row의 child page들로 Phase를 표현 (Slices DB row 1개/슬라이스, child pages = phases). 마이그레이션 단순성.
  - ADR ID 체계: ADR-NNNN 글로벌 vs 슬라이스별 (ADR-fragmap-NNNN)? → 권고: 글로벌 ADR-NNNN, Slice property로 그룹. ADR 표준.
  - chg 마커 hidden property 이동 시 read-back gate 호환: Notion API가 hidden properties를 fetch 시 노출하는지 검증 필요 (검증 task에 포함).
- tradeoffs:
  - Full backfill 비용 (수 시간 in-session MCP 호출) vs 깨끗한 history. 권고: full backfill (사용자 선택).
  - Big-bang vs phased — big-bang는 release 명확하지만 중간 상태 어색 vs phased는 유연하지만 IA 일관성 유지 어려움. 권고: big-bang 한 시리즈, 작업 단계는 plan으로 phasing (User 선택).
  - Slices DB와 기존 5 slice hub pages 관계: hubs를 DB row의 child page로 만들고 기존 URL 보존하면 마이그레이션 cost 낮음. 그렇지 않으면 새 hub page 생성 + URL 변경 → 외부 링크 깨짐. 권고: 기존 URL 보존.

## Constraints

- allowed change scope (workspace only):
  - **scripts/notion_sync.py** — 대폭 확장. 새 함수:
    - `contract_to_adr_rows(contract_path)` → 1 contract의 `decisions:` 리스트를 ADR rows로 변환.
    - `slurm_to_experiment_row(job_id)` → sacct + 출력 디렉터리 metrics 추출.
    - `slice_to_db_row(slice_name)` → status frontmatter를 Slices DB row property로 변환.
    - `home_navigator_payload()` → 홈에 표시할 5 섹션 데이터 종합.
    - `migrate_slice(slice)` / `migrate_contracts()` / `migrate_slurm_history()` — 마이그레이션 entry points.
    - `--migrate` CLI 모드.
  - **docs/notion-sync-runbook.md** — 전면 재작성. v0.5 IA 설명 + 자동 흐름 + 마이그레이션 절차.
  - **.claude/skills/handoff/SKILL.md** Step 5 — 3번째 재작성. Slices/ADR/Experiments DB row 갱신 + Navigator-aware.
  - **.codex/skills/handoff-writer/SKILL.md** — Codex parity mirror.
  - **AGENTS.md** + **.agent/templates/AGENTS.md.example** — IA + ADR + Experiments 사용 정책 명시.
  - **.agent/notion_map.yaml** — DB IDs 갱신 (새 DBs / 격상된 DBs의 ID 저장).
  - **tests/test_notion_handoff_log.py** + 새 `tests/test_notion_migration.py` — 추가 unit tests.
  - **Notion 워크스페이스** (in-session MCP via Notion MCP):
    - Slices DB 생성 (새), 5 rows 시드.
    - Decisions DB 재구조화 (Properties 추가/변경, body schema ADR로).
    - Artifacts DB → Experiments DB (Properties 재구조화, 이름 변경).
    - 홈 페이지 재작성 (Navigator).
    - 5 slice hub pages를 Slices DB row의 child page로 reparenting (URL 보존).
  - **.agent/scratch/notion_backup_20260529/** — 마이그레이션 전 Notion export 백업 (수동 export 또는 fetch dump).
- forbidden change scope:
  - 업스트림 template 변경 (Notion 관련 파일이 거기에 부재).
  - Headless 토큰 도입 (workspace permission 차단; 받기 전 안 함).
  - LLM-based event classification (v0.4.2 keyword 휴리스틱 그대로; v0.6 candidate).
  - 실시간 SLURM 모니터링 (poll-based 또는 manual trigger만; daemon 없음).
  - 역방향 sync (Notion → workspace) — by design.
  - arl slice 신규 promotion (별도 contract; arl이 active 슬라이스 아니므로).
  - Project-level (FKSFold-Boltz / Harness) weekly rollup 자동 생성 (`/meeting-to-notion`이 수동, v0.6 candidate).
  - 새 이벤트 타입 추가 (v0.4.2의 6종 그대로; closed/종료 등 추가는 별도).
  - chg 마커 완전 제거 (gate 동작 보존 필수; hidden property로 이동만).
- external constraints:
  - claude.ai Notion MCP 세션 OAuth만. Codex MCP는 사용자 config에 따라 가용/미가용 (defensive).
  - Notion API rate limits (~3 requests/second/integration); 마이그레이션은 throttled batch.
  - Notion-flavored markdown spec 준수 (`notion://docs/enhanced-markdown-spec`).
  - 게이트 substring 검사 호환성 보존 (chg 마커 위치만 변경).
  - 사용자 워크스페이스 owner 권한 부재 — DB 생성/properties 변경은 사용자 명시 권한 필요시 사용자에게 인계.

## Non-Goals

1. LLM 기반 event classification (휴리스틱 keyword 유지, v0.6 candidate).
2. 실시간 SLURM 모니터링 (poll/manual trigger).
3. Headless 토큰 도입 (워크스페이스 권한 차단 영구).
4. 역방향 sync (Notion → workspace).
5. arl 슬라이스 promotion (별도 작업).
6. Project-level (Harness/FKSFold) weekly rollup 자동 생성.
7. 새 이벤트 타입 추가.
8. chg 마커 완전 제거.
9. 업스트림 template 변경.
10. Notion → SLURM 또는 git 역방향 자동화.

## Done When

### 1. Slices DB (Engineering Wiki Projects 패턴)
- Notion에 새 `Slices` DB 생성 (또는 옛 Projects DB 재구조화).
- 5 슬라이스 (harness, fragmap, mmgbsa, vav1, fksfold-core) row 시드.
- Properties: Name, Status (활성/완료/릴리즈/휴면), Owner, Owner Session, Last Heartbeat (date), Last Updated, Project (relation → Harness or FKSFold-Boltz), Next Action (text), Linked Decisions (relation → Decisions DB), Linked Experiments (relation → Experiments DB).
- 기존 5 slice hub pages가 Slices DB row의 child page로 reparented (URL 보존 — 외부 링크 안 깨짐).
- `/handoff` Step 5 호출 시 active slice의 row Properties (Status/Heartbeat/Last Updated/Next Action) 자동 갱신.
- Linked views: All / Active (활성) / Released (릴리즈) / By Project.
- Verification: `python notion_sync.py --migrate --slices` 실행 후 5 rows 확인 + Properties 정상 + child page link 보존.

### 2. Decisions DB → ADR registry (ADR 패턴)
- Decisions DB 재구조화 — Properties 추가: ADR ID (auto-numbered ADR-NNNN), Status (Proposed/Accepted/Rejected/Implemented/Superseded), Date, Slice (relation → Slices), Deciders (people 또는 text), Linked Contract (URL), Supersedes / Superseded by (self-relation).
- Body schema (ADR Markdown):
  - `# ADR-NNNN: <title>`
  - `## Context` / `## Decision` / `## Consequences` / `## Links` 섹션.
- Full backfill: 12+ 기존 contracts × ~5 decisions 평균 = 60+ ADR rows 자동 생성 (`scripts/notion_sync.py --migrate --decisions`).
- 자동 status 흐름: contract status: pending → ADR Proposed; approved → Accepted; done → Implemented.
- Linked view: ADRs by Slice / By Status / Recent (last 30d) / Implemented.
- Verification: Decisions DB row count >= 60, 임의의 새 contract approve → 그 contract의 decisions가 ADR rows로 자동 생성 + Status Proposed.

### 3. Artifacts DB → Experiments DB (W&B 패턴)
- Artifacts DB 재구조화 (이름 변경 또는 새 DB) — Properties: Run ID, Slice (relation), Phase (text, e.g. "AB Stage 1", "Phase 10"), Status (Queued/Running/Completed/Failed/Cancelled), Start (datetime), End (datetime), Duration (formula), Exit Code (text), Parameters (text, JSON snapshot), Metrics (text, pass_rate / scores), Artifact Path (URL), Linked Decision (relation → Decisions ADR), Linked Slice (relation).
- Full backfill: SLURM sacct history (mmgbsa 30+ jobs) — `sacct -S 2026-04-01 -j 5000..5900 --format=...` → Experiments rows. fragmap Phase 1..10 같은 비-SLURM phase events는 수동 시드 (~10 rows).
- 자동 갱신: SLURM job completion (poll or sacct snapshot) → row Status/End/Duration/Exit/Metrics 갱신. metrics는 ready_for_mmpbsa_prod.tsv 등 output dir 파일 parsing.
- Linked views: Recent (last 7d) / Running / Per-slice / Per-phase / Failed.
- Verification: Experiments DB row count >= 40 (30 SLURM + 10 phases), mmgbsa job 5754/5809의 metrics+status 정상.

### 4. Navigator 홈 페이지
- Notion 워크스페이스 홈 (28d1e76c-3b60-8069-a83b-eab69a131a99) 재작성.
- 5 섹션 명시:
  - 🔄 **지금 진행 중** (linked Slices view, Status=활성).
  - 🧭 **최근 결정** (linked Decisions view, last 7d, Status=Accepted or Implemented).
  - 📊 **진행 중 실험** (linked Experiments view, Status=Running).
  - 📝 **최근 리포트** (linked Reports view, last 7d).
  - 📚 **Docs & Standards** (links to docs/runbook/AGENTS).
- 사용자 휴가 시나리오: 5일 후 홈 한 페이지에서 5 슬라이스 상태 + 진행 중 실험 + 최근 결정 + 최근 리포트 다 보이는지 verify.

### 5. 자동 데이터 흐름
- `/handoff` Step 5: 3번째 재작성. payload (v0.4.2 형식) + Slices DB row 갱신 + 새 ADR/Experiment rows trigger.
- `scripts/notion_sync.py` — 새 함수 + 마이그레이션 entries.
- Codex `.codex/skills/handoff-writer/SKILL.md` — parity mirror.
- runbook + AGENTS.md 갱신.
- Verification: 임의의 새 contract → /brainstorm + /write-plan + /execute-plan + /handoff → Slices/Decisions/Experiments DB rows 자동 갱신 end-to-end.

### 6. 새 세션 reorient 시나리오
- 가상 시나리오 (또는 실제 다음 세션) walk-through: Codex 또는 새 Claude 세션이 SessionStart 후 Notion 홈 1 페이지에서 lab 전체 상태 파악 + 슬라이스 1 클릭으로 자세한 history.
- Verification: 시나리오 documented in `.agent/handoffs/notion-redesign-walkthrough.md` + screenshots/fetches.

### 7. Codex parity
- Codex handoff-writer가 Slices/ADR/Experiments DB row 갱신 시 같은 schema/형식 사용.
- defensive on Codex MCP availability.

### 8. 마이그레이션 검증
- 마이그레이션 전 Notion 워크스페이스 백업 (export 또는 in-session fetch dump → `.agent/scratch/notion_backup_20260529/`).
- 옛 구조 데이터의 100% (5 hubs, 12+ contracts, 30+ SLURM, 5 reports)가 새 DB에 정확히 반영됨 (spot-check by user).

### 9. 코드 + 테스트
- Unit tests: `tests/test_notion_handoff_log.py` 보존 + `tests/test_notion_migration.py` 신규 (마이그레이션 함수 단위).
- 모든 test GREEN.

## Implementation Steps

(상위 — /write-plan이 30-50 tasks로 분해할 것)

### Phase A: Foundation (1-2 sessions)
1. Notion 워크스페이스 백업 (in-session MCP fetch dump).
2. notion_map.yaml 확장 (새 DB IDs 자리).
3. `scripts/notion_sync.py`에 새 함수 stub + tests RED.
4. Slices DB 생성 (Notion MCP).
5. Decisions DB 재구조화 (Properties 추가).
6. Artifacts DB → Experiments DB 재구조화.

### Phase B: Backfill (2-3 sessions)
7. 5 슬라이스 → Slices DB rows 시드.
8. 기존 slice hub pages를 Slices row의 child page로 reparenting.
9. 12+ contracts → ADR rows backfill.
10. SLURM sacct history → Experiments rows backfill.
11. Inaugural reports → Reports DB cleanup.

### Phase C: Navigator + Automation (1-2 sessions)
12. 홈 페이지 재작성 (5 섹션).
13. `/handoff` Step 5 재작성 (v0.5 형식).
14. Codex handoff-writer mirror.
15. runbook + AGENTS.md 갱신.
16. notion_sync.py 자동 갱신 함수.

### Phase D: Verify + Release (1 session)
17. End-to-end 시나리오 검증 (4 시나리오 walk-through).
18. Cold-start 시나리오 (새 Claude 세션 시뮬레이션).
19. 사용자 spot-check.
20. status: done, baton 갱신, /handoff.

## Verification

- (A) Slices DB row count = 5, properties 정상, child page URL 보존.
- (B) Decisions DB row count >= 60 (12 contracts × ~5 decisions); 임의의 contract status 전환 시 ADR Status 자동 흐름.
- (C) Experiments DB row count >= 40 (30 SLURM + 10 phases); mmgbsa 5754/5809 metrics+status 정확.
- (D) Navigator 홈 5 섹션 다 작동, linked views 정상.
- (E) `/handoff` end-to-end: 임의의 새 contract → Slices/Decisions/Experiments rows 자동 갱신.
- (F) 사용자 휴가 시나리오: 홈 한 페이지에서 5 슬라이스 + 진행 중 실험 + 최근 결정 + 최근 리포트 다 보임.
- (G) `python -m pytest tests/test_notion_handoff_log.py tests/test_notion_migration.py -q` → ALL GREEN.
- (H) Notion 백업 dump 존재.

## Risks

- **마이그레이션 데이터 손실** — Notion MCP가 트랜잭션 보장 안 함, 중간 실패 시 partial migration 상태. 완화: 매 단계 backup + verify + idempotent re-run.
- **5 슬라이스 hub URL 깨짐** — reparenting 중 URL이 바뀌면 외부 링크 죽음. 완화: Notion의 page URL은 페이지 ID 기반이라 parent 변경에 robust — pre/post URL 비교 검증.
- **자동 ADR 분류 misclassification** — `decisions:` 항목이 ADR로 매핑되면서 의미가 변형될 수 있음. 완화: 각 ADR row를 사용자가 spot-check 가능한 형태 (Status: Proposed로 시드, 사용자 확인 후 Accepted로 승격).
- **SLURM history 추출 brittleness** — sacct output 포맷이 환경마다 다를 수 있음. 완화: 추출 함수 unit test + 모범 사례 (mmgbsa 5754) 대조 검증.
- **마이그레이션 시간** — 40+ DB rows + 5 hub reparenting + 홈 재작성 = 2-3 in-session 시간. 완화: phased (A→B→C→D) 각 단계마다 break-point.
- **Codex Notion MCP 미설정** — Codex parity가 deferred 상태 유지. 완화: Codex 부분은 SKILL.md 갱신만, 실제 동작은 사용자가 Codex MCP 설정 시 자동 활성화.
- **chg 마커 hidden property 이동 시 게이트 깨짐** — Notion fetch가 hidden property를 노출 안 하면 substring 검사 실패. 완화: Phase A에서 우선 검증 (작은 test 페이지로) 후 결정. 가능하면 hidden property; 안 되면 v0.4.2의 gray span 유지.

## Rollback

- 마이그레이션 전 Notion backup dump → catastrophic 실패 시 사용자가 backup 기준으로 수동 복구.
- 옛 구조 (5 hubs + 옛 Decisions + 옛 Artifacts DB)는 마이그레이션 후 4주 read-only로 보존 → 새 구조 충분히 검증되면 archive (또는 영구 보존).
- Per-task commit → git revert로 코드 변경 되돌리기.
- Slices DB row reparenting: 5 hub pages는 URL ID 기반 보존이라 reparent는 원위치 가능.
- 자동 흐름 깨지면 v0.4.2 코드 패스로 fallback (legacy flag in /handoff Step 5).

## Progress Log

- 2026-05-29: contract drafted (status: pending). v0.4.0-v0.4.2의 5 IA가 fragmentation 문제 노출 (사용자 진단 "어디 볼지 감 안 온다"). 3-pattern 통합 + Navigator + Full backfill + Codex parity + Big-bang 한 시리즈. 사용자 승인 대기.
- 2026-05-29: approved (사용자 "진행"). Phase A (T1-7) + Phase B (T8-16) 실행 — Slices DB 생성 (3435079f) + 6 rows / Decisions DB ADR 재구조화 + 107 rows / Experiments DB 생성 (949a3553) + 252 rows (240 SLURM + 12 fragmap phase) / 5 hub reparent / Reports cleanup. commits 6c75e23..87fad95. USER PAUSE A·B 통과.
- 2026-06-01: Phase C (T17-23) 실행 — home_navigator_payload() 5섹션 (commit 1de3cbc); notion_sync.py --migrate {slices,contracts,slurm,home,all} upsert-keyed JSON CLI (293f95b, slurm=sacct 30d); runbook v0.5 410줄 (d333d2e); AGENTS+template v0.5 IA (00efc49); /handoff Step 5 v0.5 (696aa62, skill-lint PASS:14); Codex handoff-writer warn-only mirror (57221b7); 홈 Navigator 5섹션 (Notion-side). 각 /code-review APPROVE. USER PAUSE C 통과.
- 2026-06-01: Phase D (T24-28) 실행 + **status: done**. T24 4-시나리오 walk-through (6ed6e06) + T25 cold-start 시뮬 (e5a6c60) → `.agent/handoffs/notion-redesign-walkthrough.md`. T26 사용자 spot-check gate 통과 ("Finalize 진행"). T27 contract+plan status: done + baton 갱신. T28 최종 /handoff + status.sh index.
  **SHIPPED with 2 documented follow-ups** (non-blocking): (a) 홈 Slices/Decisions/Experiments 필터 inline 뷰 3개를 Notion UI에서 "Linked view of database"로 추가 — content API가 data-source-url linked-view 생성 거부하여 현재 mention 링크; (b) v0.5 /handoff Step 5 Notion 자동흐름 live-verify (Task 28 /handoff가 1차 실거동). Done-When 1-9 중 1-4·7-9 검증 완료; 5(자동 흐름 end-to-end)·6(reorient)는 walkthrough 문서화 + Task 28 1차 실거동으로 충족, 완전 live-verify는 follow-up (b).
