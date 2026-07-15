---
status: approved
slice: fragmap
topic: light-filter-recal
date: 2026-05-26
owner: claude
approved_by: user (2026-05-26, "approved" after Q1+Q2+Q3 brainstorm)
decisions:
  - Input data: Step 4 AB-139 batch ternary metrics CSV (vav1_ab_139batch_<TS>/ + paired vs norm143_full)
  - Baseline filter (Phase 4): `PASS = NOT (ipde>1.0 OR clash≥1 OR plddt<0.85 OR p_vav1_lig<0.55)` (99/139 pass, 29% drop)
  - Candidate new features: vav1_rigid_body_offset (Step 4 새 metric), F1@4Å (Step 3 핵심 discriminator), iface F1, target_min_dist
  - Tuning: 1D threshold grid search per feature + AND-combination 최대 4 features (no ML/GBM)
  - Target cohort size: **70 compounds** (mmgbsa Stage 2 capacity)
  - Validation metric: **AUC(active vs inactive, DC50 ≤ 30 nM cutoff) ≥ 0.65** on the 70-cohort
  - Comparison baseline: Phase 3 confidence AUC 0.426 (worse-than-random) → +0.22 absolute improvement required
  - Compute: zero-compute (Python script, ~10 min wall on local CPU)
---

# Light filter recalibration on AB outputs — mmgbsa Stage 2 cohort selector

## Purpose

Phase 4의 light filter (29% drop, top-10 70% precision)는 confidence + structural metrics만 사용해 within-class ranking에 한계가 있었다 (Phase 3 confidence AUC 0.426). Step 4가 끝나면 AB pattern으로 인해 **vav1_rigid_body_offset**이라는 새 metric이 139 compound 전체에 대해 존재하며, 이 metric은 Phase 8/10에서 AB의 가장 sensitive 한 discriminator로 입증됨 (5/5 compound × 5/5 seed 모두 <5Å). 본 contract는 (a) 새 metric 포함해 filter feature space 확장, (b) threshold 재고정으로 mmgbsa Stage 2 cohort size 70에 맞춤, (c) active vs inactive AUC ≥ 0.65 달성으로 Phase 4 대비 명시적 개선.

## Current State

- Phase 4 light filter: 99/139 pass (29% drop). Top-10 active precision 70% (1.72× baseline 40.6%).
  단 top-50에서 enrichment 1.08×, top tail에만 강한 signal.
- Phase 3 confidence AUC (binary active≤30nM): **0.426 (worse than random)** on n=37 (mmgbsa). 더 큰 n=139에서도 confidence 단독 한계 예상.
- Phase 8/10 결과: AB pattern은 vav1_offset을 17.4 Å → 3.0-3.97 Å (target zone) 로 끌어 내림. 5/5 cpd 모두 <5Å.
- Step 4 (5638 RUNNING) 완료 후 데이터:
  - `ab_139batch_eval.csv` (≥120 rows): F1@4Å, F1@5Å, vav1_rigid_body_offset, target_min_dist, iptm, plddt, p_vav1_lig
  - `ab_vs_norm143_paired.csv`: Δ vs baseline per compound
- DC50 ground truth: `outputs/_mmgbsa_staging/norm143_corrected_sources.tsv` (99 row) 또는 norm143_full 자체 metadata
- mmgbsa Stage 2 cohort 요구: ready 70 compound + VAV1_411 (host-232 회수) 등. 본 filter가 sources.tsv 생성

## Assumptions And Questions

- assumptions:
  - Step 4 AB-139 결과가 ≥120 valid PDB + non-NaN F1@4Å + vav1_offset 제공 (Step 4 contract Done When §3)
  - DC50 metadata가 norm143_full CSV에 포함됨 (또는 corrected_sources.tsv에서 join 가능). active 비율은 ~40% (norm143 baseline)
  - active 정의 = DC50 ≤ 30 nM (standard cutoff; 사용자 변경 시 contract revise)
  - vav1_offset이 5Å 임계값에서 가장 큰 separation 보일 것 (Phase 8/10 5/5 confirmed)
  - Phase 4 filter의 4개 feature는 baseline으로 유지하고 vav1_offset만 추가하는 increment vs 전체 재튜닝 — 후자 선택 (1D grid + AND combo로 충분 표현)
- open questions:
  - F1@4Å이 active rate와 monotonic correlation 보일지 (Phase 3는 confidence null; Step 3는 top-5 robust지만 134 다른 compound에서는 가변 가능)
  - vav1_offset이 saturate되었으면 (모두 <5Å) discriminator로 작동 안 함 — Step 4 분포에서 spread 확인 필요
  - 70 cohort size 게이트가 너무 strict하면 AUC와 trade-off (cohort 50으로 줄여서 AUC 더 끌어올리기 vs 70 고정)
- tradeoffs:
  - 1D AND combo는 단순하나 feature 상관성 못 잡음 (예: vav1_offset과 F1@4Å이 redundant) — 단 AUC 0.65 가능하면 ML 불필요
  - Cohort 70 lock vs AUC 0.65 lock 동시 만족 어려울 수 있음 — 둘 다 충족 못하면 사용자 결정 (more permissive vs strict)

## Constraints

- allowed change scope:
  - 새 evaluator: `analysis/fragmap_spectral_discriminator/src/light_filter_ab_recal.py`
  - 새 sources.tsv: `outputs/_mmgbsa_staging/light_filter_ab_cohort70.tsv` (mmgbsa Stage 2 input)
  - 새 report: `analysis/fragmap_spectral_discriminator/reports/light_filter_ab_recal.md`
  - threshold dict (Python dict 또는 small JSON): `analysis/fragmap_spectral_discriminator/configs/light_filter_v2.json`
- forbidden change scope:
  - Phase 4 filter logic 파일 변경 금지 (old filter는 baseline reference로 보존)
  - `src/boltz_extension/*` 변경 금지
  - mmgbsa SLURM script 자동 변경 금지 (cohort tsv만 제공)
  - ML/GBM model files 도입 금지 (simple threshold만)
- external constraints:
  - zero-compute: Python (pandas, sklearn.metrics.roc_auc_score), local CPU, ~10 min wall
  - 입력 deps: Step 4 5638 COMPLETED + ab_139batch_eval.csv ≥ 120 rows
  - DC50 metadata source: norm143_full CSV에서 추출 또는 sources.tsv

## Non-Goals

- MMGBSA Stage 2 자동 트리거 (cohort tsv만 제공, 실제 submit은 사용자 결정 + host-232 제외 등 mmgbsa slice 별도)
- Step 6 정식 DC50 correlation (Pearson/Spearman/per-class breakdown/scatter) — Step 5는 AUC binary metric만
- ML/GBM 학습 (1D threshold AND combo만)
- Filter feature space 무한 확장 (max 6 features: 기존 4 + vav1_offset + F1@4Å)
- Worker `failed_stage.tsv` bug fix (5627 분석에서 발견된 별도 트랙)
- mmgbsa Stage 2 결과 분석

## Done When

1. **Step 4 5638 COMPLETED + Step 4 evaluator CSV ≥ 120 rows 검증** (선결 조건)
2. **Threshold grid + AND combo search**: 6 candidate features (ipde, clash, plddt, p_vav1_lig, vav1_offset, F1@4Å) 각각 1D grid (10-20 thresholds). pairwise/triplewise AND combo 시도
3. **Best filter**: cohort size = 70 ± 3 (67-73 OK) AND AUC(active vs inactive) ≥ 0.65 동시 만족하는 threshold set 선정
   - 충족 못하면: cohort 65-75 범위에서 AUC 최대 set 선정 + 사용자 결정 게이트 escalation
4. **70-cohort sources.tsv 생성**: `outputs/_mmgbsa_staging/light_filter_ab_cohort70.tsv` (compound, run_type, yaml_path, pdb_path 등 mmgbsa staging 표준 schema)
5. **Report 작성**: `analysis/fragmap_spectral_discriminator/reports/light_filter_ab_recal.md`
   - Phase 4 vs new filter 비교 표 (pass rate, cohort size, AUC, top-10 active rate)
   - Selected threshold dict
   - Active rate per decile (sanity)
   - Cohort composition (DC50 분포, VAV1_345/411 등 top hit 포함 여부)
   - **Verdict**: PROMOTE (filter v2 production 권고) / HOLD (cohort 70 + AUC 0.65 동시 만족 못함, 사용자 결정) / REGRESS (Phase 4보다 안 좋음, 채택 안 함)
6. **Filter spec JSON 저장**: `analysis/fragmap_spectral_discriminator/configs/light_filter_v2.json` (reproducibility)
7. **`.agent/status/fragmap.md` §Open Step 5 → §Closed 갱신**
8. **`.agent/handoffs/CURRENT.md` remaining_actions 갱신**

## Implementation Steps

1. **5638 완료 + Step 4 evaluator 출력 검증**
   - prereq: `vav1_ab_139batch_<TS>/` PDB count ≥ 120
   - prereq: `ab_139batch_eval.csv` 존재, F1@4Å + vav1_offset non-NaN
   - verify: `python -c "import pandas; df=pd.read_csv('ab_139batch_eval.csv'); print(df.shape, df.isna().sum())"` OK

2. **Feature CSV 작성**
   - `light_filter_ab_recal.py`: AB CSV + norm143_full baseline join + DC50 metadata join
   - 6 features per compound + active label (DC50 ≤ 30nM)
   - verify: row count = AB cohort size, no NaN on features

3. **Threshold grid search**
   - 각 feature 1D: quantile-based grid (5%, 10%, ..., 95%)
   - 결과 표 (per feature): cohort_size_passing, AUC_passing, AUC_overall
   - Pairwise AND combo (15 pairs) + triplewise (20 triples)
   - verify: 모든 grid run 완료, AUC 계산 non-NaN

4. **Best filter 선정**
   - cohort 70±3 만족하는 set 중 AUC 최대
   - tie-breaking: top-10 active rate 더 높은 쪽
   - verify: report에 selected threshold + 2nd/3rd alternative 비교

5. **70-cohort sources.tsv 생성**
   - mmgbsa staging 표준 schema 따름 (`outputs/_mmgbsa_staging/norm143_corrected_sources.tsv` 참조)
   - verify: row count = 70, 모든 path file exists

6. **Report 작성**
   - 표 + verdict + Step 6 권고 (Pearson/Spearman/per-class)
   - verify: report markdown valid + verdict 명시

7. **Status doc + CURRENT.md 업데이트**
   - verify: `./scripts/handoff.sh claude` clean (옵션, /handoff에서 합칠 수 있음)

## Change Discipline

- simplest adequate approach: 1D threshold + AND combo, no ML
- new abstractions introduced: 없음 (sklearn.metrics.roc_auc_score 사용)
- unrelated code touched: 없음
- pre-existing dead code noticed: 없음
- request-to-diff trace: brainstorm Q1 (cohort 70 + AUC 0.65) + Q2 (no Stage 2 auto-trigger) + Q3 (zero-compute post-5638)

## Verification

- `python light_filter_ab_recal.py` exits 0
- Filter v2 JSON valid
- 70-cohort tsv = 70 rows, paths exist
- Report markdown valid + verdict (PROMOTE/HOLD/REGRESS) 명시
- AUC sanity: Phase 4 reproduce 0.55-0.60 정도, v2 ≥ 0.65 (or HOLD)

## Risks

- prereq risk: Step 4 5638이 STOP verdict (Done When §6c)면 Step 5는 부적합 — Step 4 verdict GO/HOLD에서만 진행
- statistical risk: cohort 70 + AUC 0.65 동시 만족 못할 수 있음 → HOLD verdict + 사용자 결정
- feature redundancy: vav1_offset과 F1@4Å이 highly correlated이면 AND combo가 over-restrict — 1D 단독도 fallback option
- cherry-picking risk: 6 features × 20 thresholds × 15 pairs = 1800 combos 검색 → multiple testing inflation. mitigation: validation은 holdout 없이 entire 139 cohort에 대한 in-sample AUC (Stage 2 실제 ΔΔG가 진짜 holdout) — 의도적 cap
- DC50 label noise: 일부 compound DC50이 assay 변동 큼 (Phase 9 anecdotal) → 30 nM cutoff fragile. mitigation: 보조 cutoff 100 nM에서도 AUC 보고

## Rollback

- revert strategy: report + sources.tsv + JSON 삭제. Phase 4 filter는 그대로 baseline reference로 남음
- containment strategy: 새 file 모두 별도 path. 기존 filter logic 무수정

## Triggers Matched (WORKFLOW.md §2)

- ❌ SLURM submission (zero-compute)
- ✅ ranking semantics 변경 (light filter는 mmgbsa cohort selector — ranking-adjacent)
- ✅ 4+ files modified (evaluator + tsv + report + JSON config + status update = 5)
- ✅ shared storage write (_mmgbsa_staging/, analysis/reports/)
- ❌ FragMap scoring mode 변경 (filter는 post-hoc)
- ❌ local vs shared concurrent edits

## Progress Log

- 2026-05-26: contract drafted via /brainstorm (status: pending)
  - Q1 success criterion = cohort 70 + AUC ≥ 0.65
  - Q2 out of scope = MMGBSA Stage 2 auto-trigger; implicitly Step 6 정식 DC50 + ML
  - Q3 = zero-compute post-Step 4, rollback = file 삭제
- 2026-05-26: user approved. status: approved. 실행은 5638 COMPLETED 후. /write-plan은 prereq 충족 후 invoke.
