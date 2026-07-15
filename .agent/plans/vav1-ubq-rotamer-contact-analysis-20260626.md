---
contract: .agent/contracts/vav1-ubq-rotamer-contact-analysis-20260626.md
slice: vav1-ubq
status: in-progress
total_tasks: 6
estimated_total_min: 50
---

# Plan — Rotamer Optimization + SH3c Contact Analysis

Zero-GPU. 작업 디렉토리: `analysis/crl_integrative/steered_regen/`.

---

## Task 1: 비-MCS 원자 rotatable bond 분석
- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `analysis/crl_integrative/steered_regen/rotamer_analysis.py` (출력: rotbond_summary.tsv)
- **Change shape**: 12 S003 각각의 비-MCS 원자들 rotatable bond 수 계산. 샘플링 비용 예측(n_states^n_bonds). VAV1_101/379(비-MCS=0) 제외 처리.
- **Verification**: `python rotamer_analysis.py` → tsv(compound·n_nonMCS·n_rotbonds·n_conformers_planned) 존재.
- **Estimated time**: 5 min
- **Rollback**: rm rotbond_summary.tsv

## Task 2: MCS 고정 멀티컨포머 생성 (RDKit ETKDG constrained)
- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: `analysis/crl_integrative/steered_regen/generate_rotamers.py` (출력: `rotamers/<compound>/conf_<i>.pdb`)
- **Change shape**: 각 화합물 MCS 13원자 crystal 좌표 고정(ConstrainedEmbed), 비-MCS 원자 ETKDG로 50-200개 컨포머 생성. 전 원자 clash 제거(<2.5Å vs CRBN+SH3c rigid). 유효 컨포머 저장.
- **Verification**: 12/12 화합물에 ≥1 clash-free 컨포머 존재(없으면 MCS-only로 fallback, 기록). rotamers/ 디렉토리 존재.
- **Estimated time**: 10 min
- **Rollback**: rm -r rotamers/

## Task 3: OpenMM CPU 최소화 (MCS restraint + 접촉 sidechain 이완)
- **Status**: pending
- **Prereq tasks**: 2
- **Files touched**: `analysis/crl_integrative/steered_regen/minimize_rotamers.py` (출력: `minimized/<compound>/best.pdb`)
- **Change shape**: 각 화합물 최적 clash-free 컨포머(가장 낮은 MMFF 에너지) → OpenMM CPU에서 minimization. MCS 원자 harmonic restraint k=1000 kJ/mol/nm². ARG796/TRP820/D797/S799 sidechain 원자 자유 이완. 나머지 protein 원자 fixed.
- **Verification**: `python minimize_rotamers.py` → 12/12 minimized/\<compound\>/best.pdb 존재 + PE 수렴(print log).
- **Estimated time**: 15 min
- **Rollback**: rm -r minimized/

## Task 4: SH3c engagement 에너지 계산
- **Status**: pending
- **Prereq tasks**: 3
- **Files touched**: `analysis/crl_integrative/steered_regen/score_contacts.py` (출력: contact_scores.tsv)
- **Change shape**: 최소화된 포즈에서 ① 비-MCS 원자의 ARG796+TRP820 대비 productive contact 수(2.5-4.0Å) ② OpenMM MM pair energy(non-MCS atoms ↔ ARG796+TRP820 residue atoms) ③ MCS 코어의 ARG796+TRP820 pair energy (baseline, 모든 화합물서 동일). 화합물별 delta_E = non-MCS contribution 분리.
- **Verification**: `python score_contacts.py` → contact_scores.tsv(compound·logDC50·n_productive·interaction_energy_kcal·delta_E) 존재.
- **Estimated time**: 8 min
- **Rollback**: rm contact_scores.tsv

## Task 5: DC50 상관 분석 (사전 등록 기준 적용)
- **Status**: pending
- **Prereq tasks**: 4
- **Files touched**: `analysis/crl_integrative/steered_regen/contact_dc50_correlation.py` (출력: contact_correlation.png + contact_correlation_report.txt)
- **Change shape**: Spearman ρ(logDC50, interaction_energy) + ρ(logDC50, n_productive) 계산. 사전 등록 기준(ρ<0, |ρ|>0.3, p<0.1) 판정. MCS-aligned(before) vs rotamer-optimized(after) contact distance 비교 테이블. 그래프 fks png/ 저장.
- **Verification**: report.txt에 PASS/FAIL + ρ + p 명시 + png 존재.
- **Estimated time**: 5 min
- **Rollback**: rm contact_correlation.{png,txt}

## Task 6: 결과 리포트 + 커밋
- **Status**: pending
- **Prereq tasks**: 5
- **Files touched**: `analysis/crl_integrative/rotamer_contact_results_20260626.md`
- **Change shape**: 설계 결정 요약 + 결과 수치 + PASS/FAIL 판정 + 해석 + 다음 단계 권고. τ-RAMD pilot 리포트와 연결.
- **Verification**: 리포트 존재 + git commit.
- **Estimated time**: 7 min
- **Rollback**: rm 리포트
