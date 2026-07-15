# Notion v0.5 IA 재설계 — 시나리오 walk-through

> Task 24 산출물 (plan `harness-notion-redesign-20260529`, Phase D).
> 4개의 시나리오를 **실제로 ship된 v0.5 Notion 상태** 기준으로 기술한다.
> 각 시나리오는 다음 형태를 따른다:
> **사용자가 X를 하면 → 시스템이 Y를 (자동 또는 `/handoff` Step 5 semi-auto) → 사용자가 홈에서 Z를 본다.**
>
> 모든 Notion URL은 `.agent/notion_map.yaml`의 실제 ID에서 빌드했다 (id에서
> 하이픈을 제거한 형태: id `28d1e76c-3b60-8069-...` → `https://www.notion.so/28d1e76c3b608069...`).

## 0. 실제 v0.5 상태 (전제 — 모두 ship됨)

- **Navigator 홈**: <https://www.notion.so/28d1e76c3b608069a83beab69a131a99>
  - 5개 섹션: 🔄 진행 중 슬라이스 / 🧭 최근 결정 / 📊 진행 중 실험 / 📝 최근 리포트 / 📚 Docs.
- **Slices DB** (id `3435079f-07ca-4d3c-85c8-f51f0efb0936`):
  <https://www.notion.so/3435079f07ca4d3c85c8f51f0efb0936> — 6 rows
  (fragmap / mmgbsa / vav1 / fksfold-core / harness / arl).
  - mmgbsa row: <https://www.notion.so/36f1e76c3b60814090a5ebf0d42e4702>
  - harness row: <https://www.notion.so/36f1e76c3b6081e7af5fc32c7443755f>
  - fragmap row: <https://www.notion.so/36f1e76c3b60819590ced22406675706>
- **Decisions DB** (ADR registry, data source `b11ae976-472b-46dd-98d9-b42ebe2e8b7b`):
  현재 107 ADR rows (102 backfill + 5 기존 큐레이션). Status enum:
  Proposed / Accepted / Rejected / Implemented / Superseded.
- **Experiments DB** (id `949a3553-1e44-41a7-a8d3-d673ae2f0efe`):
  <https://www.notion.so/949a35531e4441a7a8d3d673ae2f0efe> — 252 rows
  (240 SLURM jobs + 12 fragmap phase). canonical 예: mmgbsa job **5754**.
  Status enum: Queued / Running / Completed / Failed / Cancelled.

### ⚠️ 정직성 caveat (두 군데에 영향 — 시나리오 안에서 다시 표시)

1. **홈의 필터링은 아직 미완**: 홈의 🔄 진행 중 슬라이스 / 🧭 최근 결정 /
   📊 진행 중 실험 섹션은 현재 **클릭 가능한 `<mention-database>` 링크**다.
   Notion content API가 새 data-source-url linked-view 생성을 거부해서, 이
   3개는 필터링된 inline view가 **아직 아니다**. 📝 최근 리포트 섹션만 진짜
   inline view다. → "사용자가 홈에서 Z를 본다"에서 필터(활성/Running/최근7일)에
   기대는 단계는 **DB 한 번 더 클릭**이 필요하다. PENDING manual follow-up:
   Notion UI에서 "Linked view of database" 블록 3개를 필터와 함께 추가 (~3분).
2. **`/handoff` Step 5 v0.5 자동 흐름은 end-to-end로 아직 live-verify 안 됨**:
   아래 "시스템이 Y를 자동" 절반은 **설계/ship된 동작(designed/shipped)**으로
   기술한다. best-effort · NON-BLOCKING · **Claude 전용** · **MCP-only**
   (compute-then-apply: `notion_sync.py`는 payload를 PRINT만 하고, 세션의
   Notion MCP가 실제 write) · change-gated. MCP가 없으면 이 자동 write는
   조용히 **SKIP**되고 `/handoff` 자체는 그대로 완료된다 (durable record는
   slice 파일 + `handoff.sh` 스냅샷).

---

## 시나리오 1 — mmgbsa Stage 1 완료

**사용자가 X**: mmgbsa SLURM job (예: job **5754**, AB Stage 1)이 sacct에서
`COMPLETED`로 끝난다. 사용자/에이전트가 mmgbsa 슬라이스에서 `/handoff`를 돌린다.

**시스템이 Y (semi-auto via `/handoff` Step 5, best-effort)**:
- Step 5.1: `./scripts/notion_sync.py --migrate slices` + `--migrate slurm`로
  payload를 PRINT한다 (Notion 호출 없음). `slurm_to_experiment_row(5754)`가
  sacct에서 `{run_id, slice=mmgbsa, status, start, end, duration, exit, metrics}`를
  추출한다 (`_SACCT_STATE_TO_STATUS`로 `COMPLETED → Completed`).
- Step 5.4 (Experiments scan): 새로 완료된 job이 있으면 세션 MCP가 Experiments DB
  row(upsert key = `Run ID`)를 upsert — Status `Running→Completed`, End/Duration/
  Exit/Metrics 채움. 새 job이 없으면 SKIP.
- Step 5.2 (Slices DB row): mmgbsa row(`36f1e76c-3b60-8140-90a5-ebf0d42e4702`)를
  `slice_to_db_row("mmgbsa")` 결과로 `notion-update-page` — Last Heartbeat /
  Last Updated / Next Action 갱신. (state가 `active`이므로 Status는 `활성` 유지.)
- 이 `/handoff`가 contract status 전환에서 트리거된 게 아니면 ADR 단계(5.3)는 SKIP.
- NON-BLOCKING: MCP 없거나 sub-step 에러 → stderr 한 줄 + 중단, handoff는 완료.

**사용자가 홈에서 Z**: 홈 <https://www.notion.so/28d1e76c3b608069a83beab69a131a99>
열어서 📊 진행 중 실험 섹션 → Experiments DB
<https://www.notion.so/949a35531e4441a7a8d3d673ae2f0efe> 진입. job 5754 row가
Completed로, mmgbsa row의 Next Action이 갱신된 걸 본다.
⚠️ caveat 1: 홈 📊 섹션이 아직 `Running` 필터 inline view가 아니라 DB 링크라서,
"진행 중만" 보려면 DB에서 Status=Running 필터를 한 번 더 적용해야 한다.

---

## 시나리오 2 — harness v0.4.1 ship cycle

**사용자가 X**: harness v0.4.1 contract가 `pending → approved → done`으로 흐른다
(`.agent/contracts/harness-v041-lifecycle-hotfix-20260529.md`). 각 전환마다
harness 슬라이스에서 `/handoff`를 돌린다.

**시스템이 Y (semi-auto via `/handoff` Step 5.3, conditional)**:
- 이 `/handoff`가 **contract status 전환**(`pending→approved` 또는
  `approved→done`)에서 트리거됐을 때만 ADR 단계가 실행된다.
- `contract_to_adr_rows(<contract_path>)`가 contract의 `decisions:` 리스트를
  항목당 1개 ADR dict로 변환한다 (v0.4.1 contract → 5개 ADR). Status는
  `_CONTRACT_STATUS_TO_ADR` 매핑: `pending→Proposed`, `approved→Accepted`,
  `done→Implemented`.
- 세션 MCP가 Decisions data source(`b11ae976-472b-46dd-98d9-b42ebe2e8b7b`)에
  ADR rows를 upsert한다 (upsert key = `adr_id`). 따라서 같은 contract가
  approve→done으로 흐르면 **동일 row의 Status가 Accepted→Implemented로 갱신**되지,
  중복 row가 안 생긴다.
- Step 5.2: harness row(`36f1e76c-3b60-81e7-af5f-c32c7443755f`)의 Status를
  `slice_to_db_row("harness")`로 갱신 (state `active→closed`면 `활성→완료`).

**사용자가 홈에서 Z**: 홈 🧭 최근 결정 섹션 → Decisions DB(ADR registry)에서
harness-v041 contract의 5개 ADR이 Proposed→Accepted→Implemented로 흐른 걸 본다.
harness Slices row의 Status도 그에 맞춰 보인다.
⚠️ caveat 1: 🧭 섹션도 아직 "최근 7일 + Accepted/Implemented" 필터 inline view가
아니라 DB 링크라서, 필터링된 최근 결정만 보려면 DB에서 필터를 한 번 더 적용한다.

---

## 시나리오 3 — fragmap Phase 10 closure

**사용자가 X**: fragmap phase/contract가 닫힌다 (예: `fragmap-*` contract가
`status: done`). fragmap 슬라이스에서 `/handoff`를 돌린다.

**시스템이 Y (semi-auto via `/handoff` Step 5, best-effort)**:
- fragmap Phase는 SLURM job이 아니라 contract에 묶인 phase event다. Experiments DB에
  이미 12개 fragmap phase rows(Task 15 시드, Run ID = contract slug)가 있다. phase가
  닫히면 해당 row의 Status를 `Completed`로 upsert한다 (upsert key = `Run ID`).
- Step 5.3 (ADR): contract가 `approved→done`으로 전환됐으면
  `contract_to_adr_rows()`가 그 contract의 ADR rows를 `Implemented`로 갱신.
- Step 5.2 (Slices row): fragmap row(`36f1e76c-3b60-8195-90ce-d22406675706`)의
  Next Action을 다음 phase로 갱신. fragmap이 active로 계속되면 Status는 `활성` 유지.

**사용자가 홈에서 Z**: 홈 → Experiments DB
<https://www.notion.so/949a35531e4441a7a8d3d673ae2f0efe>에서 그 fragmap phase row가
Completed, Decisions DB에서 해당 ADR이 Implemented, fragmap Slices row의 Next Action이
다음 phase를 가리키는 걸 본다.
⚠️ caveat 2: 위 자동 write는 designed/shipped 동작이며 아직 end-to-end live-verify
전이다. MCP 미가용이면 이 갱신은 SKIP되고, fragmap 슬라이스 파일이 durable record다.

---

## 시나리오 4 — 새 세션 reorient (cold-start)

**사용자가 X**: 새 Claude/Codex 세션 또는 휴가에서 돌아온 사용자가 Navigator 홈을 연다.

**시스템이 Y**: 자동 write 없음 — 홈은 이미 ship된 정적 Navigator(Task 18)다.
SessionStart 후 홈 한 페이지가 lab 전체 상태의 진입점이다.

**사용자가 홈에서 Z (1-2 클릭)**:
1. 홈 <https://www.notion.so/28d1e76c3b608069a83beab69a131a99>를 연다 (클릭 0).
   🏠 callout + 5개 섹션이 한 페이지에 보인다.
2. 🔄 진행 중 슬라이스에서 관심 슬라이스(예: mmgbsa) DB 링크 클릭 →
   Slices DB <https://www.notion.so/3435079f07ca4d3c85c8f51f0efb0936> →
   mmgbsa row <https://www.notion.so/36f1e76c3b60814090a5ebf0d42e4702> (클릭 1-2).
   row의 Status/Owner/Last Heartbeat/Next Action + child page로 reparent된
   기존 hub 콘텐츠(전체 history)를 본다.
- pre-v0.5에서는 홈 → project hub → slice hub → digest로 ~5 클릭이 필요했다.
  v0.5는 1-2 클릭으로 단축.
⚠️ caveat 1: 🔄/🧭/📊 섹션은 현재 **클릭 가능한 DB 링크**(필터된 inline view 아님).
"활성 슬라이스만" 같은 필터링된 뷰는 DB 안에서 필터를 한 번 더 적용해야 한다 —
PENDING manual follow-up(3개 Linked-view 블록 추가)이 끝나면 홈에서 바로 필터됨.
📝 최근 리포트만 진짜 inline view라 홈에서 곧장 최신 리포트가 보인다.

---

## 요약

| 시나리오 | 트리거 | 자동(Y)의 성격 | 홈에서 보는 것(Z) |
|---|---|---|---|
| 1 mmgbsa Stage 1 완료 | SLURM `COMPLETED` + `/handoff` | Step 5.4 Experiments upsert + 5.2 Slices row | 📊 → Experiments 5754 Completed |
| 2 harness v0.4.1 ship | contract status 전환 + `/handoff` | Step 5.3 ADR Proposed→Accepted→Implemented | 🧭 → Decisions ADR 흐름 |
| 3 fragmap Phase 10 closure | contract done + `/handoff` | phase row Completed + ADR Implemented + Slices Next | 📊/🧭/Slices 갱신 |
| 4 새 세션 reorient | 홈 열기 | (자동 write 없음 — 정적 Navigator) | 5 섹션 + 1-2 클릭 drill-down |

자동(Y)은 시나리오 1-3에서 모두 `/handoff` Step 5의 best-effort · NON-BLOCKING ·
Claude-only · MCP-only · change-gated 흐름이며, end-to-end live-verify는 별도
pending follow-up이다. 홈의 필터링 inline view(3개 블록)도 별도 manual follow-up.

---

## Cold-start 시뮬레이션

시나리오 4는 "새 세션 reorient"를 high-level로 narrate했다. 이 절은 **휴가에서
돌아온 사용자**(또는 fresh Claude/Codex 세션을 옆에서 보조하는 사람)가 lab 전체
상태를 다시 머리에 올리는 **클릭-바이-클릭** 경로를 구체적으로 추적한다.

### 전제 — 에이전트 cold-start vs 휴먼 cold-start (혼동 금지)

두 cold-start는 **다른 surface**에서 출발한다:

- **에이전트 cold-start (SessionStart)**: 새 Claude/Codex 세션은 Notion을 읽지
  **않는다**. `CLAUDE.md`의 3-step ritual이 권위 있는 진입점이다 —
  (1) `.agent/handoffs/CURRENT.md` 인덱스(파생 lab-wide view) 읽기 →
  (2) 슬라이스의 `.agent/status/<slice>.md` baton(owner_session · heartbeat ·
  remaining_actions) 읽기 → (3) 필요시 `.agent/projects/<slice>-harness.md`로
  drill-down. 즉 `.agent/` 파일이 **에이전트-facing authoritative baton**이다.
- **휴먼 cold-start**: 휴가에서 돌아온 사람은 `.agent/` 마크다운을 grep하지 않고
  **Navigator 홈 한 페이지**를 연다. Notion 홈은 같은 상태의 **휴먼-facing
  reorient surface**다. 아래 클릭 경로가 이 휴먼 경로다.

핵심 매핑: **Notion 홈 = 휴먼 reorient surface**, **`CURRENT.md` / `.agent/status`
= 에이전트 authoritative baton**. 둘은 같은 ground truth(슬라이스 상태)를 각각의
청중에게 비추지만, **에이전트가 SessionStart에 Notion을 읽는다고 가정하지 말 것**.

### 휴먼 cold-start 클릭 경로 (홈 → 5 섹션 → 슬라이스 1개 → 상세)

1. **(클릭 0) 홈을 연다.** Navigator 홈
   <https://www.notion.so/28d1e76c3b608069a83beab69a131a99>.
   🏠 callout + 5개 섹션(🔄 진행 중 슬라이스 / 🧭 최근 결정 / 📊 진행 중 실험 /
   📝 최근 리포트 / 📚 Docs)이 한 페이지에 보인다. 휴가 전 대비 "지금 무엇이
   움직이고 있나"의 한눈 요약 — 에이전트의 `CURRENT.md` 인덱스에 대응하는
   휴먼 뷰다.
2. **(클릭 1) 🔄 진행 중 슬라이스 섹션의 DB 링크를 클릭한다.** Slices DB
   <https://www.notion.so/3435079f07ca4d3c85c8f51f0efb0936>로 진입.
   6 rows(fragmap / mmgbsa / vav1 / fksfold-core / harness / arl)와 각
   Status / Owner / Last Heartbeat / Next Action 컬럼이 테이블로 보인다.
   ⚠️ caveat 1: 🔄 섹션은 아직 필터된 inline view가 아니라 **클릭 가능한
   `<mention-database>` 링크**라서, "활성 슬라이스만"을 보려면 여기서
   Status=활성 필터를 **한 번 더** 적용해야 한다. (PENDING manual follow-up —
   3개 Linked-view 블록이 추가되면 홈에서 바로 필터된 채로 보인다.)
3. **(클릭 2) 관심 슬라이스 row 1개를 클릭한다** (예: 휴가 중 돌던 mmgbsa).
   mmgbsa row <https://www.notion.so/36f1e76c3b60814090a5ebf0d42e4702>.
   row 속성에서 Status / Owner / Last Heartbeat / **Next Action**으로
   "마지막으로 어디까지 갔고 다음 한 수가 무엇인지"를 즉시 확인한다 — 이는
   에이전트가 읽는 `.agent/status/mmgbsa.md` baton의 휴먼 미러다.
4. **(클릭 3) row를 펼쳐 child page(상세)로 들어간다.** 같은 row URL
   <https://www.notion.so/36f1e76c3b60814090a5ebf0d42e4702>의 page body에
   reparent된 기존 hub 콘텐츠(전체 history · 과거 결정 · 아티팩트 링크)가 있어,
   휴가 동안 쌓인 맥락을 한 곳에서 따라잡는다. (다른 슬라이스를 확인하려면
   클릭 1의 Slices DB로 한 번 돌아가 다른 row를 고른다.)

### pre-v0.5 경로와 비교 (~5 클릭 → 3 클릭)

| | pre-v0.5 (문서화된 prior path) | v0.5 (위 경로) |
|---|---|---|
| 경로 | 홈 → project hub → slice hub → weekly digest → row | 홈 → Slices DB → 슬라이스 row → child 상세 |
| 클릭 수 | **~5 클릭** | **3 클릭** (클릭 1·2·3; 홈 자체는 클릭 0) |
| 깊이 | hub가 3계층으로 중첩 + digest를 거쳐야 row 도달 | 홈에서 2-hop으로 row, 1-hop 더로 전체 상세 |

pre-v0.5의 ~5 클릭은 **문서화된 prior path**(홈 → project hub → slice hub →
weekly digest → row)로, 새로 측정한 벤치마크가 아니라 재설계가 줄이려던 기존
경로다. v0.5는 중간 project/slice hub 계층과 digest hop을 제거해 홈에서 슬라이스
상세까지 3 클릭으로 단축했다. ⚠️ 단, caveat 1 때문에 "활성만" 같은 필터를
원하면 클릭 1(Slices DB) 안에서 필터 1회가 추가로 필요하다 — 3개 Linked-view
블록 manual follow-up이 끝나면 이 추가 단계도 사라진다.
