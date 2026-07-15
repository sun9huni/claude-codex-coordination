---
status: done
slice: fksfold-core
topic: ood-rescue-confirm
date: 2026-06-02
owner: claude
approved_by: user (2026-06-02, "진행" via /brainstorm → 확증-먼저 + 재분석+seed심화+OOD확장 채택)
parent_lane: T2/D3 held-out placement (Stage B = KILL at pooled bar; this re-opens the OOD-regime sub-question)
prior_artifacts:
  - analysis/heldout_placement_20260601/STAGEB_RESULTS.md (Stage B verdict + median matrix)
  - analysis/heldout_placement_20260601/stageB_dockq_results.tsv (36-cell per-seed DockQ)
triggers_matched:
  - "SLURM 신규 제출 (seed 심화 + 신규 OOD 타깃 생성)"
  - "4개 파일 이상 (신규 held-out CIF/GT/YAML/config + 확장 jobs TSV + 재분석/특성화 스크립트 + report)"
  - "local↔shared 동시 (신규 타깃 staging + 생성 출력 scratch)"
result: "DONE = CONFIRM (2026-06-02, FKSFold 6283739, 120/120 OOD cells). regime-stratified(baseline<0.23): prior-works=9NYR/9NGT/9W2F(0.733), OOD=9NFQ/9OS2/9DWW/9DUR. OOD steering-rescue REAL+재현+특이: ★9DWW(PDE6D) baseline 0.006→nativeAB 0.683(8/8 acceptable, iRMSD~1Å, GT-vs-GT=1.0 검증), wrongAB 0.047(붕괴)=강한 특이적 구제; 9OS2 partial(2/8); 9NFQ/9DUR(PROTAC) none. OOD nativeAB accept 10/32 vs wrongAB 0/32(wrongAB는 절대 구제 안 함=generic-artifact 배제). 동결 (i)재현성[≥2타깃] (ii)특이성 (iii)비-fluke 전부 충족 → CONFIRM. Stage-B pooled-median KILL 교정(regime 혼합 + 9DWW 미포함이 신호 가림). target-의존(9DWW 강/9OS2 부분/9NFQ·9DUR 무) — why가 follow-on 질문. 보고서 ood_rescue_20260602/OOD_RESCUE_RESULTS.md. → steering-strengthening follow-on 정당화."
decisions:
  - 성격= PRE-REGISTERED 확증·특성화 연구. 기존 36셀 재분석(zero-compute) + seed 심화 + 신규 OOD 타깃. 목적= mechanism 강화 *전에* OOD-rescue 신호가 진짜/재현/특이적/일반적인지 판정 → strengthen follow-on의 go/no-go.
  - 배경= Stage B(STAGEB_RESULTS.md)는 pooled-median PROVE/KILL로 KILL이었으나, 그 bar가 regime을 섞어 OOD 신호를 가림. 재분석: prior-works(9NGT 0.73/9NYR 0.51 baseline)에선 steering이 간섭, **prior-fails(9NFQ base 0.008/9OS2 base 0.005)에선 nativeAB가 baseline 5–7× 초과 + 9OS2 seed16은 0.005→0.392(acceptable) 실제 구제, wrongAB는 어떤 seed도 거기 못 감(특이적)**. 단 1 real rescue/6 OOD seed = hint, not proof.
  - **regime 분류 (동결, 비순환)**: 타깃은 median **baseline DockQ < 0.23**이면 OOD/prior-fails로 분류. baseline=steering 0이라 분류가 검증 대상(steering)과 독립 → 비순환. 분류는 측정된 baseline에 사후 적용하되 규칙은 사전 동결.
  - **panel (동결)**: 기존 OOD 2개(9NFQ, 9NGT는 prior-works라 제외 — 9NFQ/9OS2가 OOD) + 신규 held-out CRBN-ternary 타깃 추가(recon ~15 후보 중 prior-fails 기대군). 전 타깃 3-condition(nativeAB/wrongAB/baseline) × seed 심화(3→8). 신규 타깃은 Stage-A 레시피(extract_heldout_gt + 3-subsystem 비활성 config + per-target CRBN 앵커 재유도)로 prep.
  - **CONFIRM (동결, → strengthen follow-on 정당)= 전부**: (i) **재현성**: OOD regime에서 nativeAB가 acceptable(DockQ≥0.23)에 ≥1 seed 도달하는 타깃이 ≥2개; (ii) **특이성**: OOD regime에서 nativeAB acceptable-rate > wrongAB acceptable-rate AND median nativeAB > median baseline; (iii) **비-fluke**: 위가 단일 타깃/단일 seed가 아니라 ≥2 타깃 또는 ≥2 seed에서 성립. → OOD-rescue 실재 확증 → mechanism 강화 follow-on contract 정당.
  - **NOT-CONFIRM (동결)**= 위 미달(9OS2 0.39가 재현 안 됨 / wrongAB와 구분 안 됨 / 단일 fluke) → OOD-rescue는 비재현 hint로 기록, strengthen 미착수. (활성 lane처럼 정직한 음성.)
  - leakage/guard (동결)= regime 분류는 baseline(비순환)로; CONFIRM threshold는 신규 생성 점수 보기 전 동결; pooled-median 금지(regime-stratified만); wrongAB=특이성 control; power=여전히 modest → bound로 보고. proxy-audit: DockQ=직접 구조지표.
  - 한계 (동결)= (a) oracle-only; (b) 상대적 비순환(ligand-bridge 결합, AMENDMENT 2); (c) seed/타깃 여전히 저power→bound; (d) acceptable 도달이 곧 활성/실용 아님(placement만); (e) 신규 타깃 참조 해상도 caveat.
---

# OOD-regime steering-rescue: confirm + characterize (pre-strengthen gate)

## Purpose

Stage B의 pooled-median verdict(KILL)는 regime을 섞어, steering이 *애초에 의도된* 영역
— 모델 prior가 실패하는 OOD/MGD-유사 ternary — 에서 보인 약하지만 특이적인 구제 신호를
가렸다. 이 contract는 mechanism을 손대기 *전에*, regime-stratified로 그 OOD-rescue가
**진짜·재현·특이적·일반적**인지 사전등록 threshold로 판정한다. CONFIRM이면 steering 강화
follow-on이 정당화되고, NOT-CONFIRM이면 비재현 hint로 정직하게 종료한다.

## Current State

- Stage B 36셀 per-seed DockQ: `analysis/heldout_placement_20260601/stageB_dockq_results.tsv`; verdict `STAGEB_RESULTS.md`.
- 재현된 OOD 신호(재분석 대상): 9NFQ base 0.008→native 0.040(5×, 여전히 incorrect);
  9OS2 base 0.005→native 0.036 median이나 **seed16 0.392(acceptable, iRMSD 2.9Å)**, wrongAB는 0.04 평탄(구제 0).
- 하네스 작동(수정 완료): per-task UUID GPU selector, /mnt/data staging, DockQ scorer({native:model}), qos=batch.
- 재사용 자산: `score_heldout_dockq.py`, `run_stageB_scoring.py`, `stage_heldout_stageB.sh`, `extract_heldout_gt.py`, `verify_heldout_anchor.py`, `fix_pocket_numbering.py`; recon `.agent/scratch/d3_heldout_recon_20260601.md`(신규 OOD 후보).

## Constraints

- allowed: 기존 데이터 regime-stratified 재분석; 신규 held-out CIF/GT/YAML/config prep(Stage-A 레시피); seed 심화 + 신규 타깃 생성(SLURM); 재분석·특성화 스크립트·report git-track; 출력은 scratch OUT_BASE.
- forbidden: **steering 메커니즘/수식 변경**(그건 강화 follow-on); production ranking 변경; pooled-median 판정(regime-stratified 강제); CONFIRM threshold 사후 변경; **승인 없는 SLURM 제출**.
- external: regime 분류는 baseline(비순환); 결과는 bound; DockQ 직접지표(proxy-audit 통과).

## Out of scope

- steering 메커니즘 강화/수정 (CONFIRM 시 별도 follow-on contract).
- prior-works 타깃(9NGT/9NYR)의 steering 간섭 추적(별개 현상, 이 질문 아님).
- 활성/DC50, blind-mode, production 파이프라인.

## Success criteria

1. **재분석(zero-compute) 완료**: 기존 36셀을 regime(baseline<0.23=OOD)으로 층화 → OOD subset의 native/base/wrong 통계 + 특이성(native vs wrong acceptable-rate) report.
2. **확장 생성**: seed 심화(3→8) on 9NFQ/9OS2 + 신규 OOD 후보 타깃(≥2) 3-condition × 8-seed, DockQ 채점.
3. **사전등록 CONFIRM/NOT-CONFIRM 판정**(위 frozen threshold에 bound로): (i)재현성 (ii)특이성 (iii)비-fluke.
4. 검증 커맨드(예): `grep -qiE 'CONFIRM|NOT-CONFIRM' analysis/.../OOD_RESCUE_RESULTS.md`; regime-stratified 표(OOD subset의 per-target native/base/wrong acceptable-rate); proxy-audit 통과.

## Resource budget

- zero-compute 재분석 + Stage-A prep(신규 타깃). 생성: (2 기존 + ~2-4 신규 OOD) × 3 condition × 8 seed ≈ 수십 GPU-hr (per-task UUID GPU fix로 충돌 없음, qos=batch %4-8). 사용자 appetite 확인 필요(데이터 확보까지 OK 전례).

## Approval

- requested: 2026-06-02
- approved by: pending

## Rollback plan

- 진단 전용 — production/steering 미접촉. 생성 출력 scratch → scancel/폐기. 코드·report git revert. 신규 prep 파일 rm.

## Done When

- 재분석 + 확장 생성 + DockQ 채점 완료, regime-stratified CONFIRM/NOT-CONFIRM 사전등록 threshold에 판정.
- CONFIRM → steering-strengthen follow-on /brainstorm. NOT-CONFIRM → OOD-rescue 비재현 기록, lane 종료.

## Verification

- OOD_RESCUE_RESULTS.md: regime 분류표(타깃별 baseline + OOD/prior-works) + OOD subset의 native/base/wrong DockQ(per-seed + acceptable-rate) + (i)(ii)(iii) 각 numbers + 한 줄 verdict + 한계.
- proxy-audit 체크리스트; power bound 명시.

## Progress Log

- 2026-06-02: spec 초안 (brainstorm; Stage B pooled-median이 OOD 신호 가린 점 사용자 지적 → regime-stratified 확증으로 재조준). 스코프 fork: 확증-먼저(권고 채택) + 재분석+seed심화+OOD타깃확장(채택). 승인 대기.
