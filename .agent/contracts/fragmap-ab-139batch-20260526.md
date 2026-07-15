---
status: approved
slice: fragmap
topic: ab-139batch
date: 2026-05-26
owner: claude
approved_by: user (2026-05-26, "진행" after Step 3 close-out + Step 4 contract draft + dep verify)
decisions:
  - 139 compounds × 1 seed (seed=16) = 139 cells (multi-seed robustness 확인됨; 단일 seed로 5× compute 절감)
  - Pattern: AB (Phase 8/10) = Boltz YAML contact [A,106]↔[B,35] + [A,352]↔[B,16] + pocket VAV1 32-41 + CRBN 104-109 + 14-19 / 305-355
  - npart=8, λ=20 (P7 setup, Phase 8/10과 동일 binary)
  - **Metric upgrade (Step 3 핵심 발견)**: F1@5Å saturated under AB constraint (prec 0.833 / recall 1.0 universal). 결정 메트릭 = F1@4Å + vav1_rigid_body_offset + target_min_dist. F1@5Å은 sanity diagnostic으로만 보존.
  - Compute budget: 8 GPU × ~3 h ≈ 24 GPU-h. walltime cap 4 h (Phase 8/10 처리량 비례 + buffer 25%)
  - Fixed deps (Phase 8/10과 동일 고정):
    - FRAGMAP_CFG = configs/vav1_pipeline/fragmap_conditioning_target_t1_r10.yaml
    - BIOPHYS_CONFIG = examples/9nfr/biophysical_config_stage.yaml
    - SHARED_MSA = examples/vav1_shared_msa
    - REFERENCE_CIF = examples/9nfr/9NFR.cif
    - IMAGE_NAME = fksfold-boltz:glueplex-v2
  - 별도 condition / variant 없음 — 단일 AB pattern 139-batch 일회 commit
---

# AB pattern 139-batch scale-up — proper DC50 correlation + light filter recalibration prerequisite

## Purpose

Phase 10 Step 3 robustness gate 통과 (25/25 cells, 0/5 seed=16 outlier 신호).
24 GPU-h commit으로 AB pattern을 norm143_full 전 139 compound에 확장하여
(a) 5-compound hand-pick 너머 generalization 확인, (b) n=139 DC50 correlation의
proper statistical power, (c) Step 5 light filter recalibration data 확보.

## Current State

- Phase 8 (5395, 15 cells, seed=16): AB vav1_offset 3.39 ± 0.29 Å, F1@4Å +0.164 lift on 5/5
- Phase 10 Step 3 (5628+5631, 25 cells, 5 seed × 5 cpd): seed-invariant, F1@5Å=0.909 saturated, F1@4Å 0.75-0.857, vav1_offset 2.29-4.67 Å all sub-5Å. Verdict GO.
- norm143_full baseline (5284, 145 attempts → 139 PDB, seed=16): VAV1 mispositioning paradigm 17.4 Å mean
- Available YAML inputs: `examples/normtest_msa_patched_vav1_14_19/` (145 YAML) — 동일 compound 집합에 AB 변환 적용 필요
- DC50 GT: `outputs/_mmgbsa_staging/norm143_corrected_sources.tsv` (99 row), DC50 table는 norm143_full에 포함

## Assumptions And Questions

- assumptions:
  - AB YAML 생성기는 Phase 8 generator (`scripts/build_vav1_iface_anchor_yamls.py`) 패턴을 139-compound 확장. 새 generator 또는 기존 확장
  - 6 norm143_full OOM/MSA failure는 AB로 바꿔도 동일 실패 가능 (sequence 자체 문제) — 결과 PDB 기대 ~133-139
  - 단일 seed (16) 충분 — Step 3 robustness 결과 기반
  - MSA cache는 `examples/vav1_shared_msa`에 이미 구축됨 (norm143_full에서 재사용)
- open questions:
  - 139 compounds 중 hand-pick 5 외에서 AB pattern이 동등 효과 보일지 (Step 3는 best 5 + most DC50-potent에 편중)
  - F1@4Å이 DC50 (log) 와 correlation 보일지 — Phase 9 n=5 anecdotal (ρ=−0.205) → n=139 proper signal
  - VAV1_345 (Phase 9 outlier high F1, top DC50) 처럼 super-hit 더 발견될지
- tradeoffs:
  - 24 GPU-h commit. Multi-seed (120 GPU-h) 대비 single-seed (24 GPU-h) — Step 3 자료 기반 5× 절감 정당화
  - 4 h walltime cap. Phase 8 13.5 min/15-cell parallel, Phase 10 ~25 min/25-cell parallel ⇒ 139-cell ~2.5 h. 25% buffer + MSA cache warm-up

## Constraints

- allowed change scope:
  - 새 YAML 139개 (`examples/normtest_msa_patched_vav1_iface_AB_139/`)
  - 새 YAML generator (`scripts/build_ab_139batch_yamls.py`; Phase 8 generator로부터 derive)
  - 새 SLURM script (`workflow/slurm_vav1_ab_139batch.sh`; Phase 10 sweep script로부터 derive)
  - 새 evaluator (`analysis/fragmap_spectral_discriminator/src/eval_ab_139batch.py`; Step 3 evaluator의 single-seed flat 버전)
  - 새 report (`analysis/fragmap_spectral_discriminator/reports/ab_139batch_results.md`)
- forbidden change scope:
  - `src/boltz_extension/steering/*` 변경 금지 (code path 동결, Phase 8/10과 동일 binary)
  - production baseline YAML (`normtest_msa_patched_vav1_14_19/`) 변경 금지
  - mmgbsa 관련 파일 미접촉
  - F1@5Å threshold 변경 금지 (메트릭 자체는 보존; 단순히 decision driver에서 제외)
- external constraints:
  - SLURM submit: `sbatch` (ubuntu user, kim user availability 확인 후 routing), partition=gpu, qos=normal
  - 출력 dir: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/outputs/vav1_ab_139batch_<TS>/`
  - 로그: `/mnt/data/users/ubuntu/logs/vav1_ab_139batch_<jobid>.{out,err}`
  - 자원 예산: 8 GPU × ~3 h ≈ **24 GPU-h**, walltime cap 4 h

## Non-Goals

- light filter recalibration (Step 5, 별도 contract)
- DC50 correlation 분석 (Step 6, 별도 contract — 이 contract는 raw PDB + 기본 metric CSV까지)
- 새 AB variant 탐색 (C/D)
- CDK2/9D0W 또는 다른 target 진입
- MMGBSA stage 2-4 disposition (별도 slice)
- multi-seed extension (Step 3 robustness 결과로 unnecessary)

## Done When

1. 139 cells SUBMITTED (sbatch), 사용자 승인 후
2. ≥130/139 cells COMPLETED (≥93%; norm143_full 139/145 통과율 비례). 누락 cells 명시 + 원인 분류 (OOM, MSA missing, NaN 등)
3. Per-cell metrics CSV: `compound, ligand_target_contact_f1_4A, ligand_target_contact_f1_5A, vav1_rigid_body_offset, target_min_dist, crbn_align_rmsd, n_gen_4A, n_gen_5A, iptm, plddt, p_vav1_lig` — 모든 row non-NaN on F1@4Å + vav1_offset
4. Paired comparison report (baseline norm143_full vs AB-139): per-compound rows + summary stats:
   - vav1_rigid_body_offset: mean / median / pct < 5Å (target: all < 5Å)
   - F1@4Å: mean / median / win rate vs baseline (target: ≥ 80% compounds with lift ≥ 0)
   - target_min_dist: mean / median
5. DC50 stratified preview (n≈82 active subset): Spearman ρ(log10 DC50, F1@4Å) + ρ(log10 DC50, vav1_offset) — preliminary; full DC50 contract는 Step 6에서
6. Verdict / next action:
   - **GO** to Step 5 (light filter recal) if (a) ≥80% compounds vav1_offset < 5Å AND (b) F1@4Å win rate ≥ 60% vs baseline
   - **HOLD** if mixed (50-80% on either)
   - **STOP** if < 50% on either — AB pattern doesn't generalize beyond hand-picked 5
7. `.agent/status/fragmap.md` §Open Step 4 → §Closed, Step 5/6 actionable 갱신
8. `.agent/handoffs/CURRENT.md` remaining_actions, version 갱신

## Implementation Steps

1. **YAML 139개 생성**
   - `scripts/build_ab_139batch_yamls.py`: norm143_full 입력 YAML 145개 (`examples/normtest_msa_patched_vav1_14_19/`)을 읽어, 각각에 AB constraint 추가
   - 출력: `examples/normtest_msa_patched_vav1_iface_AB_139/VAV1_*_vav1_iface_AB.yaml`
   - Phase 8/10 5-compound YAML과 patch 구조 동일 (`contact:` block + `pocket:` extension)
   - verify: 동일 compound에 대해 Phase 10의 YAML과 byte-equal (5개 sample)

2. **SLURM script 작성**
   - `workflow/slurm_vav1_ab_139batch.sh`: Phase 10 multi-seed script에서 seed loop 제거, compound loop 확장
   - 헤더: `--gres=gpu:8 --cpus-per-task=64 --mem=256G --time=04:00:00`
   - 139 cells, 8 GPU parallel wave (≈18 waves), stagger 10s (docker init race 방지)
   - verify: `bash -n workflow/slurm_vav1_ab_139batch.sh`

3. **사용자 승인 게이트 (이 contract status: pending → approved 변경 필수)**
   - 사용자 확인 후 `sbatch workflow/slurm_vav1_ab_139batch.sh` (ubuntu or kim user, 가용성 확인)
   - SLURM ID 기록 → CURRENT.md verification_run
   - verify: `squeue -j <jobid>` RUNNING

4. **결과 evaluator**
   - `analysis/fragmap_spectral_discriminator/src/eval_ab_139batch.py`: Step 3 evaluator의 single-seed flat 버전
   - Input: 139 PDB + JSON predictions
   - Output: per-cell metrics CSV (≥130 rows non-NaN) + baseline paired CSV + summary JSON + verdict
   - DC50 merge: `outputs/_mmgbsa_staging/norm143_corrected_sources.tsv` 또는 norm143_full CSV에서 DC50 컬럼 join
   - verify: CSV row count ≥ 130, F1@4Å + vav1_offset non-NaN, DC50 join 성공

5. **Report 작성**
   - `analysis/fragmap_spectral_discriminator/reports/ab_139batch_results.md`
   - Paired comparison vs norm143_full baseline + DC50 stratified preview + Go/Hold/Stop verdict + Step 5/6 권고
   - verify: report markdown valid + verdict 명시

6. **Status doc + CURRENT.md 업데이트**
   - `.agent/status/fragmap.md` §Closed에 Step 4 결과 + §Open Step 5/6 status 갱신
   - `.agent/handoffs/CURRENT.md` remaining_actions, version 갱신
   - verify: `./scripts/handoff.sh claude` clean

## Change Discipline

- simplest adequate approach: Phase 8/10 setup 100% 재사용, compound 축만 139로 확장, seed 축 1로 collapse
- new abstractions introduced: 없음 (evaluator는 Step 3의 seed-axis 제거 버전)
- unrelated code touched: 없음
- pre-existing dead code noticed: `fragmap_steering.py.bak_20260520` (local-only backup, 무관)
- request-to-diff trace: 사용자 "현재 진행 파악 및 다음 설계" → Step 3 verdict GO → Step 4 contract draft

## Verification

- `python -c "import yaml; yaml.safe_load(open(f))"` × 139 YAML
- `bash -n workflow/slurm_vav1_ab_139batch.sh`
- 사용자 승인 후 `sbatch` → `squeue` RUNNING
- 완료 후 evaluator CSV ≥ 130 rows, F1@4Å + vav1_offset non-NaN
- Verdict GO/HOLD/STOP report에 명시

## Risks

- regression risk: AB constraint syntax이 Phase 8/10과 동일 → 낮음. 단 139개 중 일부 compound가 AB와 호환되지 않을 가능성 (e.g., 매우 작은 ligand, MSA 누락)
- integration risk: 139 cell 18-wave parallel submit이 docker init race로 OOM 가능 → Phase 10 stagger 10s + 1회 retry 적용 (5631 followup 패턴)
- hidden dependency risk: norm143_full에서 OOM/MSA 실패한 6 compound가 AB에서도 동일 실패 가능 → 139 → 133 effective sample size 가정
- statistical risk: DC50 correlation이 n=82 active subset에서도 약할 수 있음 (Phase 9 n=5 ρ=−0.205) → Step 6에서 full analysis, 본 contract는 preview만
- ceiling risk: F1@5Å saturation이 F1@4Å에서도 부분 나타날 수 있음 (3/5 cpd already 0.857 in Step 3) → vav1_offset이 primary discriminator로 fallback

## Rollback

- revert strategy: SLURM cancel `scancel <jobid>`, output dir cleanup
- containment strategy: 새 file은 별도 directory에 격리, 기존 production 경로 무수정. report만 status doc에 link

## Progress Log

- 2026-05-26: contract drafted (status: pending, Step 3 verdict GO 기반). 사용자 승인 게이트 대기
- 2026-05-26: 사용자 "진행" 승인 → status: approved. YAML generator (`scripts/build_ab_139batch_yamls.py`) 작성 → 145 YAMLs 생성 (Phase 10 reference 5/5 byte-equal sanity OK). SLURM script (`workflow/slurm_vav1_ab_139batch.sh`) 작성, `bash -n` OK, 5 deps OK. `sbatch` 제출 → **SLURM 5638** (host-10-0-3-160, 8 GPU idle node, R 0:09 / 3:59:51 walltime cap 4h). OUT_BASE: `outputs/vav1_ab_139batch_<TS>/`. Logs: `/mnt/data/users/ubuntu/logs/vav1_ab_139batch_5638.{out,err}`.
