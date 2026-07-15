---
status: done
slice: chronobridge
topic: apo-holo-benchmark
date: 2026-07-13
owner: claude
approved_by: sunghoon.kim (2026-07-13, "승인")
requested: 2026-07-13
cross_slice: []
triggers_matched:
  - "새 슬라이스 (기존 8개 슬라이스 어디에도 매칭되지 않음 — 사용자 확인 후 분리, AskUserQuestion 2026-07-13)"
  - "4개 파일 이상 수정 — 데이터 소싱 스크립트 + 셔플/FP-injection 스크립트 + ChronoBridge order-recovery 구현 + FP 검출기 + 평가 스크립트 + 결과 문서"
---

# chronobridge — Phase A: generic apo/holo dynamics benchmark (CRBN-agnostic)

## Purpose

"Robust ChronoBridge"(구조 앙상블에서 상태 순서/kinetics를 복원하는 방법)와 FP(false-positive)
검출기를 CRBN molecular-glue ternary 시스템(GSPT1 → IKZF family → CK1α → VAV1, 사용자가
이미 확정한 순서)에 적용하기 전에, CRBN과 무관한 일반 apo/holo 단백질 동역학에서 방법론
자체가 작동하는지부터 검증한다. VAV1은 실험 ternary 정답 구조가 없는 최종 prospective
타깃이라, 원인 분리가 안 되는 상태로 바로 붙이면 "구조 생성 실패인가 / FP 검출 실패인가 /
상태 순서가 틀렸나 / VAV1 prior가 틀렸나 / VAV1이 실제로 flexible해서인가"를 구분할 수
없다는 것이 출발점 문제의식이다 (2026-07-13 사용자 대화, 외부 LLM 브레인스토밍을 사용자가
검토·승인).

이번 계약은 **5단계 프로그램 전체가 아니라 Phase A 한 단계만** 범위로 한다. Phase B(GSPT1)
이후는 Phase A 결과를 보고 각각 별도 계약으로 스코핑한다.

## Current State

- 저장소 전체에 "ChronoBridge" 문자열 0건 (grep 확인, 2026-07-13) — 완전히 새로운 코드베이스.
- 참고할 만한 기존 자산: aigen-fold-core의 trunk-latent/poolMSD/3-body hypergraph 인프라가
  있으나, 사용자 확인 결과 이번 파이프라인은 **그 자산을 재사용하지 않고 완전히 새로 구현**
  한다 (AskUserQuestion 2026-07-13). 따라서 aigen-fold-core에 대한 `depends_on`/`cross_slice`
  엣지 없음.
- Phase A에 쓸 공개 MD 트라젝토리 데이터는 로컬/공유 스토리지에 없음 (사용자 확인) — 소싱이
  이번 계약의 첫 번째 task.

## Assumptions And Questions

- assumptions: 공개적으로 구할 수 있는 apo/holo (또는 장시간) MD trajectory 1개 이상으로
  Phase A를 시작할 수 있다 (특정 단백질을 못 박지 않음 — task 1에서 후보를 정하고 기록).
- open questions:
  - 구체적으로 어떤 공개 trajectory를 쓸지 (예: D.E. Shaw Research 공개 장시간 trajectory,
    MDRepo, GPCRmd 등) — task 1에서 후보 비교 후 결정하고 이 문서에 기록.
  - "FP 10-30% 주입"의 정확한 주입 방식(어떤 decoy를 FP로 볼 것인가: 무작위 프레임 셔플,
    다른 trajectory에서 가져온 프레임, rigid-body 교란 등) — task 2에서 확정.
- tradeoffs: 탐색적 진행(GPU/시간 예산 미고정, 사용자 확인)이라 방법이 중간에 막다른 길로
  판명되면 그대로 문서화하고 멈춘다. 조기 확장(더 큰 예산 투입)은 이 결과가 나온 뒤 판단.

## Constraints

- allowed change scope: `.agent/scratch/chronobridge/` 신규 스크립트/데이터/결과물. 새 슬라이스
  상태 파일(`.agent/status/chronobridge.md`)은 이 계약이 approved된 이후, 실제 작업 세션에서
  `scripts/handoff.sh`로 생성.
- forbidden change scope: 기존 슬라이스(aigen-fold-core/vav1-ubq 등)의 코드·계약·상태 파일
  수정 금지. 이번 단계에서는 SLURM 제출 없음(승인 없이 sbatch 시도 금지, WORKFLOW.md §3).
- external constraints: 없음(탐색적, 예산/마감 미지정 — 사용자 확인 2026-07-13).

## Non-Goals

- GSPT1 / IKZF family / CK1α / VAV1 적용(Phase B~E)은 이번 계약의 범위 밖. 각각 Phase A
  결과를 보고 별도 계약으로 스코핑한다.
- aigen-fold-core의 v1.1 랭킹 모델이나 3-body hypergraph 피처 파이프라인을 변경하거나
  재사용하지 않는다(사용자 확인: 완전 신규 파이프라인).
- VAV1-generated pose를 구조 정답으로 쓰는 어떤 실험도 하지 않는다(전체 프로그램의 핵심
  원칙 — self-confirmation 방지).
- 정식 SLURM GPU 실행은 범위 밖(필요해지면 그 시점에 별도 승인).

## Done When

- 후보 공개 apo/holo(또는 장시간) MD trajectory 1개 이상을 확보하고, 소스와 라이선스/출처를
  이 문서 또는 후속 결과 문서에 기록.
- Timestamp를 제거한 뒤 대표 구조 순서를 복원하고, FP(가짜 상태)를 10-30% 주입한 상태에서도
  섞이지 않고 걸러내는 파이프라인을 구현.
- 평가 지표(FP 제거율, Kendall τ, 전이 edge recall, false-shortcut rate, committor calibration,
  MFPT rank)를 랜덤/베이스라인 순서와 비교.
- **PASS 기준(사용자 확인, 2026-07-13): 절대 임계값이 아니라, 랜덤/베이스라인 대비 통계적으로
  유의미하게 우수함** — 최소 부트스트랩 CI가 0(무차이)을 포함하지 않는 지표가 핵심 지표
  (FP 제거율 또는 Kendall τ 중 최소 1개) 기준으로 존재해야 한다.
- 이 저장소의 관행대로, 양성(positive) 결과가 하나라도 나오면 독립 재현/permutation
  null/leave-one-out 등 adversarial verification을 거친 뒤에만 "real"로 보고한다(단순
  point-estimate만으로 보고하지 않음 — 3body-mgoff-features 계약의 선례를 따름).
- 결과 문서(`.agent/scratch/chronobridge/phaseA/results.md`) + 이 계약 상태 `done` 전환.

## Implementation Steps

1. 공개 apo/holo MD trajectory 후보 조사 및 확정(라이선스/규모/접근성 비교), 다운로드/소싱.
   verify: trajectory 파일 확보 + 출처 기록.
2. Timestamp 제거 + FP 주입(10-30%) 스크립트 구현. verify: 주입된 FP 프레임이 원본과 구분
   가능한 라벨로 별도 추적됨(평가용 ground-truth 라벨 보존, 모델에는 미노출).
3. ChronoBridge 순서/kinetics 복원 로직 + FP 검출기 최초 구현(완전 신규). verify: 전체
   trajectory에 대해 순서 예측 + FP 스코어 출력.
4. 평가: FP 제거율/Kendall τ/edge recall/false-shortcut rate/committor calibration/MFPT rank를
   랜덤 순서 베이스라인 및 (있다면) 단순 baseline 방법과 비교, 부트스트랩 CI 계산.
   verify: 비교 표 + CI, point-estimate 단독 보고 금지.
5. 양성 결과 발견 시 adversarial verification(독립 재현, permutation null, 최소 1개 대체
   trajectory에서 재확인). verify: 최소 2개 검증 통과 후에만 "real"로 기록.
6. 결과 문서 작성 + 새 슬라이스 상태 파일(`.agent/status/chronobridge.md`) 최초 생성 +
   `scripts/handoff.sh claude chronobridge` + `scripts/status.sh index`로 CURRENT.md 갱신 +
   이 계약 `status: done` 전환.

## Resource budget

- 탐색적 진행, 고정 GPU/시간 예산 없음(사용자 확인, 2026-07-13). CPU 우선, GPU가 필요해지면
  그 시점에 규모를 다시 판단(GPU는 풍부하나 근거 없이 먼저 늘리지 않는다 — 기존 원칙 유지).
- SLURM 제출은 이 계약 범위 밖. 필요 시 별도 승인 후 새 계약 또는 이 계약의 진행 로그에 명시.

## Risks

- regression risk: 없음 — 신규 슬라이스, 기존 슬라이스 파일 미변경.
- integration risk: 없음 — 독립 파이프라인, 기존 엔진/랭킹 모델 코드 미접촉.
- hidden dependency risk: 공개 trajectory의 라이선스/재배포 제약을 확인하지 않으면 나중에
  결과 공유(Notion 등)에 제약이 생길 수 있음 — task 1에서 출처와 함께 기록.

## Rollback

- revert strategy: `.agent/scratch/chronobridge/` 삭제. 공유 상태 변경 없음(다른 슬라이스
  파일 미접촉이므로 git revert 불필요).
- containment strategy: 새 슬라이스 상태 파일이 아직 없으므로, 이 단계에서 중단해도 다른
  슬라이스에 영향 없음. 중단 시 이 계약 상태를 `abandoned`로 표시.

## Progress Log

- 2026-07-13: /brainstorm 진행. 사용자가 GSPT1→IKZF→CK1α→VAV1 개발 순서 결정을 확인
  (AskUserQuestion), 이를 별도 슬라이스(chronobridge)로 분리하기로 결정. 계약 범위를
  Phase A(일반 apo-holo benchmark)로 한정, 기존 aigen-fold-core 자산 재사용 안 함, 공개
  MD 데이터 미보유, PASS 기준은 랜덤/베이스라인 대비 통계적 유의성으로 확정. 승인 대기.
- 2026-07-13: 사용자 승인("승인"). status: approved. 다음 단계 /write-plan.
- 2026-07-13: /write-plan → /execute-plan 16-task 실행 완료 (commits c44ff3ed..8d6ed075,
  188e3a4c, d5a56666). ATLAS 1k5n_A(276 Cα, 1001 frame) + 1r6w_A 이종단백질 스플라이스 FP
  주입(150 frames)으로 벤치마크 구축. ChronoBridge(diffusion-map pseudotime, RMSD-after-
  Kabsch 거리행렬) + FP 검출기(PCA residual + kNN, pairwise-distance feature) 구현.
  **결과: PASS — 7/7 지표 전부 부트스트랩 CI가 0을 배제**(FP-removal AUC Δ+0.503
  CI[+0.449,+0.554], Kendall τ Δ+0.702 CI[+0.654,+0.749], 나머지 5개 지표도 동일).
  Adversarial verification(재시드 seed=999 재현 + null-calibration 이중 무작위 베이스라인
  비교) CONFIRMED — 결과가 특정 시드의 우연이나 부트스트랩 결함이 아님을 확인.
  전체 검증 과정에서 코디네이터가 4개 지표를 원본 CSV에서 독립 재계산(정확히 일치),
  Kabsch RMSD 폐형해를 합성 데이터로 1e-15 정밀도까지 재검증. 상세: results.md.
  **권고: Phase B(GSPT1)로 진행**, 단 Phase A의 이종단백질 FP 주입은 실제 CRBN-ternary의
  "동일 표적·오답 포즈" 실패모드보다 쉬운 케이스일 수 있다는 caveat를 Phase B 계약에 반영할 것.
  .agent/status/chronobridge.md 최초 생성 + handoff + CURRENT.md 인덱스 갱신 완료.
  status: done.
