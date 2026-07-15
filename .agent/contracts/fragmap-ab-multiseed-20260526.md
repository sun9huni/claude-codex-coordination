---
status: approved
slice: fragmap
topic: ab-multiseed
date: 2026-05-26
owner: claude
approved_by: user (2026-05-26, said "진행" after 정합성 review + GPU efficiency check)
decisions:
  - 5 seeds × 5 compounds = 25 cells (single condition = AB pattern)
  - Seeds: 16 (Phase 8 base), 100 (Y5/S3 historic), 1000 (S6 historic), 2024 (S7 historic), 7 (new probe)
  - Compounds: VAV1_345, VAV1_489, VAV1_209, VAV1_292, VAV1_411 (Phase 8과 동일)
  - Pattern: AB = Boltz YAML `contact:` `[A,106]↔[B,35]` + `[A,352]↔[B,16]` + pocket VAV1 32-41 + CRBN 104-109 + 기존 14-19 / 305-355
  - npart=8, λ=20 (P7 setup, Phase 8과 동일)
  - 8-GPU parallel (Phase 8 setup 재사용, 1 GPU serial은 wall 6× 느림으로 비효율)
  - Fixed deps (Phase 8과 동일하게 고정):
    - FRAGMAP_CFG = configs/vav1_pipeline/fragmap_conditioning_target_t1_r10.yaml
    - BIOPHYS_CONFIG = examples/9nfr/biophysical_config_stage.yaml
    - SHARED_MSA = examples/vav1_shared_msa
    - REFERENCE_CIF = examples/9nfr/9NFR.cif
    - IMAGE_NAME = fksfold-boltz:glueplex-v2
  - 별도 condition / variant 없음 — robustness만 측정
---

# AB pattern multi-seed robustness — confirm seed=16 not lucky before 139-batch

## Purpose

Phase 8 SLURM 5395에서 AB pattern이 5/5 compounds에서 F1@5Å 0.909, vav1_offset 3.39 ± 0.29 Å (80% reduction)
달성했지만 단일 seed=16. 24 GPU-h commit (Phase 10 Step 4 = 139-batch scale-up) 전에 seed dependence
확인 필요. Static §Pareto front 8-seed sweep에서 5/8이 baseline barrier 깬 robustness 있었으나
AB pattern은 그 후 추가된 constraint이므로 별도 검증 필요.

## Current State

- Phase 8 결과 (단일 seed=16, AB): VAV1_345/489/209/292/411 각 5/5 cell이 F1@5Å > 0.85
- Phase 9 cross-target test에서 wrongAB도 F1 안 깸 (CDK2 hinge prior 지배) → AB pattern의
  target-dependent behavior 확인됨. VAV1에 한해 paradigm 유지
- Phase 10 Step 4 (139-batch, ~24 GPU-h) 진입 전 robustness 게이트
- 가용 자원: workspace shared (ubuntu submit) + kim user output dir
- YAML 생성기: `scripts/build_vav1_iface_anchor_yamls.py` (Phase 8) 이미 존재

## Assumptions And Questions

- assumptions:
  - Phase 8 P7 setup (npart=8, λ=20, corrected pocket 14-19) 그대로 사용
  - AB constraint이 Boltz YAML parser에서 seed-invariant하게 적용됨 (Phase 8 5/5에서 검증된 전제)
  - MSA cache가 seed independent (compound-only key)
- open questions:
  - seed=16이 Phase 6 Pareto sweep에서 5/8 robust 그룹 안이었던 것의 의미: Phase 10 다른 seed들도 비슷 robust일지
  - VAV1_411 (best DC50 1.99 nM)이 Phase 8에서 가장 큰 lift (+0.286 F1@4Å)였는데 seed=16 effect인지 compound effect인지
- tradeoffs:
  - 1 GPU-h 투자 vs 24 GPU-h scale의 사전 보험 — 작은 보험료
  - 5 seeds로 std 추정의 power 제한 (sample stats); ≥ 3/5 seeds win criterion으로 보완

## Constraints

- allowed change scope:
  - 새 YAML 25개 (`examples/normtest_msa_patched_vav1_iface_AB_seedsweep/`)
  - 새 SLURM 1개 (`workflow/slurm_vav1_ab_multiseed.sh`, Phase 8 sweep script에서 derive)
  - YAML 생성 helper (`scripts/build_ab_multiseed_yamls.py` 또는 기존 generator 확장)
  - 새 evaluator (`analysis/fragmap_spectral_discriminator/src/eval_ab_multiseed.py`)
  - report (`analysis/fragmap_spectral_discriminator/reports/ab_multiseed_robustness.md`)
- forbidden change scope:
  - `src/boltz_extension/steering/*` 변경 금지 (code path 동결, Phase 8과 동일 binary)
  - production YAML 변경 금지 (baseline `normtest_msa_patched_vav1_14_19/` 유지)
  - mmgbsa 관련 파일 미접촉
- external constraints:
  - SLURM submit은 `sbatch` (ubuntu user, kim 사용 중), partition=gpu, qos=normal
  - 출력 dir: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/outputs/vav1_ab_multiseed_<TS>/`
  - 로그: `/mnt/data/users/ubuntu/logs/vav1_ab_multiseed_<jobid>.{out,err}`
  - 자원 예산: 8 GPU × ~25 min wall ≈ **~3.3 GPU-h** (Phase 8 실측 1.8 GPU-h/15-cell 비례 환산). walltime cap 45 min

## Non-Goals

- 139-batch scale-up (Phase 10 Step 4 별도 contract)
- light filter recalibration (Step 5)
- DC50 correlation at n=139 (Step 6)
- 새 AB variant (C/D) 탐색
- CDK2 또는 다른 target 진입
- mmgbsa stage 2-4 disposition (별도 slice)

## Done When

1. 25 cells COMPLETED (5 × 5), OOM/MSA fail은 1회 retry 후에도 실패시 누락 명시
2. 셀당: F1@5Å, F1@4Å, vav1_rigid_body_offset, ligand_target_contact_f1, tgt_min_dist 측정 → CSV
3. Robustness 표 작성: compound별 row (5 seeds 평균 ± std), seed별 column
4. **Go criterion**: median F1@5Å lift ≥ +0.10 vs Phase 8 baseline on ≥ 4/5 compounds × ≥ 3/5 seeds
   → Step 4 (139-batch) contract 작성 권고
5. **Hold criterion**: mixed signal (3/5 compounds robust, 2/5 seed-sensitive)
   → robust subset only 139-batch + 별도 분석
6. **Stop criterion**: seed=16이 outlier (median lift < +0.05 across other 4 seeds)
   → Phase 8 결과 재검증, AB pattern hypothesis 재평가
7. Report 작성: 결정 + 다음 단계 권고
8. `.agent/status/fragmap.md` §Open / §Closed 갱신

## Implementation Steps

1. **YAML 재사용 (생성 불필요)**
   - Phase 8 AB YAML 5개 (`examples/normtest_msa_patched_vav1_iface_AB/VAV1_{345,489,209,292,411}_vav1_iface_AB.yaml`) 그대로 사용
   - Seed는 CLI `--seed` 인자로 변경되므로 YAML 자체는 seed-invariant
   - verify: `for f in $SHARED/examples/normtest_msa_patched_vav1_iface_AB/*.yaml; do python3 -c "import yaml; yaml.safe_load(open('$f'))"; done` 5/5 OK

2. **SLURM script 작성**
   - `workflow/slurm_vav1_ab_multiseed.sh` (`slurm_vav1_iface_anchor_sweep.sh`에서 derive)
   - 헤더: `--gres=gpu:8`, `--cpus-per-task=64`, `--mem=256G`, `--time=00:45:00` (Phase 8 실측 13.5 min, 25 cells 추정 ~25 min)
   - 8 GPU parallel, 25 cells (5 compound × 5 seed), stagger 10s (MSA race 방지)
   - 셀 타깃: 각 셀이 (compound, seed) 쌍을 받아 `--seed <seed>` 적용
   - 출력 dir: `/mnt/data/users/kim/fksfold_outputs/vav1_ab_multiseed_<TS>/<compound>_seed<seed>/`
   - verify: `bash -n workflow/slurm_vav1_ab_multiseed.sh`

3. **사용자 승인 게이트** (이 contract status → approved 변경 필수)
   - 사용자 확인 후 `sbatch workflow/slurm_vav1_ab_multiseed.sh` (ubuntu user)
   - SLURM ID 기록 → `.agent/handoffs/CURRENT.md` verification_run
   - verify: `squeue -j <jobid>` RUNNING

4. **결과 evaluator**
   - `analysis/fragmap_spectral_discriminator/src/eval_ab_multiseed.py` (Phase 8 `eval_vav1_iface_sweep.py`에서 derive)
   - Input: 25 PDB + JSON predictions
   - Output: per-cell metrics CSV + 5×5 표 + Go/Hold/Stop verdict
   - verify: CSV 25 rows, no NaN on F1 columns

5. **Report 작성**
   - `analysis/fragmap_spectral_discriminator/reports/ab_multiseed_robustness.md`
   - 표 + Go/Hold/Stop verdict + Step 4 권고 (proceed / partial / stop)
   - verify: report markdown valid + verdict 명시

6. **Status doc + CURRENT.md 업데이트**
   - `.agent/status/fragmap.md` §Closed에 Phase 10 Step 3 entry 추가
   - §Open Step 4 status 갱신 (proceed/partial/stop 반영)
   - `.agent/handoffs/CURRENT.md` remaining_actions 갱신
   - verify: `./scripts/handoff.sh claude` clean

## Change Discipline

- simplest adequate approach: Phase 8 setup 100% 재사용, seed loop만 추가
- new abstractions introduced: 없음 (evaluator는 기존 Phase 8 evaluator의 seed-axis 확장)
- unrelated code touched: 없음
- pre-existing dead code noticed: `fragmap_steering.py.bak_20260520` (local-only backup, 무관)
- request-to-diff trace: 사용자 "다음 계획 세워줘" → Phase 10 plan → Step 3 = robustness gate for Step 4

## Verification

- `python -c "import yaml; yaml.safe_load(open(f))"` × 25 YAML
- `bash -n workflow/slurm_vav1_ab_multiseed.sh`
- After SLURM: `squeue -u kim -j <jobid>` COMPLETED 25/25 (또는 부분 + retry log)
- After eval: CSV row count = 25, F1@5Å column non-null on ≥ 23/25
- Go/Hold/Stop 판정 결과가 report에 명시

## Risks

- regression risk: AB constraint syntax이 Phase 8과 동일 → 낮음
- integration risk: 25 cell parallel submit이 docker init race로 OOM 가능 → stagger 10s + 1회 retry
- hidden dependency risk: MSA cache이 seed independent라는 전제가 깨지면 seed effect가 MSA 변동으로 오염 → 1차 결과에서 plddt/iptm seed-variance 확인 (compound 내 std가 큰지)

## Rollback

- revert strategy: SLURM cancel `scancel <jobid>`, output dir `rm -rf /mnt/data/users/kim/fksfold_outputs/vav1_ab_multiseed_<TS>/` (kim ownership 필요)
- containment strategy: 새 file은 별도 directory에 격리, 기존 production 경로 무수정. report만 status doc에 link

## Progress Log

- 2026-05-26: contract drafted (status: pending, 사용자 승인 대기)
- 2026-05-26: 정합성 review + GPU 효율 분석 → 4건 정정 (GPU-h 추정, walltime, deps 명시). status: approved
- 2026-05-26: kim 사용 중 → ubuntu user routing (output/log paths swap). `sbatch slurm_vav1_ab_multiseed.sh` 제출 → **SLURM 5628** (host-10-0-5-232, R 0:08 / 44:52)
- 2026-05-26: AB YAML 5/5 재사용 확인 (3 seq + 4 constraint), bash -n OK, dep 5/5 OK
- 2026-05-26: SLURM 5628 TIMEOUT @ 00:45:17 (waves 1+2+3 finished 24/25 cells just before walltime kill, wave 4 = VAV1_411_seed7 not started). Followup SLURM 5631 COMPLETED @ 12:54 — 9 cells (8 wave-3 safety re-runs + VAV1_411_seed7). 25/25 unique cells assembled across both dirs.
- 2026-05-26: Eval — F1@5Å = 0.909 across all 25 cells (recall=1.0, prec=0.833, seed std=0.000). vav1_rigid_body_offset mean 2.91–3.97 Å per compound (std 0.21–0.76). Median F1@5Å lift +0.242 to +0.338 vs baseline on 5/5 cpd × 5/5 seeds. **VERDICT: GO** (seed=16 outlier falsified). Caveat: F1@5Å saturated at 0.909 ceiling; F1@4Å minor seed sensitivity (std 0–0.059). Report: `analysis/fragmap_spectral_discriminator/reports/ab_multiseed_robustness.md`. status: completed.
