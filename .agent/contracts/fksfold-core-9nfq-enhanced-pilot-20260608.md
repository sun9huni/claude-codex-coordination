---
status: approved
slice: fksfold-core
topic: 9nfq-enhanced-pilot
date: 2026-06-08
owner: claude
parent_contract: .agent/contracts/fksfold-core-9os2-trackb-pilot-20260604.md
triggers_matched:
  - "SLURM 신규 제출 (9NFQ enhanced arm)"
  - "4개 파일 이상 (TSV + SLURM script + scoring + report)"
  - "local↔shared 동시 (생성 출력 scratch /mnt/data)"
---

# 9NFQ Enhanced Pilot: CoM-distance steering-limit test

## Purpose

Track B (2026-06-05)에서 9OS2(CoM=37.7Å)는 enhanced params(λ=20/p=8)로 25%→56%
향상을 확인했다. 9NFQ(NEK7, CoM=46.9Å)는 λ=0.5/p=4에서 0/8으로 steering 효과가
사실상 없었다(nativeAB≈wrongAB≈0.03). 이 실험의 질문:

**CoM 거리 46.9Å(9OS2 대비 +9.2Å)에서 enhanced params가 동일하게 작동하는가?**

- YES → steering paradigm은 CoM 46.9Å까지 적용 가능 (9NFQ production-operational)
- NO → CoM 거리가 steering 효과의 구조적 한계이며, 더 근본적인 앵커 재설계 필요

이는 WHY_ANALYSIS의 "blind sweeping 지양" 권고 이후 가장 명확한 구조 가설이
생긴 첫 번째 기회임. 선행 Track B 없이는 "blind"였으나, 이제 validated lever(λ/p)와
measurable variable(CoM 거리)이 확인됨.

## Current State

- OOD rescue 9NFQ: nativeAB 0/8 (median DockQ 0.038, λ=0.5/p=3)
- WHY 진단: H2(pocket burial) REFUTED, H4(anchor) REFUTED. CoM=46.9Å가 유일한
  구별자 — 9DWW(39.5Å,8/8), 9OS2(37.7Å)와의 유일한 체계적 차이.
- 재사용: `examples/heldout/9NFQ.yaml` + `oracle_generation_heldout_9NFQ.yaml`
  + `run_ood_scoring.py` DockQ scorer + Track B SLURM pattern
- W400_IDX: 9NFQ CRBN sequence walk 필요 (re-derive, Track B와 동일 방법)

## Scope

- **Enhanced arm (16 seeds)**: `--num_particles 8 --interface_lambda 20
  --interface_resampling_interval 3`
  seeds: 16, 42, 123, 7, 99, 256, 314, 512, 1, 2, 3, 4, 5, 6, 8, 9
- **Replication arm (8 seeds)**: λ=0.5/p=4 (Track B replication arm 동일)
  seeds: 16, 42, 123, 7, 99, 256, 314, 512
- **Condition**: nativeAB only (wrongAB는 OOD rescue 0/8 확인됨 — 재실행 불필요)
- **총 runs**: 24 (enhanced 16 + replication 8)

## Out of Scope

- 9OS2, 9DWW: 이미 완료
- 9DUR: PROTAC paradigm gap — steering inapplicable
- YAML 수정 또는 새 체인 추가: 9OS2 DDB1 교훈 적용 — parameter sensitivity 먼저 확인
- 앵커 재설계: 이 실험이 KILL 날 경우만 고려 (별도 계약)

## Success Criteria (사전 동결)

| 판정 | 조건 |
|------|------|
| **GO** | enhanced ≥5/16 AND > replication AND wrongAB=0(기존) |
| **KILL** | enhanced ≤2/16 → CoM 거리 한계, 앵커 재설계 필요 |
| **INCONCLUSIVE** | 3-4/16 → 더 큰 sweep 또는 앵커 재설계 필요 |

## Resource Budget

- GPU: A100 × 8 (qos=batch), array %8
- 예상 시간: ~1-2h (24 runs, 각 ~5-7분, 8 병렬)
- 출력: `/mnt/data/users/ubuntu/workspace/9nfq_enhanced_20260608/` (scratch)

## Rollback

- `scancel <jobid>` + scratch 출력 폐기
- YAML/config 미수정 → git revert 불필요

## Done When

- 24/24 runs 완료, DockQ 채점, GO/KILL/INCONCLUSIVE 판정표 작성
- `9NFQ_ENHANCED_RESULTS.md`
