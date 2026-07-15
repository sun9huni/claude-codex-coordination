---
status: done
slice: fragmap
topic: multivariate-potency-test
date: 2026-05-29
owner: claude
approved_by: user (2026-05-29, "진행" after retrospective+directions panel → Step 0 convergent zero-compute test)
result: "KILL (both cohorts). Multivariate learned model over 56 non-circular pose/FragMap features does NOT recover within-class potency: active-cohort grouped-CV Spearman -0.233, permutation p=0.484 (= chance), floor |rho|>=0.45 not cleared; full-cohort -0.204, p=0.173. Null upgraded univariate -> ENSEMBLE level. NEW FINDING: descriptors-only (MW/logP/HBD/HBA/rotbond) model BEATS all 56 pose features (+0.366 active / +0.261 full vs pose-feature models going negative/anti-generalizing) -> the platform's 'weak DC50 rank signal' is largely physicochemistry, NOT ternary recognition. Bound: no within-class effect > |rho|~0.41 detectable at n=56. Scope: kills existing static-pose feature set; cooperativity Delta (RunA-RunB) + lysine geometry NOT included = Step 1. Report: analysis/multivariate_potency_test_20260529/RESULTS.md. Decisions: charter A (placement=product) confirmed; do NOT justify job 5809 Stage 2 as potency ranker; repurpose its Stage 3/4 decomp for Step 1 cooperativity contrast."
decisions:
  - 성격= PRE-REGISTERED diagnostic (NOT exploratory). 점수 보기 전에 spec/threshold/leakage-guard/STOP 규칙을 본 contract에 동결. 이후 threshold 변경 금지.
  - 검증 동기= "within-class potency ranking null"은 지금까지 univariate(36 single-feature)로만 증명됨. 4개 method가 같은 static pose의 functional이라 사실상 ≤2 독립 관찰. 한 번도 안 한 것 = features의 학습된 다변량 결합. feature_matrix.csv(139×59)가 디스크에 있음 → 신규 compute 0.
  - PROVE/KILL (사전 동결):
    - PROVE = scaffold-grouped-CV Spearman(pred,logDC50)가 (full ρ≥0.30 OR active ρ≥0.45) AND 1000× label-permutation 95%ile band 초과 AND descriptors-only(MW/logP/HBD/HBA/rotbond) baseline이 못 따라옴(physicochemistry confound 배제). → univariate가 놓친 학습 신호 회복, B/E direction 살아있음, escalation 정당화.
    - KILL = grouped-CV ρ가 permutation band과 구분 불가. → within-class null이 ENSEMBLE level로 격상(univariate보다 강함). static ranker 추적 중단, 제품 charter A(placement=제품) 확정, 16-A100 Stage 2를 potency 용도로 쓸 근거 소멸.
  - leakage-guard (사전 동결): (1) 순환 feature 격리 = lig_crbn_f1, lig_vav1_f1, iface_f1 (9NFR contact로 채점 → steered pocket 내부, 포함 시 가짜 신호). (2) Murcko-scaffold GroupKFold (같은 scaffold가 train/eval 동시 출현 금지). (3) DC50_nM/active를 predictor로 쓰지 않음. 이 3개를 점수 보기 전에 강제, 안 하면 프로젝트 기존 측정 결함 재생산.
  - cohort (사전 동결): (full) n=139 logDC50 회귀 = 전체 DC50 ordering 신호. (active) active==1 n=56, DC50 1.99–29.29 nM = TRUE within-class 질문(결정 관련). 둘 다 보고, active가 결정 driver.
  - 보고 규칙 (사전 동결): 결과는 검출한계 bound로 기술("|ρ|=X 이하 효과 검출 불가 at this n"), 절대 bare "null"/"signal" 금지. no-GT 규칙: DC50 rank/active label에만 채점, 9NFR-distribution-shift로 채점 금지. per-compound metric(Spearman/Pearson), top-K 금지.
  - 결정 인자 ceiling 명시: permeability/expression/hook/kinetics는 구조 밖 → active-cohort null도 부분적으로 예상됨. KILL 결과는 "도구 실패"가 아니라 determinant-partition(C/D항 지배)으로 기술.
---

# Multivariate within-class potency test (Step 0) — leakage-guarded ranker on feature_matrix.csv

## Purpose

플랫폼 중심 음성 결론("within-class potency ranking은 현재 도구 해상도 이하, 4-way null")은
**univariate regime에서만 증명**됐다 (dc50_overfit_scan = 36개 단일-feature Spearman/Pearson,
0/36 after FDR). 모든 feature에 대한 univariate null이 그 **학습된 결합**의 null을 함의하지
않는다 — cooperativity/potency는 E3-face·target-face occupancy·pose 기하의 비선형 상호작용일
수 있고 어떤 단일 컬럼도 그걸 표현 못 한다. 본 단계는 디스크에 이미 있는
feature_matrix.csv(139 cpd × 59 engineered feature + logDC50 + active label)에 **누수 차단
다변량 모델**을 적합해, univariate가 놓친 신호를 (a) 회복하거나 (b) ensemble level에서 null을
확정(univariate보다 강한, 출판 가능한 결과)한다. 신규 generation/MD compute 0 (CPU 수 분).
"diagnose before scaling compute"의 정의상 in-flight MMGBSA Stage 2(16 A100)와 FEP 앞에 와야 함.

## Current State

- Input (read-only, shared): `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/analysis/fragmap_spectral_discriminator/outputs/feature_matrix.csv`
  - 139 rows × 63 cols. cols = compound, DC50_nM, logDC50, active, + 59 feature.
  - active==1: n=56 (DC50 1.99–29.29 nM). active==0: n=83 (33.95–10000 nM, 일부 10000 ceiling).
  - 순환 feature 3개 확인: lig_crbn_f1, lig_vav1_f1, iface_f1 → 격리 대상.
- SMILES: per-compound YAML `…shared/examples/normtest_msa_patched_vav1_14_19/VAV1_*.yaml`의 `smiles:` 필드 (normtest_metadata.csv엔 SMILES 없음).
- 환경: rdkit 2025.09.1, sklearn 1.7.2, pandas 2.3.3 (ubuntu python3) 확인됨.
- 선행 detection limit (dc50_overfit_scan, n=84 full/35 active): |ρ|≥0.30 / 0.46.

## Assumptions And Questions

- 가정: feature_matrix의 occ_*/raw_* feature는 비순환(FragMap occupancy/confidence/pose 기하).
  순환은 명시된 3개(f1류)뿐. → 적합 후 retained feature 목록 전체를 report에 기록(감사용).
- open: full-cohort logDC50 회귀는 active/inactive 분리와 within-class ordering을 혼재 →
  active-only cohort가 진짜 within-class 질문. 둘 다 돌리되 active를 결정 driver로.
- tradeoff: n=56 active는 |ρ|≥~0.45만 검출. 약신호는 놓칠 수 있음 → 결과를 bound로 기술.

## Constraints

- allowed: 새 분석 스크립트 + 산출물(CSV/MD/PNG)을 repo `analysis/multivariate_potency_test_20260529/`에 작성·git-track. shared feature_matrix.csv는 read-only(스냅샷 복사만).
- forbidden: feature_matrix.csv 원본 수정; vav1_ensemble_rank.py/oracle_ranking.yaml 등 production ranking 변경(본 단계는 진단, ranking-default 미변경); SLURM/GPU 사용; threshold 사후 변경.
- external: no-GT→activity-validator 규칙; generation verdict=per-compound(top-K 금지).

## Non-Goals

- production ranking 교체 (이건 진단; 양성이면 별도 ranking contract).
- 신규 MD/FEP/generation (전부 후속 gate).
- 9NFR-distribution-shift를 정확도로 해석 (prior-shift 측정일 뿐).

## Done When

- full + active 두 cohort에 대해 grouped-CV Spearman(pred,logDC50) ± bootstrap CI, vs 1000× label-permutation 95%ile band 보고.
- descriptors-only(MW/logP/HBD/HBA/rotbond) baseline + MW/logP partial 보고 (physicochemistry confound 분리).
- n_scaffolds vs n_compounds, retained/quarantined feature 목록, permutation_importance 보고.
- PROVE/KILL 판정을 사전등록 threshold에 대해 기술 (bound 형태).
- 스크립트 + frozen feature_matrix 스냅샷 + permutation null CSV를 repo에 git-track.

## Implementation Steps

1. SMILES 추출 + Murcko scaffold 계산 (139 cpd), n_scaffolds 보고. GroupKFold group key 확정.
   verify: scaffold table 행수 == 139, n_scaffolds 출력
2. predictor matrix 구성: 59 feature에서 순환 3개 격리 → 56 retained. DC50_nM/active 제외.
   verify: retained feature 수 == 56, 격리 목록 == [lig_crbn_f1,lig_vav1_f1,iface_f1]
3. 모델 적합 (ElasticNetCV primary + GradientBoosting robustness), nested scaffold-GroupKFold (outer=성능, inner=hyperparam). full + active cohort.
   verify: 각 fold에서 train/eval scaffold 교집합 == ∅
4. 1000× label-permutation null (동일 grouped-CV scheme) → 95%ile band. descriptors-only baseline + MW/logP partial.
   verify: permutation 분포 중심≈0, band 출력
5. report 작성(bound 형태), PROVE/KILL 판정, git-track (스크립트+스냅샷+null CSV).
   verify: `python -m compileall` 통과; report에 사전등록 threshold 명시

## Verification

- `python -m compileall analysis/multivariate_potency_test_20260529/`
- 결과는 검출한계 bound로; threshold는 본 contract 동결값 사용 (사후 변경 금지).
