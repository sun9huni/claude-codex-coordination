---
status: done
slice: fragmap
topic: dmax-multivariate-test
result: "KILL (both cohorts). FULL (n=138): structure features → grouped-CV Spearman +0.011 (perm p=0.986 = chance); descriptors-only MW/logP +0.258 BEATS it; MW/logP-partial −0.005 (structure adds nothing). ACTIVE (n=56): Dmax_std=2.8 only — potent binders nearly all degrade ~95–99% → no dynamic range, test moot (−0.284, perm p=0.283). VERDICT: Dmax is ALSO physchem/no-structure beyond the MW prior — same as DC50. The earlier carried-forward dG_C/keyres→Dmax signals (+0.36/−0.19, raw, non-scaffold-blocked) were in-sample/physchem illusions that scaffold-blocked CV dissolves. Dmax pivot KILLED. Biological note: in this VAV1 series potency↔efficacy are coupled (good binders = complete degraders), so no separable efficacy axis exists among actives to model."
date: 2026-05-29
owner: claude
approved_by: user (2026-05-29, "진행" after cross-experiment mining surfaced dG_C→Dmax signal → test if degradation completeness is structure-predictable)
decisions:
  - 성격= PRE-REGISTERED diagnostic (Step 0의 자매 테스트). 점수 보기 전 spec/threshold/leakage-guard/STOP 동결. 이후 변경 금지.
  - 동기= cross-experiment mining(cross_experiment_insights_20260529.md §5)에서 dG_C가 potency(DC50)보다 efficacy(Dmax)를 더 잘 추적(dG_C vs Dmax Pearson −0.185; keyres/n_lv vs Dmax +0.30~0.36). 가설= **degradation completeness(Dmax)는 ternary 기하에 DC50보다 가까울 수 있다.** Step 0가 DC50를 죽였으니, Dmax가 구조-예측 가능한지 같은 엄밀성으로 테스트.
  - ★ 결정적 통제= Dmax는 DC50와 상관 → descriptors-only(MW/logP/HBD/HBA/rotbond) baseline + MW/logP partial 필수. 안 하면 Step 0의 MW confound를 새 라벨로 재발견할 뿐. "structure가 Dmax 예측" vs "MW가 Dmax 예측"을 반드시 분리.
  - PROVE = grouped-CV Spearman(pred,Dmax) |ρ|≥0.30(full) AND 1000× label-permutation 95% band 초과(p<0.05) AND descriptors-only가 못 따라옴(차 >0.05). → degradation completeness가 physchem 너머 구조-예측 가능 → Dmax-pivot 추구 정당.
  - KILL = permutation band과 구분 불가 OR descriptors-only가 매칭/초과. → Dmax도 physchem/무신호 → degradation-completeness pivot이 구조 모델을 구제 못 함. charter A 유지.
  - leakage-guard (Step 0와 동일, 동결): 순환 feature 격리(lig_crbn_f1, lig_vav1_f1, iface_f1); Murcko-scaffold GroupKFold; DC50/active/Dmax를 predictor로 안 씀.
  - cohort (동결): (full) Dmax 보유 전체 (~139) = 주. (active) active==1 (~56) = 보조(강한 binder 중 degradation completeness 예측 가능?).
  - 보고 규칙 (동결): 검출한계 bound로 기술; no-GT→activity-validator(Dmax는 측정 활성 endpoint); per-compound Spearman(top-K 금지); git-track.
---

# Dmax multivariate test — degradation completeness가 구조-예측 가능한가 (Step 0 자매)

## Purpose

Step 0가 within-class **potency(DC50)** 순위를 죽였고(physchem로 환원), cross-experiment mining은
**efficacy(Dmax)**가 다른 결정 인자임을 시사했다(dG_C·keyres가 DC50보다 Dmax를 더 잘 추적).
DC50는 cooperativity/kinetics/permeability(구조 밖)가 지배하지만, **degradation completeness(Dmax)**는
ternary 기하·lysine presentation(구조 내)에 더 가까울 수 있다 — 미검증. 본 단계는 Step 0와 *동일한*
누수 차단 다변량 절차로, 라벨만 logDC50→Dmax로 바꿔 Dmax가 구조-예측 가능한지(physchem 너머) 테스트.

## Current State

- Target: `data/VAV1_Analy...lts_Part_{1,2,3}.csv` (tab-sep) `VAV1 Dmax %`. join: feature_matrix `VAV1_101` → int `101` → `Compound No.`.
- Dmax 분포(라벨 recon): n=397 측정, mean 84.0%, median 91.0, min 1.26, max 99.35, **ceiling 없음**(0 at 100), 6 NaN. left-skew(bulk 80–96%, tail to 1.26 = 불완전 degrader).
- Predictors: feature_matrix_snapshot_20260529.csv의 59 feature 중 순환 3개 격리 → 56.
- 선행 신호(cohort-level, mining §5): keyres vs Dmax Spearman +0.364, n_lv +0.303, dG_C −0.101 (전부 carried/약함).

## Assumptions And Questions

- 가정: Dmax-DC50 상관 존재 → descriptors-only baseline이 confound 분리의 핵심.
- open: Dmax bulk가 80–96%로 압축 → 동적범위 작음, 신호 검출 어려울 수 있음(full std ~18.6 전체, active subset은 더 좁을 수). bound로 기술.
- tradeoff: full cohort가 결정 driver(Dmax는 active/inactive 무관하게 의미 있음).

## Constraints

- allowed: 새 스크립트+산출물을 `analysis/multivariate_potency_test_20260529/`에 추가, git-track. 원본 read-only.
- forbidden: production ranking 변경(진단); SLURM/GPU; threshold 사후 변경.
- external: no-GT→activity-validator; per-compound metric(top-K 금지).

## Non-Goals

- production ranking 교체(양성이면 별도 contract). 신규 MD/generation. 9NFR-distribution-shift 해석.

## Done When

- full + active cohort에 대해 grouped-CV Spearman(pred,Dmax) ± boot CI, vs 1000× permutation band.
- descriptors-only + MW/logP partial 보고(confound 분리). n_scaffolds, retained/quarantined feature 목록.
- PROVE/KILL 판정을 사전등록 threshold 대비 bound로 기술. 스크립트+결과 git-track.

## Implementation Steps

1. Analy Dmax 로드+join(VAV1_xxx→int), feature_matrix와 병합. n 확인.
   verify: join된 행수 출력, Dmax NaN 제외 후 n
2. 56 retained predictor(순환 3 격리), Murcko scaffold group.
   verify: retained==56, 격리 목록 일치
3. ElasticNet(primary, 관측은 full CV) + GBM(robustness), nested scaffold-GroupKFold, full+active.
   verify: fold train/eval scaffold 교집합 ∅
4. 1000× label-permutation(고정 hyperparam) + descriptors-only + MW/logP partial.
   verify: perm 중심≈0
5. report+판정, git-track.
   verify: compileall 통과; threshold = 본 contract 동결값

## Verification

- `python -m compileall analysis/multivariate_potency_test_20260529/dmax_multivariate_test.py`
- 결과는 bound로; threshold 사후 변경 금지.
