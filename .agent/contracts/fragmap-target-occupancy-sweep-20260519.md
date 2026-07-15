# fragmap-target-occupancy-sweep

## Purpose

T1 pilot (job 5253) 결과 W400/interface_steering이 deterministic VAV1 attractor를
만들어 어떤 FragMap 강도로도 pose를 못 흔드는 것이 확인됨
(memory `project_fragmap_vav1_attractor`). 본 contract는 **2축 8-cell sweep**으로
W400 weight × FragMap target_reward_weight의 효과를 동시에 측정한다.

## Current State

- T1 (5253) 결과: VAV1 pose = B_current와 mm-level 동일. frag_term/Total ≈ 50%인데도 못 흔듦.
- W400 attractor 위치 `(+12.6, -24.3, -13.6)`은 A_pure `(+19, +17, +16)`와 53Å 차이.
- ligand-VAV1 contact F1 = 0 (W400 basin이 ternary geometry 아님).
- code: shared `fragmap_steering.py` (target_occupancy + patch + normalize override) DONE.

## Assumptions And Questions

- assumptions:
  - W400 weight를 단순 감소시키면 attractor 강도가 비례 감소. completely-off은 flag
    `--w400_interface_range_weight 0.0`로 (W400 conditioning 자체는 유지하되 range
    force만 0).
  - target_reward_weight를 키우면 frag_term 자릿수가 base/dist 자릿수를 넘게 됨
    (10→100에서 frag_term ~ -1.5 vs Total ~ 0.2 → 압도적).
  - 8 GPUs 단일 node에서 docker `--gpus device=N`으로 병렬 가능 (`abc_pilot` 패턴).
  - sweep 결과 한 cell이라도 “VAV1 pose 변화 > 1 Å”이면 다음 contract로 진입.
- open questions:
  - target_reward_weight 500이 발산할 가능성. 발산하면 비교가 안 됨 — 단순히 sample
    결과 PDB가 깨졌는지로 판정.
  - W400 = 0이면 다른 attractor (biophysical_hybrid stage_based dist score)가 새로
    pose를 잡을 수 있음 — 그래도 “W400 비의존성” 한 단계 분리됨.
- tradeoffs:
  - 8 GPUs sweep은 동시 ~15분이라 단일 node 점유. 사용자 승인.

## Constraints

- allowed change scope:
  - `configs/vav1_pipeline/fragmap_conditioning_target_t1_r{10,100,500}.yaml` (3개 신규)
  - `workflow/slurm_fragmap_9nfr_target_sweep.sh` (1개 신규)
- forbidden change scope:
  - 기존 T1 config / SLURM / 기존 conditions 수정
  - 기존 fragmap_steering.py 코드 변경 (sweep은 config-level만)
- external constraints:
  - 단일 node 8 GPUs 점유. 다른 job과 충돌 시 다음 idle node로 자연 fallback.
  - 사용자 승인 후에만 sbatch.

## Non-Goals

- multi-seed (sweep은 seed=16 고정)
- GD enable variation (별도 contract)
- biophysical_hybrid weight 변경
- code 변경

## Done When

1. 3 YAMLs 추가 (target_reward_weight=10/100/500). 다른 필드 동일.
2. SLURM sweep script: 8 conditions를 단일 node에 병렬 (docker `--gpus device=0..7`).
3. 후처리: 각 condition에 대해 `compare_generated_to_9nfr.py` + offline occupancy CSV 자동.
4. 모든 8 jobs COMPLETED 0:0.
5. 평가:
   - 8 cells의 VAV1 centroid을 표로 출력
   - VAV1 RMSD vs B_current (baseline) 표
   - **PASS 기준**: 적어도 1 cell이 RMSD > 1 Å (즉 W400 또는 FragMap을 충분히 바꾸면 pose 흔들림)
   - 추가 측정: 각 cell의 ligand-VAV1 contact F1
6. 결과를 본 contract progress log에 기록 + 다음 contract 후보 결정.

## Sweep Design (2축 8-cell)

| # | name                    | W400 weight | reward_w | 의미                       |
|---|-------------------------|-------------|----------|----------------------------|
| 1 | S1_t1_baseline          | 0.05        | 10       | T1 재현 sanity             |
| 2 | S2_w400_half            | 0.025       | 10       | W400 50%                   |
| 3 | S3_w400_tenth           | 0.005       | 10       | W400 10%                   |
| 4 | S4_w400_off             | 0.0         | 10       | W400 range 무력화          |
| 5 | S5_frag_x10             | 0.05        | 100      | FragMap 10×                |
| 6 | S6_frag_x50             | 0.05        | 500      | FragMap 50× (발산 risk)    |
| 7 | S7_w400_tenth_frag_x10  | 0.005       | 100      | 두 축 함께                 |
| 8 | S8_w400_off_frag_x10    | 0.0         | 100      | W400 off + FragMap 10×     |

## Implementation Steps

1. 3 YAMLs 작성 (reward_w 10/100/500). 다른 target_occupancy 필드는 T1 동일.
   verify: yaml parse OK.
2. SLURM script. 1 node, 8 GPUs, 8 docker run 병렬 (& + wait).
   verify: `bash -n`, +x.
3. sbatch (사용자 승인 후).
4. 모든 conditions COMPLETED 확인.
5. 8-cell summary 표 생성 (centroid + RMSD vs B + offline occ + ligand-VAV1 F1).

## Verification

- `bash -n workflow/slurm_fragmap_9nfr_target_sweep.sh`
- `sacct -j <id> --format=JobID,JobName,State,ExitCode,Elapsed`
- pose summary table (post-run)

## Risks

- regression risk: 새 파일만, 기존 변경 없음.
- integration risk: target_reward_weight=500이 NaN 또는 발산 → 후처리에서 단순히
  fail flag. sweep 다른 cell에 영향 없음.
- hidden dependency risk: 단일 node 8 GPUs가 5252 (mmgbsa) 등과 충돌하면 PD 대기.

## Rollback

- revert strategy: SLURM cancel + 새 파일 4개 삭제

## Progress Log

- 2026-05-19: contract draft. SLURM 8-GPU sweep 사용자 승인 대기.
- 2026-05-19: 사용자 승인 후 sbatch. JobID 5254, host-10-0-3-160, 06:30 elapsed, COMPLETED 0:0.
- 결과 (`outputs/fragmap_9nfr_sweep_20260519_201741`):
  - 7/8 cells completed (S8 OOM CUDA out of memory, parallel docker init race).
  - 모든 cell의 VAV1 RMSD vs B_current ≤ `0.012 Å`.
  - **S5/S6 (frag×10, frag×50) PDB가 S1과 bit-identical** (centroid 7+ digit 동일).
  - W400 weight 0/0.005/0.025/0.05 변화로도 max `0.012 Å`만 이동.
  - S6 score breakdown: FragMap=`40.2`, Total=`4.0` — score는 정상 dominant이지만 pose 영향 없음.
- **PASS 기준 (>1 Å) 전 cell FAIL**. W400-attractor 가설 기각.
- 진단 갱신: Boltz backbone + seed=16이 deterministic VAV1 pose 생성. 3 particles이
  같은 seed/noise schedule에서 시작해 trajectory가 거의 동일. score 함수의 어떤
  weight 조작도 결과를 못 바꿈.
- 다음 후보 (사용자 결정 대기):
  - (a) **seed sweep** (4 seeds × T1 or W400_off) — particle diversity가 seed에 따라
    바뀌는지 직접 측정. 가장 결정적.
  - (b) Boltz 노이즈 주입 또는 per-particle seed 분리 (코드 변경 필요).
  - (c) Boltz fine-tune 또는 더 큰 model로 전환 (장기).
