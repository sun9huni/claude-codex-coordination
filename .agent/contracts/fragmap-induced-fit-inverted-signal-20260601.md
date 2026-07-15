---
status: done
slice: fragmap
topic: induced-fit-inverted-signal
date: 2026-06-01
owner: claude
approved_by: user (2026-06-01, "둘 다 진행 ... 시간이 오래 걸려도 좋으니 정확하고 절차대로" — deep-mining 무늬 4 confirm/kill)
result: "KILL (frozen rule). Placement↔potency inversion (raw offset ρ=−0.305) is WITHIN-chemotype SAR, not cross-chemotype induced-fit: Murcko-scaffold-blocked OOF ρ=−0.117 (95% CI [−0.328,+0.104]), permutation p=0.694 (detect-limit |ρ|=0.328) → leg (i) perm-significance FAILS. centroid/rotation (collinear) collapse identically (OOF −0.140/−0.124, p 0.60/0.67). active n=35 fully collapses (OOF +0.028, p 0.97, underpowered |ρ|≥0.47). NOTABLE REFINEMENT: NOT an MW artifact — MW/logP-partial SURVIVES at −0.281 (leg ii TRUE); but descriptors-only OOF +0.247 out-predicts the blocked offset (leg iii FALSE). So the inversion is the one corpus signal that is neither MW nor generalizable structure = congeneric within-series SAR. Induced-fit/alternate-basin NOT supported (would survive cross-chemotype blocking); charter A unchanged/strengthened; D3 escalation NOT justified by this; last unexplained activity thread now closed. Report: analysis/induced_fit_inverted_signal_20260601/RESULTS.md (FKSFold). Pre-registration vindicated: MW-partial survival alone would have looked promising; scaffold-block is what killed it, exactly as the free test was meant to adjudicate."
decisions:
  - 성격= PRE-REGISTERED diagnostic (NOT exploratory). 점수 보기 전에 spec/threshold/leakage-guard/PROVE-KILL 규칙을 본 contract에 동결. 이후 threshold 변경 금지. (태피스트리의 중심 교훈 "패널에 fit하면 신호 부풀림"이 이 테스트 자신에게 가장 엄격히 적용된다.)
  - 검증 동기= deep-mining(2026-06-01)에서 dc50_overfit_scan의 placement-geometry↔logDC50 **역방향** 신호(offset ρ=−0.305, 즉 "9NFR-crystal 매치 좋을수록 *덜* 강력")가 이 코호트에서 **MW로 안 녹는 유일한** 약신호로 드러남(MW/logP-partial −0.250, raw −0.305). dc50_overfit_scan은 이를 q≥0.13 비유의로 버렸으나, (a) 뒤집힌 포즈 9개 제거 후 well-placed bulk(n=62)에서도 ρ=−0.247 생존, (b) MW가 거의 설명 못 함 → "노이즈"로 단정 전 scaffold-blocked + perm null로 confirm/kill 필요. 신규 compute 0 (디스크 CSV + 동결 라이브러리).
  - 가설(falsifiable, induced-fit/alternate-basin)= 가장 강력한 VAV1 유사체의 분해-적격(degradation-competent) ternary 포즈는 9NFR 크리스탈 포즈에서 *변위*돼 있고, 크리스탈-고정 AB steering이 그들을 덜 생산적인 conformation으로 밀어붙인다 → 크리스탈 매치(낮은 offset)가 낮은 potency를 예측(역방향). super-hit VAV1_292가 진짜 alternate basin(recall 0.67→0.33, superhit_mechanism.py)이었던 것과 정합.
  - PRIMARY metric (사전 동결)= `vav1_rigid_body_offset` (raw |ρ|=0.305 최강). centroid_trans(ρ_offset=0.96)·rot_angle_deg(0.88)는 **collinear = 동일 latent 축** → corroboration only, 독립 확증 아님. 3개 중 best 골라잡기로 multiple-testing 부풀리기 금지.
  - PRIMARY cohort (사전 동결)= full n=84 logDC50 (역신호의 home). active(DC50≤30nM) n=35는 검출한계 |ρ|≥0.46 → **bound only**, 결정 driver 아님.
  - 통계 (사전 동결, 전부 동결 라이브러리 analysis/foundation/activity_eval_gates.py 사용 = 직전 multivariate 테스트와 동일 머신, 메서드-쇼핑 금지):
    - (A) raw signed Spearman(offset, logDC50) — 방향 + scan 재현(−0.305 기대).
    - (B) scaffold-blocked: grouped_oof_predict(X=offset, y=logDC50, groups=Murcko-scaffold, kind=enet) → Spearman(oof, logDC50)=ρ_oof. = 다른 chemotype으로의 cross-scaffold 일반화. (within-scaffold SAR 아티팩트면 붕괴.)
    - (C) permutation_null(1000×, 동일 grouped scheme, obs=|ρ_oof|) → p_value_two_sided + perm_abs_p95(=검출한계).
    - (D) MW/logP-partial signed: partial_spearman(offset, logDC50, [MW,logP]) → ρ_partial. MW/logP는 rdkit로 SMILES에서 실측(proxy 금지).
    - (E) descriptors-only baseline: descriptors_only_spearman([MW,logP], logDC50, scaffold) → physchem 단독 재현 여부.
    - (F) bootstrap_ci(ρ_oof).
  - PROVE/KILL (사전 동결):
    - PROVE = 다음 **전부**: (i) ρ_oof가 1000× permutation 95%ile band 초과(p<0.05) = offset이 out-of-scaffold로 potency 예측; AND (ii) ρ_partial이 induced-fit(음의) 방향 유지 + |ρ_partial|≥0.15 (MW/logP로 안 녹음); AND (iii) descriptors-only ρ가 offset 신호를 0.05 이내로 못 따라옴(geometric이지 physchem 재출현 아님). → induced-fit/alternate-basin 신호 real, 비순환 held-out 테스트(D3) 정당화 → 승격(단 D3 자체는 target-ID + contract 게이트, 본 단계에서 미실행).
    - KILL = ρ_oof가 permutation band과 구분 불가(= within-scaffold SAR, cross-chemotype 일반화 안 됨) OR ρ_partial이 |ρ|<0.15로 붕괴(= MW/logP였음) OR descriptors-only가 재현. → 역방향 thread는 마지막 within-scaffold/MW 잔재로 설명됨, charter A 불변, induced-fit escalation 없음, "−0.25"는 해명 완료.
  - leakage-guard (사전 동결): (1) Murcko-scaffold GroupKFold(train/eval scaffold 교집합 ∅) — within-scaffold SAR을 cross-chemotype 신호와 분리. (2) MW/logP rdkit 실측 partial — physchem confound 제거. (3) DC50는 label(log10)로만, predictor 금지; top-K 금지; 결과는 검출한계 bound로. (4) offset/centroid/rotation = 1 가설(collinear), best-of-3 cherry-pick 금지.
  - 보고 규칙 (사전 동결): bare "null"/"signal" 금지, "|ρ|≤X 미검출 at n=84/35" 형태. no-GT: DC50 rank에만 채점, 9NFR-distribution-shift로 채점 금지. per-compound Spearman. **congeneric-series caveat 필수**: 84개 전부 glutarimide warhead(O=C1CCC(...)C(=O)N1) 공유 → "scaffold"=exit-vector/linker chemotype이지 무관 scaffold 아님(62 scaffold, 51 singleton). cross-"scaffold"는 cross-exit-vector를 의미.
  - n=84는 |ρ|≥0.30, n=35 active는 |ρ|≥0.46만 검출(dc50_overfit_scan power note). KILL은 "효과 0"이 아니라 "≤ 검출한계 효과는 배제 불가" = bounded.
---

# Induced-fit inverted-signal test — scaffold-blocked confirm/kill of the placement↔potency inversion

## Purpose

deep-mining(2026-06-01)이 6개월 corpus에서 찾은 **유일하게 아직 MW로 해명되지 않은 약신호**를
사전등록 게이트로 confirm/kill 한다: placement-geometry(VAV1 rigid-body offset)가 logDC50와
**역방향**(crystal 매치 좋을수록 덜 강력)으로 상관. dc50_overfit_scan은 q≥0.13으로 버렸으나
(a) 잘-배치된 bulk(n=62)에서 생존(−0.247), (b) MW/logP-partial이 −0.250으로 거의 안 녹음 →
"노이즈" 단정 전 scaffold-blocked CV + permutation null이 필요. 이 신호가 살아남으면 induced-fit/
alternate-basin 생물학(크리스탈 포즈 ≠ 분해-적격 포즈)을 시사하고 D3(비순환 held-out) 정당화;
녹으면 charter A의 "activity=MW prior, placement만 real" 결론이 더 강화된다. 신규 compute 0.

## Current State

- Inputs (read-only, shared):
  - offset: `…/analysis/fragmap_spectral_discriminator/reports/ab_139batch_eval.csv` (`vav1_rigid_body_offset`)
  - centroid/rotation: `…/reports/vav1_placement_decompose.csv` (`centroid_trans`,`rot_angle_deg`)
  - DC50: `…/outputs/_mmgbsa_staging/norm143_corrected_sources.tsv` (`dc50_nM`)
  - SMILES: `…/reports/ligand_position_features.csv` (`SMILES`, 84/84 coverage 확인)
- merge(ev⟕dec, ⟗src on DC50, ⟕lpf) → n_full=84, n_active(≤30nM)=35 (dc50_overfit_scan과 동일 join).
- 재현 확인: raw Spearman(offset,logDC50)=−0.305; offset~centroid ρ=0.96, offset~rot ρ=0.88; 62 scaffold(51 singleton, 최대 9).
- 환경: rdkit 2025.09.1, sklearn, 동결 라이브러리 activity_eval_gates.py (smoke OK).

## Constraints

- allowed: 새 분석 스크립트 + 산출물(CSV/MD)을 repo `analysis/induced_fit_inverted_signal_20260601/`에 git-track. shared 입력은 read-only(스냅샷만).
- forbidden: 입력 원본 수정; production ranking(vav1_ensemble_rank.py 등) 변경(진단, ranking-default 불변); SLURM/GPU; threshold 사후 변경; 동결 라이브러리 외 새 메서드 도입(메서드-쇼핑).
- external: no-GT→activity-validator 규칙; per-compound metric(top-K 금지).

## Non-Goals

- production ranking 교체 (PROVE여도 별도 ranking contract).
- D3(비순환 held-out crystal / HDX·XL-MS) 실행 (PROVE 시 후속, target-ID + contract 게이트).
- 신규 MD/FEP/generation.

## Done When

- (A)~(F) 전부 full + active(bound)에 대해 보고; PROVE/KILL을 **사전등록 threshold**에 대해 bound 형태로 판정.
- 스크립트 + frozen 입력 스냅샷 + permutation null 분포 CSV를 repo에 git-track.
- congeneric-series caveat + detection-limit bound 명시.

## Verification

- `python -m compileall analysis/induced_fit_inverted_signal_20260601/`
- threshold는 본 contract 동결값 사용 (사후 변경 금지). 결과는 검출한계 bound로.
