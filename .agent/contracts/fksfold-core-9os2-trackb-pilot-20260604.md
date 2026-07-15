---
status: done
slice: fksfold-core
topic: 9os2-trackb-pilot
date: 2026-06-04
owner: claude
approved_by: user (2026-06-04, "승인")
parent_contract: .agent/contracts/fksfold-core-ood-why-diagnosis-20260604.md
triggers_matched:
  - "SLURM 신규 제출 (9OS2 enhanced + replication arms)"
  - "4개 파일 이상 (YAML configs + SLURM script + scoring + report)"
  - "local↔shared 동시 (생성 출력 scratch /mnt/data)"
---

# 9OS2 Track B pilot: steering parameter sensitivity test

## Purpose

WHY 진단(2026-06-04)에서 9OS2(G3BP2) partial rescue(2/8)의 구조적 원인이
미확인됨 — H2(pocket burial), H4(anchor quality) 모두 REFUTED, DDB1 누락은
9DWW에도 동일 적용되어 9OS2-specific 원인 아님. 따라서 남은 질문은 경험적:
**steering parameter 강화(num_particles 8 + lambda 20)로 stochastic 성공률을
올릴 수 있는가?** GO이면 steering paradigm 적용 가능, KILL이면 구조적 한계.

## Current State

- OOD rescue 9OS2 결과: nativeAB 2/8 acceptable (0.063 median, 0.005 baseline)
  OOD rescue param: `--interface_lambda 0.5 --num_particles 3`
- 재사용 substrate: `examples/heldout/9OS2.yaml` + anchor w400_seq_pos=345(W) + 
  DockQ scorer `run_ood_scoring.py` + per-task UUID GPU harness
- 비교 기준: wrongAB 0/8 (특이성 control, 유지 필수)

## Scope

- **Enhanced arm (16 seeds)**: `--num_particles 8 --interface_lambda 20 --interface_resampling_interval 3`
  seeds: 16, 42, 123, 7, 99, 256, 314, 512, 1, 2, 3, 4, 5, 6, 8, 9
- **Replication arm (8 seeds)**: 원본 param (`lambda 0.5, particles 3`) + 8 seeds
  seeds: 16, 42, 123, 7, 99, 256, 314, 512 (OOD rescue와 동일 — 재현성 확인)
- **Condition**: nativeAB only (wrongAB는 OOD rescue 0/8로 확인 완료 — 재실행 불필요)
- **총 runs**: 24 (enhanced 16 + replication 8)

## Out of Scope

- 9NFQ: 새 구조 가설 없음 → 이 계약에서 제외
- 9DWW: 8/8 이미 완료 → 불필요
- steering 코드(src/) 수정: parameter 조정만, 코드 미접촉
- DDB1(790aa) chain 추가 YAML 실험: DDB1은 9DWW에도 누락됨이 확인됨 → 변별력 없음

## Success Criteria (사전 동결)

| 판정 | 조건 |
|------|------|
| **GO** | enhanced arm nativeAB ≥ 5/16 AND > replication arm rate AND wrongAB = 0 |
| **KILL** | enhanced arm nativeAB ≤ 2/16 → 구조적 한계, steering paradigm 부적합 |
| **INCONCLUSIVE** | 3-4/16 → 더 큰 sweep 필요 (별도 계약) |

검증 커맨드: `python3 run_ood_scoring.py --manifest <out>/manifest.json` →
`9OS2_enhanced accept=N/16` + `9OS2_replication accept=N/8`

## Resource Budget

- GPU: A100 × 8 (qos=batch), SLURM array %8
- 예상 시간: ~1-2h (24 runs, 각 ~5-7분, 8 병렬)
- 출력: `/mnt/data/users/ubuntu/workspace/9os2_trackb_20260604/` (scratch, re-runnable)

## Approval

- requested: 2026-06-04
- approved by: pending

## Rollback

- `scancel <jobid>` + scratch 출력 폐기
- production/steering 코드 미접촉 → git revert 불필요
- YAML/script git revert 가능

## Done When

- 24/24 runs 완료, DockQ 채점, GO/KILL/INCONCLUSIVE 판정표 작성
- `TRACKB_RESULTS.md`: arm별 accept-rate + verdict
