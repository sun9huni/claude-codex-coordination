---
status: done
slice: chronobridge
topic: gspt1-leave-one-out
date: 2026-07-13
owner: claude
approved_by: sunghoon.kim (2026-07-13, "진행")
requested: 2026-07-13
cross_slice: []
triggers_matched:
  - "4개 파일 이상 수정 (예상) — PDB 소싱/정리 스크립트 + 데이터 존재 확인 스크립트 + 디코이 생성 스크립트 +
     leave-one-out 평가 스크립트 + 결과 문서"
  - "SLURM/GPU 제출이 필요해질 수 있음 — 이번 계약 자체는 exploratory/zero-GPU로 시작하되, discovery
     단계에서 신규 MD가 필요하다고 판정되면 이 계약은 '필요성 문서화'까지만 완료하고 실제 제출은
     별도 계약+승인으로 넘긴다 (WORKFLOW.md §3, sbatch는 항상 별도 승인)."
---

# chronobridge — Phase B 1단계: GSPT1 leave-one-ternary-out (실험 결정구조 기반)

## Purpose

Phase A(일반 apo/holo MD 벤치마크, PASS·adversarially confirmed)에서 ChronoBridge(구조
앙상블 순서 복원)와 FP 검출기가 작동함을 확인했다. Phase B는 이를 실제 CRBN molecular-glue
표적(GSPT1, 서로 다른 글루로 얻은 정답 삼원복합체 결정구조가 여러 개 존재)에 적용해 일반화
여부를 검증하는 단계다. 이번 계약은 Phase B의 첫 서브태스크인 **leave-one-ternary-out**
(결정구조 하나를 숨기고 나머지 + 글루 정보로 그 basin을 복원할 수 있는지)만 범위로 한다.
leave-one-glue-out과 FP-injection 테스트는 이 결과를 보고 각각 후속 계약으로 스코핑한다
(사용자 확인, 2026-07-13).

## Current State

- 사용 가능한 정답 데이터: GSPT1-CRBN-DDB1 삼원복합체 결정구조 3개, 서로 다른 글루 —
  5HXB(CC-885), 6XK9(CC-90009), 9HNE(Compound-1). 아직 로컬에 다운로드되지 않음.
- Phase A의 ChronoBridge/FP 검출기는 "하나의 연속 MD 트라젝토리(앙상블)"를 입력으로
  가정한다(`aigen-fold-core` 자산 미재사용, 완전 신규 구현 — `.agent/scratch/chronobridge/phaseA/scripts/`).
  Phase B의 입력은 정지 결정구조 3장뿐이라, 이 방법이 바로 적용되지 않는다 — **이번 계약의
  첫 task는 이 간극을 어떻게 메울지(기존 GSPT1 MD 데이터가 이미 있는지) 확인하는 것**
  (사용자 확인: zero-GPU discovery 우선).
- 워크스페이스 내 참고 가능 단서: `.agent/contracts/aigen-fold-core-crbn-transfer-pilot-20260706.md`
  (GSPT1→VAV1 CRBN transfer pilot 스코핑, 실행 여부 불분명 — 이전 세션 기록에서 "결과 없음"으로
  플래그됨), `.agent/status/aigen-fold-core.md`의 "CRBN-MGD data-scout (deep-research)" 항목
  (IKZF1이 최선의 transfer target이라고 언급 — GSPT1 관련 기존 자산이 있는지 함께 확인 필요).

## Assumptions And Questions

- assumptions: PDB 5HXB/6XK9/9HNE는 공개적으로 즉시 다운로드 가능(RCSB, 등록 불필요).
- open questions:
  - 이 워크스페이스 어딘가에 이미 GSPT1 관련 MD 트라젝토리나 도킹 결과가 있는지 (task 1의
    discovery 대상). 있다면 zero-GPU로 재사용, 없다면 이번 계약은 "신규 MD 필요"를
    문서화하는 선에서 멈추고 후속 계약으로 넘긴다.
  - FP(가짜 포즈) 디코이 생성 방법의 정확한 절차: 사용자가 확정한 방향은 "글루×백서본 교차
    조합"(예: 6XK9의 글루를 5HXB의 단백질 backbone 컨포메이션에 배치)이다. CRBN 포켓
    정렬·글루 배치·clash 처리의 구체적 알고리즘은 Phase A의 Task 5(FP-injection 방법 확정)
    선례를 따라 실행 단계에서 확정하고 문서화한다.
  - leave-one-ternary-out의 "복원 성공" 판정 기준(예: 숨긴 구조와 예측/재구성 결과 간
    구조 유사도 임계값, 혹은 Phase A처럼 랜덤/베이스라인 대비 통계적 유의성)도 discovery
    결과(어떤 데이터를 실제로 쓸 수 있는지)에 따라 달라질 수 있어, 정확한 수치는 task 2
    이후 데이터를 보고 확정한다. 최소 원칙만 지금 못박는다: **절대 임계값이 아니라
    랜덤/naive 베이스라인 대비 통계적으로 유의미하게 우수해야 한다** (Phase A와 동일 원칙).
- tradeoffs: discovery에서 기존 데이터가 없다고 나오면, 이 계약의 실질 완료 범위가
  "PDB 소싱 + FP 디코이 설계 + GPU 필요성 문서화"로 축소된다. 이는 실패가 아니라
  진단 우선 원칙에 따른 정당한 결과다(먼저 컴퓨트 늘리지 않고 근거부터 확인).

## Constraints

- allowed change scope: `.agent/scratch/chronobridge/phaseB/` 신규 스크립트/데이터/결과물.
- forbidden change scope: Phase A 산출물(`.agent/scratch/chronobridge/phaseA/`) 수정 금지
  (완료·adversarially confirmed 상태 보존). 기존 슬라이스(aigen-fold-core 등) 코드 미수정.
  이번 계약 범위 내에서 SLURM/GPU 제출 없음 — discovery 결과 신규 MD가 필요하다고 나와도
  이번 계약에서 sbatch를 시도하지 않고, 필요성만 기록하고 별도 계약으로 넘긴다.
- external constraints: 없음(탐색적, 예산/마감 미지정 — Phase A와 동일 원칙 적용).

## Non-Goals

- leave-one-glue-out 테스트와 FP-injection 정식 평가는 범위 밖(후속 계약).
- IKZF family(Phase C), CK1α(Phase D), VAV1(Phase E)는 범위 밖.
- 신규 MD 시뮬레이션의 실제 SLURM 제출은 범위 밖 — 이번 계약은 필요성 판단까지만.
- aigen-fold-core의 기존 자산(trunk latent, 3-body hypergraph 등) 재사용 안 함(Phase A와
  동일 원칙 유지, 완전 신규 파이프라인).

## Done When

두 가지 분기 중 하나로 완료된다 (discovery 결과에 따라 결정):

**분기 A (기존 GSPT1 앙상블 데이터 발견 시)**:
- 3개 결정구조(5HXB/6XK9/9HNE) 다운로드 완료.
- 발견된 기존 데이터로 leave-one-ternary-out 파이프라인 구축: 결정구조 1개를 숨기고
  나머지 2개 + 글루 화학 정보로 그 basin을 복원 시도, 랜덤/naive 베이스라인 대비 통계적
  유의성(부트스트랩 CI) 확인.
- 양성 결과 시 adversarial verification(Phase A 선례: 재현성 재검증 등) 통과 후 "real"로 보고.
- FP 디코이(글루×백서본 교차 조합) 설계 및 최소 1개 구체 사례로 시연.
- 결과 문서 + 계약 done.

**분기 B (기존 데이터 없음 확인 시)**:
- discovery 결과를 명확히 문서화(어디를 확인했고 왜 없다고 결론 내렸는지).
- 3개 결정구조 다운로드 완료(다음 계약이 바로 쓸 수 있도록).
- FP 디코이(글루×백서본 교차 조합) 설계를 정지 구조 수준에서 구체화(MD 없이도 가능한 부분).
- 신규 MD가 왜/얼마나 필요한지(예상 시스템 수·GPU 규모) 문서화 — 다음 계약 초안의 입력이
  되도록.
- 결과 문서 + 계약 done(범위 축소를 명시하고 done으로 닫음 — 실패 아님).

## Implementation Steps

1. GSPT1 관련 기존 MD/도킹 데이터 discovery (zero-GPU): 워크스페이스 전체
   (`.agent/scratch/`, `analysis/`, `/mnt/data` 접근 가능 범위), 관련 계약/상태 파일
   (`aigen-fold-core-crbn-transfer-pilot-20260706.md` 등) 검색. verify: 발견/미발견을
   근거 파일 경로와 함께 문서화.
2. PDB 5HXB/6XK9/9HNE 다운로드(RCSB, 등록 불필요 확인 후). verify: 3개 구조 파일 확보 +
   기본 무결성 확인(체인 구성, GSPT1/CRBN/DDB1/글루 존재 확인).
3. Discovery 결과에 따라 분기:
   - 데이터 있음 → 분기 A 파이프라인 구축(구체 task는 발견된 데이터 형태에 따라 후속
     계획에서 세분화).
   - 데이터 없음 → FP 디코이 설계 + MD 필요성 문서화로 축소, verify: Done When 분기 B
     항목 충족.
4. 결과 문서 작성 + `.agent/status/chronobridge.md` 갱신(remaining_actions에 다음 단계
   반영) + 계약 done 전환.

## Resource budget

- 탐색적 진행, 고정 GPU/시간 예산 없음. Discovery + PDB fetch + FP 디코이 설계는 zero-GPU.
  신규 MD가 필요하다고 판정되면 그 규모(시스템 수 × 예상 ns × GPU-시간)를 추정만 하고,
  실제 제출은 이 계약 범위 밖(별도 승인 필요, WORKFLOW.md §3).

## Risks

- regression risk: 없음 — Phase A 산출물 미접촉.
- integration risk: 없음 — 독립 파이프라인.
- hidden dependency risk: discovery에서 기존 GSPT1 데이터를 "있다"고 잘못 판단(예: 다른
  타겟과 혼동)하면 분기 A로 잘못 진행할 위험 — task 1에서 발견한 데이터가 실제로 GSPT1
  삼원복합체(CRBN-DDB1-GSPT1 3자 복합체, 단순 GSPT1 단독 구조가 아님)인지 명시적으로
  확인한다.

## Rollback

- revert strategy: `.agent/scratch/chronobridge/phaseB/` 삭제. 공유 상태 변경 없음.
- containment strategy: discovery 단계에서 중단해도 Phase A 결과나 다른 슬라이스에 영향 없음.

## Progress Log

- 2026-07-13: /brainstorm 진행. Phase A 완료(PASS) 후 사용자가 Phase B 진행을 확인("진행").
  핵심 결정 3가지: (1) 앙상블 생성은 신규 MD 전에 기존 GSPT1 데이터 존재 여부를 먼저
  zero-GPU로 확인, (2) FP 디코이는 글루×백서본 교차 조합 방식, (3) 이번 계약 범위는
  leave-one-ternary-out만(leave-one-glue-out·FP-injection은 후속 계약). 승인 대기.
- 2026-07-13: 사용자 승인("진행"). status: approved. 다음 단계 /write-plan.
- 2026-07-13: /write-plan → /execute-plan 9-task 실행 완료 (commits 76f5d7f4..847451f5).
  **결과: BRANCH B** — GSPT1-CRBN-DDB1 삼원복합체 결정구조 3개(5HXB/CC-885, 6XK9/CC-90009,
  9HNE/Compound-1) 다운로드 완료(각각 2:2 heterohexamer, chain 표기법이 구조마다 다름 —
  후속 코드 작성 시 하드코딩 금지). Zero-GPU discovery 결과 기존 GSPT1 ternary MD/도킹
  앙상블은 워크스페이스 어디에도 없음을 확인(코디네이터가 mmgbsa/vav1-ubq 처리량 인용치
  등 핵심 수치를 원본 파일에서 독립 재확인). FP 디코이(글루×백서본 교차 조합, 5HXB↔6XK9
  상호 2건)는 CRBN 체인 Kabsch 정렬로 구축 — 둘 다 강체 수준 clash 있음(1.85Å/2.38Å,
  실제 MD 없이는 "진짜 불안정 basin"과 "단순 정렬 아티팩트" 구분 불가). leave-one-ternary-out
  자체는 앙상블 데이터 부재로 미실행 — 실패가 아니라 계약이 규정한 정당한 분기 B 완료.
  MD 필요성 산정: 3개 시스템(비대칭단위 2 copy 중 1개만, 결정학적 packing 중복이라 판단)
  × ~20-30ns production + ~1-2ns equilibration, ~30-80 GPU-시간(중심값 ~50, mmgbsa
  ~65ns/day/GPU·vav1-ubq 21.4-40.7ns/day 실측 처리량 근거로 산정). SLURM 제출 없음(계약
  범위 밖 유지). `.agent/status/chronobridge.md` 갱신(다음 결정: 후속 MD 생성 계약 승인
  여부, 이번엔 진짜 GPU/SLURM 승인 게이트 필요) + handoff + CURRENT.md 인덱스 갱신 완료.
  상세: phaseB/results.md. status: done.
