# fragmap-target-occupancy-pilot-t1

## Purpose

이전 contract `fragmap-target-occupancy-scale-and-patch-20260519`에서
target_occupancy mode가 normalize=False + softmax patch에서 occ ≈ `0.077`,
A_pure 대비 `range/mean=73%`로 신호 살아남을 확인. 이제 generation에 실제로
넣어 VAV1 pose가 흔들리는지 검증.

본 contract는 **단일 조건 T1 (resampling-only, target_occupancy)** 1 GPU pilot.
T2/T3/T4 + multi-seed는 의도적으로 제외.

## Current State

- 코드: shared `fragmap_steering.py` (mode + parser + patch + normalize override 완료)
- 진단: `analysis/fragmap_target_occupancy_offline_diagnostic.py`
- 기존 baseline (`outputs/fragmap_9nfr_abc_20260511_143235/B_current`)에서
  VAV1-ligand contact F1 = 0.0, CRBN-VAV1 interface F1 = 0.0.
- 기존 ternary metric 평가 스크립트:
  `analysis/compute_ternary_metrics.py`, `analysis/compare_generated_to_9nfr.py`
- SLURM image: `fksfold-boltz:glueplex-v2` (이미 host에 load됨)

## Assumptions And Questions

- assumptions:
  - 기존 9NFR generation 파이프라인(W400/biophysical_hybrid/interface_gd) 그대로
    두고, `fragmap_conditioning`만 새 T1 config로 교체. 다른 변수 통제.
  - seed=16 (이전 5158/5166과 동일) — 결과 분산 통제.
  - `target_reward_weight=10`로 시작. offline occ `~0.077` × 10 = `~0.77`이 base
    biophysical scores 자릿수와 같아짐. 과하면 resampling이 target 한쪽으로 치우침.
  - GD off (`gd_scale=0`). target_occupancy mode는 contract에서 GD를 명시적으로 zero.
- open questions:
  - target_reward_weight `10`이 과한지 약한지 — pilot 결과로 판단.
  - resampling이 너무 강하면 ligand pose가 무너질 수 있음. ligand metric
    (centroid/NN RMSD)을 보조로 모니터.
- tradeoffs:
  - 단일 seed는 noise 크지만, 1차 “움직이는가/안 움직이는가” 확인이 목적이라
    multi-seed는 다음 contract.

## Constraints

- allowed change scope:
  - `configs/vav1_pipeline/fragmap_conditioning_target_t1.yaml` (신규)
  - `workflow/slurm_fragmap_9nfr_target_t1.sh` (신규)
  - 다른 코드/설정 변경 금지
- forbidden change scope:
  - SLURM이 아닌 호스트에서 generation 직접 실행 (memory `feedback_slurm_usage`)
  - 기존 SLURM script 수정
  - multi-seed/T2-T4 추가 (별도 contract)
  - configs/vav1_pipeline의 기존 YAML 수정
- external constraints:
  - `gpu` partition idle 노드 1개 필요. 없으면 PD 상태에서 대기.
  - 사용자 승인 후에만 sbatch.

## Non-Goals

- T2/T3/T4 conditions
- multi-seed
- target_reward_weight ablation
- diagnostics CSV 통합 (자동 후처리만)

## Done When

1. T1 config YAML 작성:
   - `mode: target_occupancy`
   - `target_chain: B`, alignment offsets CRBN +45 / VAV1 +781
   - favorable_channels mixture (hydrophobe/aromatic/heteroaromatic/amide_acceptor/amide_donor/polar)
   - `target_patch_aggregation: softmax`, `target_patch_temperature: 0.5`
   - `target_probability_normalize: false`
   - `target_reward_weight: 10`, `target_exclusion_penalty_weight: 2`
   - `gd_scale: 0`, `w_frag: 0.3`, `start_t: 0.5`
2. SLURM script:
   - 단일 condition `T1_target_occupancy_resampling`
   - 1 GPU, seed=16, sampling_steps=50, num_particles=3
   - 기존 W400/biophysical/interface 인자 그대로 (probability_pilot와 동일)
   - 자동 후처리:
     - `compare_generated_to_9nfr.py` (centroid/NN RMSD)
     - `compute_ternary_metrics.py` (contact F1)
     - `fragmap_target_occupancy_offline_diagnostic.py` (post-hoc score)
3. SLURM 제출 후 job COMPLETED (exit 0).
4. 결과 비교:
   - VAV1-ligand contact F1이 B_current (=0) 대비 > 0이거나, 또는 동일하지만
     occupancy_reward가 B_current 대비 의미 있게 변화 (range/mean > 5%).
   - **PASS 기준**: VAV1-ligand contact F1 > 0 OR occupancy_reward Δ > 5%.
   - **FAIL** (signal 들어가도 pose 안 변함): 다음 contract는 GD weak 또는
     target_reward_weight 상향.

## Implementation Steps

1. T1 YAML 작성. probability c7 yaml을 베이스로 fragmap_conditioning 블록만 교체.
   verify: yaml load, `from_dict`로 parse 성공.
2. SLURM script 작성. probability_pilot.sh 패턴 답습. 단일 condition + 후처리 추가.
   verify: `bash -n`, +x 권한.
3. sbatch (사용자 승인 후).
   verify: `squeue -j` running → COMPLETED.
4. 후처리 CSV 자동 생성 확인.
   verify: `*/diagnostics/T1_*.csv` 존재, ternary_metrics 출력.

## Change Discipline

- simplest adequate approach: 새 파일 2개만 추가, 기존 SLURM/configs 미수정
- new abstractions introduced: 없음
- unrelated code touched: 없음
- request-to-diff trace: plan todo 4-5 일부 (단일 condition pilot)

## Verification

- yaml parse: `python3 -c "import yaml; yaml.safe_load(open('configs/.../fragmap_conditioning_target_t1.yaml'))"`
- shell syntax: `bash -n workflow/slurm_fragmap_9nfr_target_t1.sh`
- 실행 후: `sacct -j <id> --format=JobID,JobName,State,ExitCode`
- 후처리 CSV 자동 생성 (compare + ternary + offline diagnostic)

## Risks

- regression risk: 기존 SLURM/configs 안 건드림. 새 파일만.
- integration risk: target_occupancy mode가 실제 docker container 안의 boltz
  파이프라인에서 처음 동작. 코드는 mount하지만 컨테이너 내부 import 경로가 달라
  파싱 실패 가능성. 1단계에서 yaml parse는 호스트에서 확인했더라도 컨테이너
  안에서는 다른 결과 가능 — running 5분 이내에 fragmap_conditioning 로딩 단계
  로그 확인.
- hidden dependency risk: VAV1 chain id가 `1` (B)이 아니라 다른 값이면 target
  atoms 0 → energy 0 → 무신호. config의 `vav1_asym_id=1`로 명시.

## Rollback

- revert strategy: SLURM job cancel + 새 파일 2개 삭제
- containment strategy: 단일 condition 1 GPU 12-20분 자원만 사용

## Progress Log

- 2026-05-19: contract draft. SLURM 제출 사용자 승인 대기.
- 2026-05-19: 사용자 승인 후 sbatch. JobID 5253, host-10-0-5-232, 10:38 elapsed, COMPLETED 0:0.
- 결과 (`outputs/fragmap_9nfr_target_t1_20260519_105341`):
  - centroid=`0.8881`, NN RMSD=`1.6868` — **B_current 7+ digit identical**
  - posthoc occupancy_reward=`0.08165` — B와 동일 (Δ=0)
  - FragMap 실제 적용 확인됨 (log: `FragMap=-0.5412 → -0.3432` steps 24-49)
  - resampling 9회 실행됨
- **PASS 기준 둘 다 FAIL**:
  - VAV1-ligand contact F1 > 0 → pose ≡ B → F1 그대로 0 ✗
  - occupancy_reward Δ > 5% → Δ = 0% ✗
- 해석: target_occupancy potential은 정상 동작했지만 **3 particles 사이 VAV1 placement
  분산이 너무 작아서 resampling이 어느 particle을 골라도 같은 pose**. score 함수가 아니라
  particle diversity 문제로 보임.
- 다음 단계 후보: (a) per-particle FragMap variance 진단 (zero-compute), (b) num_particles
  상향 또는 seed 변경, (c) target_reward_weight 추가 상향, (d) weak GD enable. 메모리
  `feedback_compute_scaling`에 따라 (a) zero-compute 진단을 먼저.
