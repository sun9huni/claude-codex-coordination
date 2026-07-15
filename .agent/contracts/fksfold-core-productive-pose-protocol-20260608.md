# fksfold-core-productive-pose-protocol — M-RELATIVITY **Phase 0** (전처리·진단)

- **Status**: done (Phase 0 완료 2026-06-09 — 판정 CATASTROPHIC)
- **Notes**: Phase 0 lever-arm 진단 = 🔴 CATASTROPHIC. distal lysine(레버암 30–100Å) 변위 41Å@50°/81Å@112°
  ≫ tolerance 15Å; SH3 lysine(레버암 12–18Å)도 best 오차 112°에서 21Å>15Å. **병목 = SH3 docking 정확도**
  (committor/k_ubq 아님). committor(Phase 1, 다른 agent)는 docking ~<30° 조인 뒤, distal 제외·SH3만 재고.
  결과 `analysis/productive_pose/PHASE0_RESULTS.md`. plan 동일 slug.
- **Slice**: fksfold-core
- **Approval**: requested 2026-06-08 · approved by: user (2026-06-08 "진행"; 2026-06-09 Phase 0-only 확정)
- **Scope class**: **zero-to-low-GPU 진단 only.** (생성·committor·양자 없음.)
- **Triggers matched**: 외부 구조 다운로드(RCSB/AlphaFold = 네트워크 fetch) + /mnt scratch 쓰기 + 4+ files.
  **SLURM 없음**(Phase 0). production ranking/steering 미변경. FragMap npz 재freeze 없음.
- **🚧 경계 (다른 agent):** 양자·committor·TPT·W₃·QPE 등 **M-RELATIVITY Phase 1+ 전부는 다른 agent 소관 →
  건드리지 않음.** 이 계약은 그 상류 전처리(overlay + lever-arm 진단 + 보정)만 산출해 Phase 1에 *넘긴다*.

## Purpose

M-RELATIVITY(committor 기반 분해-운명 계산, **다른 agent**)의 **Phase 0 전처리**다. 목적: ① full-length
VAV1 + CRL4A–RBX1–E2\~Ub을 기존 9NFR pose에 **integrative overlay**로 복원하고, ② **9NFR/mrt23227 결정구조를
in-distribution 보정 앵커**로 쓰고, ③ **lever-arm 민감도**(SH3 docking 불확실성이 lysine→E2 productive-
geometry 신호를 삼키나)를 zero-GPU로 측정해, **committor(Phase 1)에 compute를 쓸 가치가 있는지 가른다.**

> 정지 k_ubq(거리×각×SASA)는 **committor의 coarse proxy(floor)로만** 사용 — 답이 아님. 진짜 운명 계산
> (committor q, 거리자 g=D⁻¹, kinetics)은 Phase 1+(다른 agent). 우리는 그 전처리·진단까지.

## 화합물 정정 (중요)

- **9NFR 결정 리간드 = mrt23227 = CCD `A1BYX`** (실제 crystal 활성 degrader) → **보정 앵커**.
- **MRT6160 = 별개 analog** — 기존 생성 pose(`9nfr_mrt6160_vav1_14_19_*`, docking 102–151° 분포)는
  **docking-불확실성 sample**(lever-arm 측정용)으로 사용. 절대 좌표 정답은 mrt23227 crystal.

## Current State (입력)

- **보정 앵커**: `best_structures/9NFR_reference.cif`(DDB1+CRBN+VAV1-SH3, 리간드 A1BYX). 보유.
- **docking sample**: 기존 MRT6160 multi-seed pose(102–151° 분포). 보유.
- **확보 필요(다운로드)**: full-length VAV1 = AlphaFold **AF-P15498-F1**; CRL core = PDB **3LRQ**(CUL4A–
  RBX1–DDB1); E2\~Ub frame(NEDD8-activated CRL–E2\~Ub) — RCSB 접속 가능 확인됨(6TTU→200), AF DB 다운로드 가능.
- **VAV1 SH3 lysine 5개**(K788/804/810/814/815)는 SH3 위 → docking으로 위치 결정. full-length는 distal
  lysine 추가(AF 모델, inter-domain 신뢰도 caveat).

## Constraints

- **HARD: 양자/committor/Phase 1+ 미접촉**(다른 agent). overlap 발견 시 멈추고 보고.
- **HARD: pre-registration** — overlay 정합 기준·lever-arm 측정 정의·tractable/catastrophic 임계를 측정 전 동결.
- static k_ubq는 **proxy floor로 명시 라벨**(productive 구조 "답"으로 제시 금지).
- 외부 다운로드는 /mnt scratch 또는 analysis/refs로, 출처·버전 기록.

## Non-Goals

- **committor / TPT / 양자(R·Q·W₃·QPE) = 다른 agent(M-RELATIVITY Phase 1+). 안 함.**
- 방향-bias 2차 생성(GPU) · surface 산출물 · active/inactive 통계 검증 = **Phase 1+ / 후속 별건**.
- DC50 활성 순위 예측. production baseline/steering 변경. PROTAC.

## Done When

1. **Overlay 조립 재현**: full-length VAV1(AF-P15498)→pose SH3, CRL4A–RBX1–E2\~Ub→pose CRBN(+DDB1),
   9NFR/mrt23227 앵커 정합 RMSD < 2Å. 스크립트 + 완성 assembly.
2. **lever-arm 민감도 수치 + 판정**: SH3 docking Δθ당 lysine→E2 기하(또는 proxy) 변화량(증폭계수) →
   **tractable / catastrophic** 판정(임계 동결). → tractable=Phase 1 넘김 / catastrophic=docking이 진짜 병목.
3. **9NFR 보정 NULL band**: mrt23227 crystal pose에서 proxy가 정상 거동(in-distribution 기준선).
4. (proxy) static k_ubq를 overlay에 적용 — **coarse floor로 라벨**, Phase 1 입력 후보.

## Verification

- overlay: `python complete_structure.py` → 완성 PDB + 정합 RMSD < 2Å 로그
- lever-arm: `python lever_arm_sensitivity.py` → Δθ vs lysine 변위 곡선 + 증폭계수 + 판정 출력
- 보정: 9NFR crystal에 동일 파이프라인 → NULL band 수치

## Risks

- **lever-arm catastrophic 가능성 큼**: 112° docking 오차 × full-length 지렛대 = distal lysine 수십 Å.
  → 그게 결론이어도 가치 있음(committor에 돈 쓰기 전 "docking부터" 판정 = compute 절약).
- **full-length VAV1 AF inter-domain 불확실**: distal lysine 위치 신뢰도 낮음 → lever-arm에 PAE 가중/도메인
  신뢰구간 반영, 또는 SH3 lysine만으로 lower-bound.
- regression risk: 없음(다운로드+로컬 분석, production·다른 agent 미접촉).

## Rollback

- analysis/refs + scratch 디렉토리 삭제로 끝. production·엔진·다른 agent 산출물 미변경.

## Progress Log (압축)

- 2026-06-08: brainstorm→write-plan→execute-plan. 초기 = orientation×기능지표 productive-pose.
- 2026-06-09 재정렬 연쇄: active/inactive 게이트 → sharpness 게이트 → **committor 프레임 인식(사용자
  M-RELATIVITY 제안)** → 정지 k_ubq는 position-패러다임 proxy로 강등. 사용자 결정: **Phase 0만 진행,
  양자/committor는 다른 agent.** 화합물 정정(9NFR=mrt23227/A1BYX, MRT6160은 별개). plan/pre-reg Phase 0 재작성.
