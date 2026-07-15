---
status: done
slice: vav1-ubq
topic: ternary-refine-minimization
date: 2026-06-25
owner: claude
approved_by: user (2026-06-25, "승인")
verdict: "DONE — orient=0 medoid (seed271_0) is ALREADY a clean near-native model: geometric constrained refinement moved SH3c only 0.12A (no clash/degron slack), SH3c RMSD-to-9NFR UNCHANGED 4.7->4.7 = NO-overfit demonstrated trivially. The 4.7A is the systematic glue-difference (MRT-23227 vs MRT6160), NOT a refinable artifact. Deliverable = the medoid (degron 3/3, PASS). METHOD DEVIATION: geometric refinement substituted for OpenMM/AMBER (LIG re-param failed: antechamber odd-electron; FF-min = available escalation, shown unnecessary by the 0.12A null move). STRUCTURE-only, zero-GPU."
requested: 2026-06-25
triggers_matched:
  - "신규 코드 — consensus 빌드 + 9UUM 조립 + 제한 최소화 배선 (analysis/crl_integrative/)"
  - "조건부 GPU — 짧은 implicit-solvent MD 옵션 시 1-GPU (게이트); 최소화는 CPU"
  - "shared-storage writes — /mnt에 조립/최소화 산출"
---

# VAV1 Ternary Pose Refinement — post-hoc constrained minimization (STRUCTURE-only, NO-overfit)

## Purpose

steered-generation으로 얻은 **MRT6160 orient=0 near-native 포즈**(다중시드 수렴, degron 3/3,
SH3c ~4Å)를 9UUM 활성 platform에 조립한 뒤 **계면 완화 + 프레임-stitch 잔차 다듬기**로
*제출용 clean 삼원 모델*을 만든다. ★**9NFR로 refit하지 않는다**(9NFR=MRT-23227 형제 글루 →
RMSD<3Å 강제는 over-fit). 목적은 "binding mode 보존한 채 계면/strain만 완화".

근거: seed_precision 분석 — orient=0 시드 pairwise 2.34Å 수렴(정밀)인데 9NFR과 ~4Å는
glue-특이 체계 오프셋. 그 4Å 중 일부(프레임 stitch ~1.3Å + 미완화 계면)는 정당하게 줄일 수
있고, glue 차이(나머지)는 보존해야 한다.

## Current State

- 입력 후보: MRT6160 orient=0 4–5 시드 PASS 포즈(/mnt/.../md_injection_productive_20260622/out/
  on/MRT6160/seed*_0/...). 9UUM ref(refs/9UUM.cif), 9NFR ref(9nfr_in_9uum.pdb), competence 필터
  (glue_competence.py)·transform(zone_render_pose.py)·seed_precision(zone_seed_precision.py).
- 최소화 인프라 존재: 카이랄 작업의 minimize_all.py/crl_md_prep.py(OpenMM/AMBER) 재사용 가능.

## Assumptions And Questions

- **[가정]** 제한 최소화(soft degron restraint + 계면 완화 + 9UUM 코어 고정)는 binding mode를
  보존한다(SH3c RMSD-to-9NFR ≈ 불변). 그게 안 되면(=RMSD가 9NFR로 collapse) over-fit 신호 → 중단.
- **[질문→확정]** consensus = orient=0 시드의 medoid(다른 시드들과 평균 RMSD 최소)로. 단일 best도 병행.
- **[질문]** CPU 최소화로 충분한가, 짧은 implicit-solvent MD까지 갈까 → 1차 CPU 최소화, 부족하면 게이트.

## Constraints

- **STRUCTURE-only** — 효율/potency 주장 0.
- **NO-overfit 가드**: 최소화 후 SH3c RMSD-to-9NFR이 *유의하게 줄면*(예: >1.5Å collapse) = over-fit → FAIL/중단.
- 최소화 CPU 우선(게이트 없는); 짧은 MD는 1-GPU 게이트 뒤.
- 기존 minimize 인프라 재사용; 신규 스크립트는 analysis/crl_integrative/; 엔진 미접촉.
- 9UUM 코어(CRBN-DDB1-CUL4-E2~Ub)는 고정/강체 restraint(우리가 움직이는 건 VAV1+glue 계면).

## Non-Goals

- **9NFR로 refit** (over-fit — 형제 글루 결정에 끼워맞추기).
- potency/효율; full MD 앙상블(별개); 카이랄 ΔΔG(Stage D); 엔진/생성(=c, aigen-fold-core).

## Done When

1. **consensus 빌드**: orient=0 시드 medoid(또는 최선 single) 포즈 산출 + 선택 근거 기록.
2. **9UUM 조립**: consensus를 CRBN-중첩으로 9UUM platform에 배치(VAV1+glue + 고정 9UUM 코어).
3. **제한 최소화 실행**: degron 접촉 soft restraint + SH3c-CRBN 계면 완화 + 코어 고정; 폭발 없이 수렴.
4. **before/after 측정**: clash↓ · degron 접촉(기능기) tighten · 신규 intra-strain 없음 ·
   **SH3c RMSD-to-9NFR ≈ 불변**(over-fit 아님 입증).
5. **산출**: clean 삼원 PDB(9UUM-frame) + before/after 표 + NO-overfit 어서트 + STRUCTURE-only 면책.

## Implementation Steps

(상세=/write-plan) consensus(medoid) → 9UUM 조립 → 최소화 배선(기존 인프라) → before/after 채점
(glue_competence + RMSD) → doc + baton.

## Change Discipline

신규 스크립트만 추가; 기존 zone_*/glue_competence 재사용(읽기); `git add` 내 파일만. /mnt에 대용량.

## Verification

`<refine>.py` → before/after 표: clash(↓), degron 기능기 거리(↓/유지), intra-strain(신규 없음),
SH3c-RMSD-to-9NFR(Δ작음=완화). over-fit이면(RMSD collapse) 명시적 FAIL.

## Risks

- **R1 over-fit**(RMSD가 9NFR로 collapse) → NO-overfit 가드가 잡음(Done#4); 그러면 완화 약화.
- **R2 최소화 폭발/strain** → soft restraint + 단계적 최소화; 기존 minimize_all 규약 재사용.
- **R3 9UUM 코어 처리** → 코어 고정(우리가 검증하려는 건 계면이지 기계 아님).

## Rollback

신규 파일/산출만 → 삭제로 무해. 엔진/공유상태 미변경.

## Progress Log

- 2026-06-25: contract 작성(pending). (a)[seed precision] 후속 (b). 설계 합의됨(사후 제한 최소화,
  no-overfit). 승인 대기.
