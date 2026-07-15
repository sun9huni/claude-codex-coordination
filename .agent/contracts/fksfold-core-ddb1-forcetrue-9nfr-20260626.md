---
status: done
slice: aigen-fold-core
topic: ddb1-forcetrue-9nfr
date: 2026-06-26
owner: claude
approved_by: sunghoon.kim
requested: 2026-06-26
cross_slice: []
triggers_matched:
  - "SLURM/GPU submission — DDB1 force:true contact 생성 런"
  - "shared-storage writes — /mnt 워크스페이스 생성 출력"
---

# DDB1 contact force:true — 9NFR CRBN 방향 고정 (hard diffusion penalty)

## Purpose

Phase 2(job 8415, force:false) 심층 분석 결과:

**DDB1이 BPC가 아닌 BPB/Arch 면으로 CRBN에 결합** — 약 180° 회전 오류.
- 올바른 파트너: BPC 잔기 D:556-638 (UniProt 951-1033) → CRBN TBD 잔기 145,151,192,193,194,202,258
- 예측 결과: BPB/Arch 잔기 D:327,419,476 (UniProt 722-871) → CRBN TBD (wrong domain)

`force:false` 원인: featurizerv2.py:2098 `if not force: continue` — hard diffusion path가 통째로
건너뜀. trunk attention bias만으로는 1.5M 쌍 중 12개 신호 → Boltz prior에 압도.

`force:true` 메커니즘: 확산 매 스텝 atom-pair union constraint.
token pair (A:192, D:638) 각각의 heavy atom × heavy atom Cartesian product → 적어도 하나가
max_distance 이내 조건. 12쌍 모두 hard penalty → DDB1 BPC 면이 CRBN을 향하도록 강제.

**가설**: force:true로 12쌍 충족 시 DDB1이 BPC-면으로 재배향 → CRBN_RMSD < 10Å.

## Phase 2 현황 (ddb1_fullstk_9nfr_20260626, job 8415)

force:false + full MSA + ARM-2 IK 결과:

| arm | seed | CRBN_RMSD | DockQ | cone_dist | 0/12 contact 충족 |
|-----|------|-----------|-------|-----------|-----------------|
| arm0 | 16 | 20.0Å | 0.010 | 77.7Å | 0/12 |
| arm0 | 42 | 20.5Å | 0.010 | 53.0Å | 0/12 |
| arm2 | 42 | 20.2Å | 0.044 | 59.4Å | 0/12 |

DDB1 실제 근접 잔기:
- A:192 → D:327 (BPB) 7.9Å (GT: A:192↔D:638 BPC)
- A:193 → D:419 (Arch) 6.1Å (GT: A:193↔D:610 BPC)
- A:145 → D:638 (BPC) 7.6Å (GT: A:145↔D:557 BPC)

## Constraints (기술 명세)

### YAML 변경: force:false → force:true

기존 Phase 2 YAML(`9NFR_ddb1_fullstk.yaml`)의 12개 contact 블록에 `force: true` 추가:

```yaml
- contact:
    token1: [A, 192]
    token2: [D, 638]
    max_distance: 9.0
    force: true   # ← 이것만 추가
```

12쌍 전부 동일하게 적용. 나머지 입력(full MSA, pocket constraints 2개, 4체인) 변경 없음.

### ARM 구성

ARM-0 × 3 seeds (16/42/123) = 3 cells.
목적: force:true 단독 효과 격리 (IK 없이 contact가 CRBN 방향을 고정하는지).
ARM-2는 CRBN_RMSD < 10Å 확인 후 다음 컨트랙트에서 진행.

### 기존 인프라 재사용

- MSA: `/mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/msa/ddb1_chain_D.csv`
- Oracle: `configs/oracle_generation_9nfr.yaml` (ARM-0에는 불필요, 파일만 존재)
- Closure spec: `stage/closure_spec_generic.json` (ARM-0에는 불필요)
- GT ref: `refs/9NFR.cif`
- 9UUM.cif: `analysis/crl_integrative/refs/9UUM.cif`

## Constraints (운영)

- allowed change scope:
  - 신규 워크스페이스: `/mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/`
  - 신규 YAML: `9NFR_ddb1_forcetrue.yaml` (Phase 2 YAML + force:true 12개)
  - 신규 런처: `run_ddb1_forcetrue_9nfr.sh` (ARM-0 × 3 seeds)
  - 결과 문서: `/home/ubuntu/analysis/crl_integrative/ddb1_forcetrue_9nfr_results.md`
- forbidden change scope:
  - Phase 1/2 워크스페이스 수정 금지
  - boltz_extension/ 소스 변경 금지
  - oracle_generation_9nfr.yaml 변경 금지
- external constraints:
  - GPU: `sudo -u kim sbatch --qos=batch`
  - 출력: `/mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/` (chmod 777)
  - SLURM GPU selector: `memory.free > 75000 MiB`

## Non-Goals

- ARM-2 IK (CRBN_RMSD가 고쳐진 후 다음 실험)
- DDB1 full 1140AA (force:true 먼저)
- force:true + ARM-2 동시 실행 (변수 분리)
- MRT6160 런 (9NFR GATE 통과 후)

## Done When

- `find .../out/ -name "*_model_0.pdb" | wc -l` → `3`
- `analysis/scores.tsv` 존재 (header + 3 rows)
  - 12쌍 contact 충족률 포함 (`contact_satisfied/12`)
  - CRBN_RMSD + DockQ + cone_dist
- `/home/ubuntu/analysis/crl_integrative/ddb1_forcetrue_9nfr_results.md` 존재

## 판정 기준

| 결과 | 의미 | 다음 |
|------|------|------|
| CRBN_RMSD < 10Å + contact ≥8/12 | force:true 유효, DDB1 BPC 재배향 성공 | ARM-2 + IK 런 |
| CRBN_RMSD 10-15Å + contact ≥8/12 | 부분 개선, DDB1 배향 개선됐으나 충분치 않음 | ARM-2 + IK 런 (IK 보조 기대) |
| CRBN_RMSD > 15Å 또는 contact < 5/12 | force:true도 DDB1 재배향 실패 | DDB1 full 1140AA 검토 |

## Rollback

`sudo -u kim scancel <JOBID>` + `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/`

## Progress Log

- 2026-06-26: 초안 — Phase 2 force:false 0/12 contact 충족, DDB1 BPB/Arch-면 결합 오류 확인.
  force:true hard diffusion penalty로 BPC 재배향 시도.
