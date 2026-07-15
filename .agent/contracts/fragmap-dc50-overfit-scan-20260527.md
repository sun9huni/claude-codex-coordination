---
status: done
slice: fragmap
topic: dc50-overfit-scan
date: 2026-05-27
owner: claude
approved_by: user (2026-05-27, "approved" after stat-design push back → exploratory-first design)
decisions:
  - 성격: EXPLORATORY 신호 인벤토리. Stage 2 go/no-go 결정 아님, 사전등록 gate(Step 6b) 아님.
  - HARKing 방지: 탐색에서 "상관 나온 지표를 채택"하지 않음. 전체 test family에 Benjamini-Hochberg FDR 보정 적용, q-value 보고. 어떤 지표를 gate로 승격하는 것은 Step 6b(별도 contract)에서 사전등록 후 독립 데이터로 재검증.
  - Overfit 해석 규칙 (사전 명시):
    - FDR 보정 후 어떤 pose metric도 DC50과 유의 상관 없음 → 강한 overfit 음성 신호 (AB가 9NFR 한 포즈 재현일 가능성), gate 없이도 잠정 결론 가능
    - ≥1 지표가 q<0.05 생존 → Step 6b 사전등록 후보 (이 단계에서 "통과" 선언 안 함)
  - Input: ab_139batch_eval.csv (125 rows) + DC50 metadata (norm143_corrected_sources.tsv: dc50_nM, logDC50) + vav1_placement_decompose 산출 metric (centroid_trans, rot_angle)
  - zero-compute, ~15 min local CPU
---

# DC50 overfit scan (Step 6, exploratory) — AB pose quality vs potency

## Purpose

AB constraint는 9NFR crystal에서 유도됐고 139 compound 전부를 9NFR contact residue로 채점한다. 순환성 probe(2026-05-27)는 trivial 순환은 아님을 보였으나(true GT F1 0.91 vs shuffled 0.00), "9NFR 포즈로 steer 후 9NFR로 채점" 가능성은 못 닫았다. 유일한 독립 신호는 DC50이다. 본 단계는 n≈125에서 pose metric과 DC50 상관을 **탐색적으로** 스캔해 (a) overfit 음성/양성 신호를 보고, (b) Step 6b 사전등록 gate에 올릴 후보 지표를 식별한다. Phase 9 n=5는 null(ρ=−0.205)이었다.

## Current State

- ab_139batch_eval.csv (125 rows): vav1_rigid_body_offset, f1_4A, f1_5A, tgt_min_dist, iptm, plddt, p_vav1_lig
- vav1_placement_decompose.py 산출: centroid_trans, rot_angle_deg (분해 metric)
- DC50: `outputs/_mmgbsa_staging/norm143_corrected_sources.tsv` (dc50_nM, logDC50). active subset 정의 = DC50 ≤ 30 nM (보조 100 nM)
- 순환성 진단 report: `analysis/fragmap_spectral_discriminator/reports/vav1_placement_decompose_20260527.md`
- 과거 한계: confidence(iptm/plddt) within-class null, F1 top-10만 enrichment, MMGBSA ΔΔG n=37 null — 세 method 모두 within-class ranking 약함

## Assumptions And Questions

- assumptions:
  - DC50 metadata가 125 cohort 대부분에 존재 (join 후 n 확인). active(≤30nM) subset n은 ~40-50 예상
  - log10 DC50가 분석 단위 (potency는 log-scale)
  - pose metric이 낮을수록(offset/tgt_min) 또는 높을수록(F1) "더 좋은 pose" → DC50 낮음(더 active)과 상관 기대 방향 사전 명시
- open questions:
  - n=139에서도 confidence/F1 null이 유지되는지 (지금까지 모든 단서가 within-class null 시사 → 본 스캔도 null일 가능성 높음, 그 자체가 정보)
  - vav1_offset(분해: centroid vs rotation)이 F1보다 DC50과 더 연결되는지
  - active subset에서만 보이는 신호 vs 전체에서 보이는 신호
- tradeoffs:
  - 탐색 범위 넓힐수록 multiple testing 부담 → FDR 보정 필수. test family를 사전에 고정(아래 Done When §2)해 사후 확장 금지

## Constraints

- allowed change scope:
  - 새 분석 script: `analysis/fragmap_spectral_discriminator/src/dc50_overfit_scan.py`
  - 새 report: `analysis/fragmap_spectral_discriminator/reports/dc50_overfit_scan_20260527.md`
  - 새 CSV: `analysis/fragmap_spectral_discriminator/reports/dc50_overfit_scan.csv` (test family + q-values)
- forbidden change scope:
  - 새 SLURM / generation 재실행 (기존 125 PDB + 산출 CSV만)
  - `src/boltz_extension/*` 미접촉
  - Stage 2 launch 또는 cohort 확정 (Step 5/별도)
  - gate "통과" 선언 또는 지표 승격 (Step 6b)
- external constraints:
  - zero-compute, local CPU (pandas, scipy.stats), ~15 min
  - DC50 source = norm143_corrected_sources.tsv (단일 출처 고정)

## Non-Goals

- Stage 2 go/no-go 결정 (별도, Step 6b 이후)
- 사전등록 gate 자체 (Step 6b 별도 contract — hold-out/다음 batch 재검증)
- 새 SLURM / generation 재실행
- MMGBSA ΔΔG 교차상관 (optional secondary로만; n=37 v3-original cohort라 AB-139와 직접 비교 부적합 → 별도 처리)
- 지표 "채택" 또는 production ranking 변경

## Done When

1. **Join**: ab_139batch_eval.csv + decompose metric + DC50 → merged table, n(both) 보고. active subset(≤30nM, 보조 ≤100nM) n 보고.
2. **사전 고정 test family** (사후 확장 금지):
   - metrics (9): vav1_rigid_body_offset, centroid_trans, rot_angle_deg, f1_4A, f1_5A, tgt_min_dist, iptm, plddt, p_vav1_lig
   - 각 metric × {Spearman, Pearson} vs log10 DC50, on {full cohort, active subset}
   - 보조: binary AUC (active≤30nM, ≤100nM) per metric
   - 기대 방향 사전 명시 (offset/tgt_min/rot ↓=better→DC50↓; F1/iptm/plddt/p_vav1_lig ↑=better→DC50↓)
3. **FDR 보정**: 전체 correlation test family에 Benjamini-Hochberg, q-value 산출.
4. **Ranked 신호 표**: metric별 ρ/r, raw p, q-value, 기대 방향 일치 여부. q<0.05 생존 항목 강조.
5. **Overfit 해석** (사전 규칙 적용):
   - 0개 생존 → "강한 overfit 음성 신호: AB 포즈가 DC50와 무관 = 9NFR 재현 가능성. Stage 2 정당화 약함" (잠정)
   - ≥1 생존 → "Step 6b 사전등록 후보: <지표>. 단 본 단계는 통과 선언 안 함, 독립 재검증 필요"
6. **Report + CSV** 작성, 해석에 "exploratory, not a gate" 명시.
7. `.agent/status/fragmap.md` §Open Step 6 갱신 + CURRENT.md remaining_actions 갱신.

## Implementation Steps

1. **데이터 join**: merged CSV (pose metric + DC50). n(both), active n 보고.
   verify: row count > 100, DC50 non-null fraction 보고
2. **Correlation scan**: 사전 고정 family 전부 계산 (scipy.stats.spearmanr/pearsonr + sklearn roc_auc_score).
   verify: test 수 = 사전 명시 수와 일치 (사후 확장 0)
3. **BH-FDR 보정**: statsmodels multipletests 또는 수동 BH. q-value 컬럼.
   verify: q ≥ p 모든 행, 생존 항목 수 보고
4. **Report 작성**: ranked 표 + overfit 해석 + Step 6b 권고.
   verify: report에 "exploratory / not a Stage 2 gate" 명시 + q<0.05 생존 수 명기
5. **Status/CURRENT 갱신**.
   verify: handoff clean

## Change Discipline

- simplest adequate approach: 단일 스캔 스크립트, 사전 고정 family, FDR 보정. ML 없음.
- new abstractions: 없음 (scipy/sklearn)
- unrelated code touched: 없음
- pre-existing dead code: 없음
- request-to-diff trace: 사용자 "Step 6 DC50 overfit gate 먼저 brainstorm" → 통계 설계 push back → "탐색 우선, gate 별도" 선택 → exploratory scan contract

## Verification

- `python dc50_overfit_scan.py` exit 0
- test 수 = 사전 명시 family 수 (확장 없음)
- 모든 q ≥ p
- report에 q<0.05 생존 수 + overfit 해석 + "not a gate" 명시
- CSV: metric별 ρ/r/p/q row 완비

## Risks

- statistical: n(active)이 작으면(~40) power 낮아 진짜 신호도 못 잡을 수 있음 → "null = overfit 확정"이 아니라 "null = 신호 없음 또는 power 부족" 으로 신중 해석. report에 active n + 검출가능 effect size 명시
- HARKing 재발: 탐색 결과로 즉석 gate 판정하려는 유혹 → contract가 명시적으로 금지, Step 6b 분리
- DC50 noise: assay 변동 큼(Phase 9). 30nM cutoff fragile → 100nM 병행 보고
- survivorship: 125/145만 평가됨(20 silent-fail). DC50 분석도 이 편향 상속 → report에 명시, silent-fail 진단 후 재검토 가능

## Rollback

- revert: report + CSV + script 삭제. 기존 데이터 무변경 (read-only 분석)
- containment: 새 file 별도 path, production 경로 무수정

## Triggers Matched (WORKFLOW.md §2)

- ❌ SLURM submission (zero-compute)
- ❌ ranking semantics 변경 (exploratory, 결정 안 함 — 명시적으로 gate 아님)
- ✅ shared storage write (analysis/reports/)
- 4+ files: 경계 (script + CSV + report + status = ~4) → 가벼운 contract 정당
- ❌ FragMap scoring mode 변경

## Progress Log

- 2026-05-27: contract drafted via /brainstorm (status: pending)
  - 동기: vav1_placement_decompose 순환성 probe가 trivial 순환 배제했으나 "steer→채점" 순환 미해결 → 독립 신호 DC50 필요
  - Q1 success: 통계 설계 push back (HARKing 경고) → 사용자 "탐색 우선, gate 별도" 선택
  - Q2 out of scope: Stage 2 결정, Step 6b 사전등록 gate, 새 SLURM/generation
  - 핵심: EXPLORATORY scan + BH-FDR, Stage 2 판정 안 함, gate 승격은 Step 6b
- 2026-05-27: EXECUTED (plan fragmap-dc50-overfit-scan-20260527, 5/5 tasks done). Result: **0/36 survivors** after BH-FDR (n=84 full, 35 active). Strongest raw signals (offset/rot/centroid spearman full, ρ≈−0.27 to −0.31) WRONG-direction, n.s. after FDR (q≥0.13). AUC all ≤0.51, placement metrics <0.5. **Verdict: strong overfit-negative — AB pose quality does not track potency (4th independent within-class-ranking null).** Report: dc50_overfit_scan_20260527.md. status: done.
