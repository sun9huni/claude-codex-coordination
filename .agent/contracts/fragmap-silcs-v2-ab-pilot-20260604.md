# fragmap-silcs-v2-ab-pilot

**Status:** approved (amended 2026-06-08: feature → target_occupancy mode)
**Slice:** fragmap
**Approval:** requested 2026-06-04 · approved by: user 2026-06-04
**Amendment:** 2026-06-08 — prior 3 A/B runs (jobs 6298/6307/6323) used wrong
  mode:feature → invalidated. Correct comparison: v1 vs v2 map under
  mode:target_occupancy (the mode used by the original success run, job 5638).
  GCMC 10× (job 6245, 120/120) now complete; v2 npz finalized 2026-06-05.

## Purpose

v1 vs v2 FragMap under the CORRECT mode (target_occupancy) to verify whether
GCMC 10× improves VAV1 interface placement in generation.

## Scope

- **A 조건**: `fragmap_conditioning_target_t1_r10.yaml` (v1 map, 5-rep, mode=target_occupancy)
- **B 조건**: `fragmap_conditioning_target_t1_r10_v2interim.yaml` (v2 map, 10-rep GCMC, same mode)
- Input: `examples/9nfr/9nfr_mrt6160_vav1_14_19.yaml`
- Seeds: 42, 123, 777, 314, 16 (5 × 2 conditions = 10 runs)
- Params: λ=20, num_particles=8 (validated production defaults)
- 평가: vav1_rigid_body_offset, iface F1@4Å, Wilcoxon win-rate

## Non-Goals

- 143-batch 전체 재실행 (Stage 3에서 별도)
- map v2를 production으로 교체 (이 pilot이 먼저)
- feature-mode testing (ceiling-limited per REPORT.md §Forward-question gate)

## Done When

- 10개 generation run 완료
- vav1_offset A vs B, iface F1 A vs B 비교표 작성
- Go/Kill 판정: win-rate ≥ 60% → Go (v2 map 채택), < 60% → Kill (v1 유지)

## Triggers

- SLURM 제출: YES
- FragMap NPZ 경로 변경(config만): 코드/engine 변경 없음

## Resource Budget

- GPU: 2× A100 (A 조건 1, B 조건 1), ~2-3h
- qos: batch

## Rollback

- 새 config yaml 삭제, 새 SLURM 스크립트 삭제
- 기존 v1 map / steering code 미접촉 → 영향 없음
