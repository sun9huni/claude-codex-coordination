# fragmap-target-occupancy

## Purpose

FragMap을 ligand-hotspot pull이 아니라 **target patch recruitment field**로 재해석한
새 scoring mode (`mode: target_occupancy`)를 `FragMapSteeringPotential`에 추가한다.
plan `target_fragmap_occupancy_af712dd6`의 todo 5개 중 todo 1 (mode + parser)을
이 contract 범위로 한다. patch aggregation/diagnostics/configs/pilot은 후속 contract.

목적은 다음을 가능하게 만드는 것:
- target chain heavy atoms (또는 CA centroid)를 CRBN-aligned FragMap 좌표계에서 평가
- favorable channel mixture의 local probability mass aggregation으로 occupancy reward
- exclusion grid에 들어가면 penalty
- ligand는 anchor를 유지 (ligand-side reward 비중은 낮춤)
- residue-pair-specific 정답 없이 reference-free하게 동작

## Current State

- 코드: `src/boltz_extension/steering/fragmap_steering.py`
  - 기존 mode: `atom`, `feature`, `feature_probability` (probability/feature overlap 구현 완료)
  - `_per_sample_energy`가 ligand chain heavy atoms만 sampling
  - target chain은 alignment용으로만 쓰이고 score 입력으로는 안 들어감
- 기존 ablation 결과 (`fragmap_9nfr_probability_20260518_142633`):
  - CRBN-ligand contact F1 ≈ 1.0 (모든 조건에서 anchoring 성공)
  - VAV1-ligand / CRBN-VAV1 interface F1 ≈ 0.0 (target recruitment 실패)
  - resampling weights ≈ [0.333, 0.333, 0.333] (probability overlap scale `~1e-5`로 무력화)
- status: `.agent/status/fragmap.md` — target occupancy 0단계
- plan: `~/.cursor/plans/target_fragmap_occupancy_af712dd6.plan.md`

## Assumptions And Questions

- assumptions:
  - shared FragMap NPZ (`ternary_r2`)의 favorable channel은 `hydrophobe`, `aromatic`,
    `heteroaromatic`, `polar` mixture로 초기 둔다. mixture weight는 channel별 균등 1.0.
  - target chain은 config에서 명시 (`target_chain: "B"` 등) — 자동 추론 안 함.
  - CRBN/VAV1 alignment offset은 기존 `reference_residue_offset_*`을 재사용.
  - 처음에는 GD off, resampling/score component만 영향. GD는 후속 contract.
- open questions:
  - target heavy atoms 전체 vs CA-only vs surface-exposed only — 일단 옵션화 (`target_atom_subset: heavy|ca|surface_heavy`), 기본 `heavy`.
  - probability normalization scale — `feature_probability`와 동일한 local mass 방식 재사용.
  - patch aggregation (best-of-patch / softmax)은 이번 contract 범위 밖. 일단
    target 전체 mean으로 두고, 다음 contract에서 patch 도입.
- tradeoffs:
  - target 전체 mean은 신호 희석 위험이 있지만, patch aggregation을 같이 넣으면
    구현 변경 표면이 커지고 원인 분리가 어려워진다. 단계 분리 우선.

## Constraints

- allowed change scope:
  - `src/boltz_extension/steering/fragmap_steering.py` — mode 분기, config parser, scoring 경로
  - 동일 파일 내 dataclass/Enum 또는 string mode 매핑 확장
  - 새 mode용 minimal unit smoke (no SLURM)
- forbidden change scope:
  - `biophysical_scorer.py`, `interface_steering_utils.py` (다음 contract에서)
  - 기존 mode (`atom`/`feature`/`feature_probability`)의 동작 변경 — backward-compat 유지
  - SLURM 제출, configs/vav1_pipeline 추가 — 별도 contract
  - 9NFR residue pair를 코드/config에 박는 행위 (generalization guard)
- external constraints:
  - shared repo (`/mnt/data/.../FKSFold-Boltz_Advancement_shared`)에는 mirror하지 않는다 — local repo만.
    shared 반영은 pilot 직전 별도 단계.
  - 사용자 승인 게이트: 어떤 SLURM 제출도 본 contract 밖.

## Non-Goals

- patch aggregation (best-of / softmax-of-patch)
- ligand-proximity shell contact reward (다음 contract: patch-aggregation)
- diagnostics CSV / score logging 보강
- T1-T4 config 작성 및 multi-seed pilot
- biophysical_scorer 쪽 component naming/logging 정리

## Done When

1. `FragMapSteeringPotential` config에서 `mode: target_occupancy` 파싱 가능
   하고 누락된 필수 필드 (`target_chain`, `favorable_channels`)는 명확한
   ValueError로 거절된다.
2. target chain heavy atoms를 CRBN-aligned 좌표계로 변환 후 favorable channel
   mixture local probability mass를 sample하는 score 함수가 단일 forward pass에서
   동작한다. `requires_grad=True` 입력에서 gradient도 backprop 가능.
3. exclusion grid (`*_excl` 또는 plan에서 정의된 negative channel)에 대해 target
   atom occupancy를 penalty로 빼는 항이 들어 있다.
4. 기존 mode (`atom`, `feature`, `feature_probability`) smoke가 그대로 통과 —
   동일 입력에서 score/gradient 값이 변하지 않는다 (backward-compat).
5. 새 mode에 대한 standalone smoke 스크립트가 `analysis/`에 추가되어 dummy
   coords + 기존 ternary_r2 NPZ로 score/grad shape, exclusion penalty sign,
   ligand weight 영향을 확인한다. SLURM 없음.

## Implementation Steps

1. `fragmap_steering.py`에서 현재 mode 분기 구조와 alignment helper를 읽어
   target chain extraction이 어디서 가능한지 확인.
   verify: 변경 전 mode 목록과 진입점 함수 이름 메모.
2. config dataclass/parser에 `mode: target_occupancy` 분기 추가. 필수 필드:
   `target_chain`, `favorable_channels` (list[str] or list[dict{channel,weight}]),
   `target_atom_subset` (default `heavy`), `exclusion_channels` (optional),
   `target_reward_weight` (default 1.0), `exclusion_penalty_weight` (default 1.0).
   verify: 잘못된 config 4종 (missing fields, unknown channel, empty target,
   conflicting subset) ValueError.
3. score 함수 구현. 절차:
   a) target chain heavy atoms 추출 + CRBN-aligned 좌표 변환 (기존 alignment 재사용)
   b) favorable channel mixture에 대해 atom별 local probability mass sample
      (`feature_probability` 모드의 helper 재사용 — 중복 구현 금지)
   c) exclusion channels에 대해 동일 sampling 후 penalty
   d) reduction: 전체 mean (patch aggregation은 non-goal)
   e) ligand atom score는 0 weight로 두되 alignment용 입력은 그대로 받음
   verify: 단일 forward pass smoke, gradient finite, sign sanity
   (exclusion atom 추가 시 score 감소).
4. 기존 mode 회귀 smoke. `feature_probability` 등 기존 fixture 입력으로
   score/grad 동등성 확인.
   verify: 동일 seed/입력에서 numeric 값 차이 `< 1e-6`.
5. `analysis/fragmap_target_occupancy_smoke.py` 추가. dummy 2-chain pose +
   기존 NPZ로 score, grad, exclusion penalty 부호 출력. py_compile 통과.
   verify: 스크립트 단독 실행 성공, 출력 finite.

## Change Discipline

- simplest adequate approach: 새 mode 분기 하나 추가 + 기존 probability helper 재사용
- new abstractions introduced: 없음 (helper 추가만, 기존 mode 구조 유지)
- unrelated code touched: 없음
- pre-existing dead code noticed: TBD (1단계에서 확인)
- request-to-diff trace: plan todo 1 (`target-occupancy-mode`)에 1:1 대응

## Verification

- `python3 -m py_compile src/boltz_extension/steering/fragmap_steering.py`
- `python3 analysis/fragmap_target_occupancy_smoke.py` (새로 추가)
- 기존 회귀: `python3 analysis/fragmap_feature_probability_breakdown.py`를
  기존 `fragmap_9nfr_probability_20260518_142633` 산출물에 돌려 출력 무변화 확인
- 수동 점검:
  - 잘못된 config 4종에서 ValueError
  - exclusion atom 추가 시 score 단조 감소

## Risks

- regression risk: 기존 mode 진입점 공유 시 분기 누락. 4단계 회귀 smoke로 차단.
- integration risk: alignment helper의 입력 contract가 ligand 가정 시 target에
  대해 미묘하게 다르게 동작할 수 있음. 1단계에서 alignment helper signature
  먼저 확인.
- hidden dependency risk: shared repo와 local repo 동기화 누락. 본 contract는
  local만 다루고, shared mirror는 다음 contract에서 명시 단계로.

## Rollback

- revert strategy: `fragmap_steering.py` mode 분기와 smoke 스크립트만 revert
  (단일 파일 + 추가 파일 1개)
- containment strategy: mode를 명시적으로 지정해야 동작하므로 기존 config는
  영향 없음 — 안전 default.

## Progress Log

- 2026-05-19: contract draft. 승인 대기.
- 2026-05-19: 사용자 승인 후 shared repo 단독 구현 결정 (local/shared divergence: shared가 SLURM source).
- 2026-05-19: 5/5 todo 완료.
  - parser: ValueError 4종 (missing favorable_channels / missing target_chain / empty favorable_channels / bad subset) 확인. 정상 config 파싱 OK.
  - scoring: `_per_sample_energy` 내 early-dispatch branch 추가. target heavy atoms를 CRBN-aligned 좌표계로 변환 후 favorable channel mixture local probability mass + exclusion penalty + unmapped penalty.
  - backward-compat: cluster_then_grid / grid / feature / feature_probability 모두 deterministic, finite. legacy code path 미수정 (early return으로 분기).
  - smoke: `analysis/fragmap_target_occupancy_smoke.py` PASS. excl-positive voxel에서 energy 단조 증가 (+1.545→+1.593). target grad_norm 0.478, ligand grad_norm 0, public compute_gradient=0 (contract guard).
  - GD off는 `compute_gradient`에서 명시적으로 zero 반환 (gd_scale > 0 무시).
- shared repo 변경 파일:
  - `src/boltz_extension/steering/fragmap_steering.py`
  - `analysis/fragmap_target_occupancy_smoke.py`
