# fragmap-npz-viz-illustration

- **Status**: pending
- **Slice**: fragmap
- **Approval**: requested 2026-06-08 · approved by: pending
- **Scope class**: read-only visualization (zero-GPU, zero-compute beyond local render)
- **Triggers matched**: none of the WORKFLOW.md §2 hard triggers
  (no SLURM submit, no ranking/scoring-mode change, no npz re-freeze, no shared-storage
  write, no public API). Contract drafted because the user explicitly asked for a spec gate
  via /brainstorm; this is effectively an additive illustrative-figure task.

## Purpose

새로 만든 GCMC v2 FragMap(`ternary_r{1,2}_maps.npz`)이 단백질 pocket 주변에 어떤
favorable 화학 환경(hotspot)을 그리는지 **설명용 일러스트**로 보여주는 그림 세트 + 문서를
만든다. 방금 만든 `/home/ubuntu/structure_viz_20260608/` 구조 번들의 후속편으로, "우리
FragMap이 이렇게 생겼다"를 팀/보고용으로 한눈에 전달하는 것이 목적이다.

## Current State

- **입력 (읽기 전용, shared)**: `/mnt/data/users/ubuntu/workspace/gcmc_ternary_10x_20260602/npz_v2/ternary_r1_maps.npz`,
  `…/ternary_r2_maps.npz`. 각각 89×94×70 / 89×96×70 voxel, **spacing 1.0Å**, `origin`(실공간
  좌표), `grid_exclusion` 마스크, `source_pdb`(<U97 경로), `source_runs`(GCMC 5런), 그리고
  ~12개 GFE 채널: `grid_aromatic`, `grid_hydrophobe`, `grid_donor`, `grid_acceptor`,
  `grid_positive`, `grid_acceptor_ether`, `grid_amide_donor`, `grid_amide_acceptor`,
  `grid_amide_donor_acceptor`, `grid_heteroaromatic`, `grid_imidazole_donor`,
  `grid_imidazole_acceptor` 등. **favorable = 음수 GFE**(최저 ~−3.5 kcal/mol), **+5.0 = exclusion cap**.
- **렌더 도구**: PyMOL conda env `/home/ubuntu/miniconda3/envs/pymol` (헤드리스 ray, 검증됨).
- **단백질 pose**: 9NFR P7 (`/home/ubuntu/best_structures/VAV1_345_best_P7_seed16.pdb`),
  structure_viz 번들과 동일 frame. 단 npz는 자체 `origin`/frame을 가지므로 grid와 pose의
  좌표계 정합 여부를 구현 전 반드시 확인해야 한다(아래 Open question 1).
- **없음**: npz 그리드를 PyMOL이 직접 읽지 못한다 → CCP4/MRC 맵 파일로 변환 후 `isomesh`/
  `isosurface`로 그리는 경로가 필요.

## Assumptions And Questions

- **assumptions**:
  - 목적은 설명용 일러스트(정량 비교/검증 아님).
  - 9NFR pose 위에 r1·r2 두 지도 모두, ~12채널 전부 표시.
  - favorable hotspot만 보이면 됨(+5.0 cap·양수 영역은 숨김).
- **open questions** (구현·write-plan 단계에서 해소):
  1. **좌표계 정합**: npz `origin`/frame이 9NFR P7 pose의 PDB 좌표계와 같은가? `source_pdb`가
     9NFR라면 직접 정합; 아니면 source_pdb를 9NFR에 superpose한 변환을 grid에도 적용해야 한다.
     (안 맞으면 hotspot이 엉뚱한 곳에 뜸 → 그림이 무의미.)
  2. **isosurface threshold**: 전역 단일 컷(예: GFE ≤ −1.0 kcal/mol)인지 채널별 적응형
     (예: 각 채널 GFEmin의 일정 비율)인지. 채널마다 favorability 범위가 달라 단일 컷이면
     약한 채널은 안 보일 수 있음.
  3. **채널 12개 표현 방식**: 채널별 개별 그림 vs 색상 코딩 합성 1장 vs 둘 다. 12개 합성은
     겹쳐서 복잡 → 그룹(aromatic류/donor류/acceptor류/hydrophobe)으로 묶는 안 검토.
- **tradeoffs**: 전체 12채널 = 정보량↑·가독성↓. 그림 수 증가(r1·r2 × 채널/그룹).

## Constraints

- **allowed change scope**: 신규 로컬 번들 디렉토리(예: `/home/ubuntu/fragmap_npz_viz_20260608/`)에
  렌더 스크립트(1) + 변환 유틸 + PNG + 마크다운 문서. npz→CCP4 임시 맵은 번들 내 또는 /tmp.
- **forbidden change scope**: npz **재생성/재freeze 금지**(fragmap HARD RULE), FragMap scoring/
  steering 코드(`src/boltz_extension/steering/`) 미변경, ranking 의미 변경 없음, SLURM 미제출.
- **external constraints**: zero-GPU, read-only on `/mnt/data` shared npz. fragmap 슬라이스는
  현재 다른 세션(32ff4da0)이 소유 → 이 작업은 슬라이스 baton/프로젝트 repo를 건드리지 않는
  로컬 번들 + pending 계약만 추가(비충돌).

## Non-Goals

- **v1 vs v2 정량 비교** — 별도 작업(이번엔 v2 일러스트만).
- **GCMC 재실행 / 채널 finalize / map 품질(QC) 검증** — map 자체는 주어진 것으로 사용.
- **steering·scoring 동작 변경, A/B pilot 결과 해석** — 무관.
- **다른 타깃(9DWW 등) FragMap** — 이번엔 9NFR(VAV1) 지도만.

## Done When

- r1·r2 두 지도 각각에 대해, ~12 favorable 채널의 isosurface를 9NFR P7 pose 위에 렌더한
  PNG 세트가 생성된다(채널별 또는 채널그룹별 + 합성 overview).
- 좌표계 정합이 확인된다: hotspot이 단백질 pocket(CRBN–VAV1 계면) 영역에 국소화되어 보인다
  (origin/frame 정합 sanity check 통과).
- 그림을 설명하는 마크다운 문서(채널 의미·threshold·정합 방법·재현 커맨드)가 작성된다.
- 렌더 스크립트가 재실행 가능하다(`pymol -cq <script>` 한 줄).

## Implementation Steps

1. npz `origin`/`source_pdb` 확인 + 9NFR pose 좌표계 정합 결정 (Open Q1)
   verify: source_pdb 경로 출력 + 9NFR과 CA-RMSD 또는 frame 일치 여부 로그
2. npz 채널 → CCP4/MRC 맵 변환 유틸 작성 (origin/spacing 반영, +5.0 cap 마스킹)
   verify: 변환된 맵 1개를 PyMOL이 load + isomesh로 그림
3. threshold 정책 결정 후 채널/그룹별 isosurface 렌더 스크립트 작성 (r1·r2 루프)
   verify: PNG들이 생성되고 hotspot이 pocket에 국소화
4. 마크다운 문서 작성 (채널 범례·threshold·정합법·재현 커맨드)
   verify: 문서 + 그림 링크 동작
5. (선택) structure_viz 번들과 교차 링크
   verify: 상호 참조 추가

## Verification

- task-specific: `/home/ubuntu/miniconda3/envs/pymol/bin/pymol -cq <render_script>` 가 PNG 생성
- manual check: 대표 PNG 1–2장 육안 확인 — favorable hotspot이 CRBN–VAV1 pocket에 위치
- sanity: grid origin 정합 — hotspot이 단백질 밖 허공에 뜨지 않는지

## Risks

- **좌표계 mis-alignment**: npz frame ≠ 9NFR pose면 hotspot이 엉뚱한 곳 → 그림 무의미.
  완화: Step 1에서 source_pdb 정합 먼저 확정(가장 큰 리스크).
- **threshold 부적절**: 너무 빡세면 빈 그림, 너무 느슨하면 노이즈 덩어리. 완화: 채널별 적응형.
- regression risk: 없음(읽기 전용·로컬 산출물).

## Rollback

- **revert strategy**: 신규 번들 디렉토리 삭제로 끝(프로덕션 영향 없음). git 커밋 시 단순 revert.
- **containment strategy**: npz·src 미변경이므로 잘못돼도 파이프라인/지도에 영향 없음.

## Progress Log

- 2026-06-08: /brainstorm 스펙 게이트 통과 — Q1 목적=설명용 일러스트, overlay=9NFR pose에
  r1+r2 둘 다, 채널=전체 ~12. 초안 작성, 승인 대기.
