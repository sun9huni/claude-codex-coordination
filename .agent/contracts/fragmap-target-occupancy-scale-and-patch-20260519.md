# fragmap-target-occupancy-scale-and-patch

## Purpose

Offline diagnostic (2026-05-19, `/tmp/fragmap_target_occupancy_offline.csv`)에서
`mode: target_occupancy`가 정상 동작하지만 두 가지 명백한 한계가 드러났다:

1. **scale 문제**: `occupancy_reward` ~`2.1e-6`. `feature_probability_normalize=True`
   기본값으로 전역 normalize되어 local mass가 희석. `exclusion_penalty` ~`0.58`로
   energy를 사실상 지배 → reward term이 무력화.
2. **patch 없음**: 511 VAV1 heavy atoms 전체 평균이라 “좋은 contact patch 일부”가
   있어도 mean이 흐려짐. plan todo 2 (`patch-aggregation`).

본 contract는 plan todo 2 (`patch-aggregation`)와 score scale calibration을 한
범위로 묶는다. todo 3 (diagnostics CSV 통합), todo 4 (configs), todo 5 (SLURM pilot)는
**의도적으로 제외**.

## Current State

- 코드: shared `fragmap_steering.py` (contract `fragmap-target-occupancy-20260519`로 추가됨)
  - `mode: target_occupancy` parser + scoring branch + smoke + backward-compat ✓
  - `target_atom_subset: heavy|ca`, `target_local_radius`, `favorable_channels` mixture
  - normalize/temperature는 `feature_probability` 경로의 `_grid_to_probability` 재사용
- 진단: `analysis/fragmap_target_occupancy_offline_diagnostic.py` (zero-compute)
- 결과: 13 conditions, B/C/D/E/F/C2/C6/C7-9 모두 occ ≈ `2.156e-6`로 동일.
  A_pure만 occ `1.746e-6`. 즉 score는 'steering on/off'만 구분하고 'which steering'은 무차별.

## Assumptions And Questions

- assumptions:
  - patch 정의는 residue 단위. residue-internal heavy atoms의 score를 patch로 묶고,
    chain 내 patches에 대해 best-of-patch 또는 softmax-of-patch reduction.
  - normalize off mode를 추가하되 기본은 ON 유지 (backward-compat). `target_occupancy`
    config에서 명시적으로 끌 수 있게 `target_probability_normalize: false`.
  - temperature는 `feature_map_temperature`를 그대로 reuse. 후속 contract에서 분리.
- open questions:
  - patch reduction이 best-of-patch이면 미분 안정성 문제 (max). softmax-of-patch이
    더 안전. 둘 다 옵션화하고 default는 softmax.
  - top-k voxel mass(grid-side aggregation)와 patch reduction(atom-side aggregation)이
    둘 다 필요한가? 본 contract는 patch 쪽만. grid-side는 후속.
- tradeoffs:
  - normalize off는 절대값을 키우지만 NPZ 사이 비교성을 깸. 본 mode 내부에서만
    영향 → 다른 모드에 영향 없음.

## Constraints

- allowed change scope:
  - `src/boltz_extension/steering/fragmap_steering.py` — config 추가, scoring branch 확장
  - `analysis/fragmap_target_occupancy_offline_diagnostic.py` — 새 옵션 노출
- forbidden change scope:
  - 기존 mode (`atom`/`feature`/`feature_probability`)의 default 동작 변경
  - `biophysical_scorer.py`, `interface_steering_utils.py` (별도 contract)
  - SLURM 제출, configs/vav1_pipeline 추가 (별도 pilot contract)
- external constraints:
  - shared repo만 수정. local은 다음 mirror 단계에서.
  - 사용자 승인 없이는 어떠한 SLURM도 제출 금지.

## Non-Goals

- diagnostics CSV / steering 로그 보강 (plan todo 3 — 별도 contract)
- T1–T4 config 작성 (plan todo 4)
- multi-seed SLURM pilot (plan todo 5)
- grid-side top-k voxel aggregation
- biophysical_scorer 통합

## Done When

1. Config 추가:
   - `target_patch_aggregation`: `none | softmax | bestof` (default `softmax`)
   - `target_patch_temperature`: float, default `0.5`
   - `target_probability_normalize`: Optional[bool] (None → inherit
     `feature_probability_normalize`; explicit False → disable for target_occupancy only)
   - parser ValueError on unknown aggregation 값.
2. Scoring branch에서 patch 분기:
   - patch는 `(chain_id, residue_index)` 기준으로 target heavy atoms를 그룹핑.
   - 각 patch마다 local probability mass mean (atom-내 평균).
   - reduction:
     - `none`: 기존처럼 전체 atom mean
     - `softmax`: `softmax_temperature` 기반 weighted mean
     - `bestof`: `torch.max` (미분 안정성을 위해 softmax(τ→0) approx 사용)
3. `target_probability_normalize=False`일 때 `_grid_to_probability`를 normalize 없이
   호출 (transient grid 캐시는 별도 키로 분리하여 다른 mode와 충돌 방지).
4. Offline diagnostic에 `--patch-mode {none,softmax,bestof}` + `--no-normalize` 추가.
   기존 13 conditions에 대해 두 옵션 조합으로 occupancy_reward 측정 후 비교 가능.
5. 검증:
   - `softmax` 또는 `bestof` 모드에서 occupancy_reward의 절대값이 기존 `2.1e-6`
     대비 최소 `100×` 이상 (목표 `~1e-3`).
   - 또한 13 conditions 사이 `occupancy_reward` range가 mean의 `> 5%`로 벌어져야 함
     (조건 구분 가능성). 만약 range가 여전히 mean 대비 작으면 contract 결과는 “fail
     to discriminate”로 기록하고 후속 grid-side aggregation contract 필요.
   - 기존 mode 4종 deterministic + finite (회귀).
   - smoke PASS, `target_grad_norm > 0`.

## Implementation Steps

1. 현재 scoring branch와 helper 캐시 키 확인. `_prob_grid_cache`가 normalize 토글에
   대해 안전한지 점검.
   verify: 메모로 키 충돌 가능성 정리.
2. config 필드 추가 + parser 분기. 잘못된 값 ValueError.
   verify: 단위 테스트 4종 (unknown aggregation, both None/True/False normalize, temperature<=0).
3. patch grouping helper. `(chain_id, resi) -> [atom_idx]` from
   `ResidueAtomMapper.mapping`. fallback when mapping empty.
   verify: 더미 feats에서 grouping count 확인.
4. scoring 분기 확장:
   - per-patch atom mean → per-channel weighted sum → patch score
   - patch scores를 `softmax(τ)` 또는 `max` reduction
   - normalize=False면 별도 cache로 unnormalized prob grids 사용
   verify: smoke + offline diagnostic 두 모드 모두 occ > 1e-4.
5. 회귀: 기존 4 modes deterministic, target_occupancy `none` mode = 기존 결과
   재현 (diff < 1e-6).
   verify: 자동 비교 출력.

## Change Discipline

- simplest adequate approach: 기존 `_per_sample_energy` target_occupancy 분기에
  patch loop만 추가. helper 1개 (`_patch_indices_from_mapper`) 추가.
- new abstractions introduced: patch grouping helper (단일 함수)
- unrelated code touched: 없음
- pre-existing dead code noticed: TBD
- request-to-diff trace: plan todo 2(`patch-aggregation`) + offline 진단의 scale issue.

## Verification

- `python3 -m py_compile src/boltz_extension/steering/fragmap_steering.py`
- `python3 analysis/fragmap_target_occupancy_smoke.py`
- `python3 analysis/fragmap_target_occupancy_offline_diagnostic.py --patch-mode softmax`
- `python3 analysis/fragmap_target_occupancy_offline_diagnostic.py --patch-mode bestof --no-normalize`
- 기존 4 modes 회귀 (cluster_then_grid/grid/feature/feature_probability)

## Risks

- regression risk: cache 키 분리 잘못하면 normalize 켠 상태에서 다른 mode에 영향.
  4단계에서 명시적 cache 키 검증.
- integration risk: bestof 미분 불안정 → softmax(τ→0) 사용. default softmax.
- hidden dependency risk: 일부 NPZ에 residue grouping이 의미 없을 수 있음
  (atom-level 만). 진단에서 grouping count 0이면 자동 fallback `none`.

## Rollback

- revert strategy: 단일 파일 patch + 진단 스크립트만 revert
- containment strategy: `target_patch_aggregation` 기본값을 `softmax`로 두지만,
  명시적 `none`이면 본 contract 이전 동작과 동일.

## Progress Log

- 2026-05-19: contract draft. 승인 대기.
- 이전 contract `fragmap-target-occupancy-20260519`에서 mode 추가 후 offline
  진단에서 scale & discrimination 문제 발견 → 본 contract로 분리.
- 2026-05-19: 사용자 승인 후 5/5 todo 완료.
  - config 4종 추가: `target_patch_aggregation`, `target_patch_temperature`,
    `target_probability_normalize` (override), `_patch_indices_from_mapper` helper
  - parser ValueError 2종 (unknown aggregation / temperature ≤ 0) 확인
  - patch grouping helper `_target_patches_from_feats` 추가 (mapping 없으면 fallback)
  - scoring branch: per-atom mixture overlap → per-residue patch mean → softmax/bestof/none
  - normalize cache 분리: `_prob_grid_cache_target` (target_occupancy 전용)
  - offline diagnostic 확장: `--patch-mode`, `--patch-temperature`, `--no-normalize`
- 검증 결과 (13 conditions, B/C2/C6/C7-9):
  - normalize=True + softmax: occ mean=`2.4e-6`, range=`7.4e-7` — 여전히 작음 (Done #5 미충족)
  - normalize=False + none:    occ mean=`0.0294`, range=`5.8e-3` (range/mean 20%) — 신호 살아남
  - normalize=False + softmax: occ mean=`0.0773`, range=`5.6e-2` (range/mean 73%) — Done #5 충족 (≥1e-3 ✓, >5% ✓)
  - normalize=False + bestof:  occ mean=`0.749`, range=`0.71`   (range/mean 95%) — 가장 강한 signal
- 한계: 12개 steered conditions 사이 occ는 여전히 동일 (~0.0817 softmax). 즉 score는
  "steering on/off"는 구분하나 "어떤 steering인가"는 무차별. VAV1 pose가 거의 안
  변했기 때문 — score 문제가 아니라 generation 쪽 문제.
- 4 legacy modes regression diff=0, target_occupancy `none` mode deterministic, smoke PASS.
- 변경 파일:
  - `src/boltz_extension/steering/fragmap_steering.py`
  - `analysis/fragmap_target_occupancy_offline_diagnostic.py`
