---
status: done
slice: aigen-fold-core
topic: ddb1-contact-early-9nfr
date: 2026-06-26
owner: claude
approved_by: sunghoon.kim
requested: 2026-06-26
cross_slice: []
triggers_matched:
  - "소스 코드 변경 — boltz_extension/steering/potentials.py 로컬 복사본 수정"
  - "SLURM/GPU submission — 6 cells (ARM-0 + ARM-2 × 3 seeds)"
  - "shared-storage writes — /mnt 워크스페이스 생성 출력"
---

# DDB1 contact-early — ContactPotentital 조기 활성화 실험

## Purpose

force:true 실험(job 8442) 결과: CRBN_RMSD 여전히 20-25Å, 0/12 contacts satisfied.  
근본 원인은 코드 추적으로 특정됨:

```python
# potentials.py:772-774 — ContactPotentital base_params
"guidance_interval": 4,
"guidance_weight": PiecewiseStepFunction(
    thresholds=[0.25, 0.75], values=[0.0, 0.5, 1.0]
),
```

`PiecewiseStepFunction([0.25, 0.75], [0.0, 0.5, 1.0])`:
- t > 0.75 (steps 1-15): `guidance_weight = 0.0` → ContactPotentital 비활성
- t 0.25-0.75 (steps 16-37): weight = 0.5
- t < 0.25 (steps 38-50): weight = 1.0

Boltz diffusion 50 steps 기준, CRBN 전역 방향은 steps 1-12 (high-noise phase)에서 결정된다.
ContactPotentital이 step 16부터 켜지므로, 체인이 방향을 잡은 **이후에** 제약이 활성화된다.
이것이 force:true로도 0/12가 되는 완전한 설명이다.

**이번 실험**: `guidance_weight = 0` 구간 제거 → step 1부터 강한 constant weight 적용.  
`guidance_interval: 4 → 1` (매 step)으로 갱신 빈도도 올린다.

수정 대상:
```python
# 변경 전
"guidance_interval": 4,
"guidance_weight": PiecewiseStepFunction(
    thresholds=[0.25, 0.75], values=[0.0, 0.5, 1.0]
),

# 변경 후
"guidance_interval": 1,
"guidance_weight": 1.5,
```

stage/src는 공유 symlink → **로컬 복사본** 생성 후 수정 (공유 src 절대 변경 금지).

## Setup

- **신규 WS**: `/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/`
- **로컬 src**: `${WS}/stage/src_local/` — `ik_9nfr_20260625/stage/src/` 전체 복사 후 potentials.py만 패치
- **YAML**: force:true 12개 contact 블록 재사용 (`ddb1_forcetrue_9nfr_20260626/inputs/9NFR_ddb1_forcetrue.yaml` 복사)
- **MSA**: `ddb1_forcetrue_9nfr_20260626/msa/ddb1_chain_D.csv` symlink 재사용
- **ARMs**: ARM-0 × 3 seeds + ARM-2 × 3 seeds = 6 cells
  - ARM-0: potentials 수정 효과 단독 격리
  - ARM-2: biophysical_hybrid + CRL IK, num_particles=2 (OOM-safe)

## Constraints

- allowed change scope:
  - 신규 WS: `/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/`
  - `stage/src_local/` — potentials.py 2줄 수정만 (guidance_interval + guidance_weight)
  - 새 런처: `run_ddb1_contact_early_9nfr.sh`
  - 결과 문서: `/home/ubuntu/analysis/crl_integrative/ddb1_contact_early_9nfr_results.md`
- forbidden change scope:
  - `ik_9nfr_20260625/stage/src/` 절대 변경 금지 (공유 src)
  - 기존 WS(forcetrue, fullstk, full_msa) 변경 금지
  - oracle_generation_9nfr.yaml 변경 금지
- external constraints:
  - GPU: `sudo -u kim sbatch --qos=batch`
  - 출력: `/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/` (chmod 777)
  - SLURM GPU selector: `memory.free > 75000 MiB`
  - PYTHONPATH: `${WS}/stage/src_local:${WS}/stage/src_local/boltz_extension` (로컬 src 우선)

## Non-Goals

- potentials.py 외 다른 소스 코드 변경 (featurizerv2, main.py 등)
- guidance_weight 값의 세밀한 튜닝 (이번은 1.5 단일값으로 시작)
- DDB1 full 1140AA
- contact max_distance 변경

## Done When

- `wc -l .../analysis/scores.tsv` → `7` (header + 6 rows)
- `/home/ubuntu/analysis/crl_integrative/ddb1_contact_early_9nfr_results.md` 존재
  — ARM-0 CRBN_RMSD 기준 개선 여부 + contact_satisfied/12 명기
- 판정 기준:
  - ARM-0 CRBN_RMSD < 10Å AND contact_satisfied ≥ 6/12 → PASS (guidance fix 유효)
  - 그 외 → FAIL (다음 가설로 전환)

## Rollback

`sudo -u kim scancel <JOBID>` + `rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/`  
공유 src는 변경 없으므로 롤백 필요 없음.

## Progress Log

- 2026-06-26: force:true 실험(8442) 분석 → guidance_weight=0 steps 1-15 근본원인 특정.
  ContactPotentital 조기 활성화 실험 컨트랙트 작성.
