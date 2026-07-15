---
status: done
slice: aigen-fold-core
topic: ddb1-fullstk-9nfr
date: 2026-06-26
owner: claude
approved_by: sunghoon.kim
requested: 2026-06-26
cross_slice: []
triggers_matched:
  - "SLURM/GPU submission — DDB1 full-stack 4체인 생성 런"
  - "shared-storage writes — /mnt 워크스페이스 생성 출력"
---

# DDB1 full-stack 9NFR — full MSA + DDB1-CRBN contact constraints + CRL closure IK

## Purpose

Phase 1(job 8413) 결과: full MSA 단독으로 CRBN_RMSD 개선 없음 (20.6-24.9Å), cone_dist
오히려 악화 (14-18→27-40Å). 결론: MSA 공진화 신호만으로는 CRBN 전역 방향을 고정할 수 없다.

이번 실험은 두 문제를 직접 해결한다:

1. **CRBN 전역 방향 고정**: 9UUM에서 확인된 DDB1 ΔBPA-CRBN Cα≤8Å 접촉 쌍 12개를
   Boltz `contact` constraint로 YAML에 직접 명시. `pocket`(binder 전체 근접)보다
   `contact`(잔기-잔기 쌍 거리 제약)가 단백질-단백질 인터페이스에 더 정밀하다.
   
2. **기질 리신 근접 공격 기하 달성**: CRL closure IK(ARM-2) 재활성화.
   이전 4체인 ARM-2 OOM 원인 = `--num_particles 8` × ~1227 토큰.
   `--num_particles 2`로 낮춰 A100 80GB 이내로 진입.

가설: DDB1-CRBN contact constraint로 CRBN 방향이 고정되면,
CRL closure IK가 VAV1 Lys Nζ를 cone_apex로 유도해 near_attack=True를 달성할 수 있다.
9OTY에서 이 스택이 DockQ=0.738을 냈다.

## Phase 1 현황 (ddb1_full_msa_9nfr_20260626, job 8413)

| seed | CRBN_RMSD (Å) | DockQ | cone_dist (Å) |
|------|--------------|-------|--------------|
| 16 | 24.866 | 0.0063 | 40.0 |
| 42 | 20.645 | 0.0146 | 27.3 |
| 123 | 21.311 | 0.0205 | 34.8 |

Fnat=0.000 전 seeds. MSA 단독 실험 종료.

## Constraints (기술 명세)

### YAML `contact` 제약 — DDB1(D)-CRBN(A) 인터페이스 (9UUM 검증)

9UUM Cα≤8Å 접촉 쌍 18개 중 상위 12쌍 (6.5-7.7Å), prediction seqid 매핑:
- CRBN prediction seqid = 9UUM seqid - 45
- DDB1 ΔBPA prediction seqid = 9UUM seqid - 395

| 9UUM CRBN | 9UUM DDB1 | dist(Å) | pred A | pred D |
|-----------|-----------|---------|--------|--------|
| 237 | 1033 | 6.54 | 192 | 638 |
| 238 | 1005 | 6.62 | 193 | 610 |
| 196 | 971  | 6.67 | 151 | 576 |
| 303 | 951  | 6.67 | 258 | 556 |
| 239 | 1005 | 6.82 | 194 | 610 |
| 196 | 970  | 7.00 | 151 | 575 |
| 239 | 722  | 7.19 | 194 | 327 |
| 190 | 952  | 7.40 | 145 | 557 |
| 247 | 842  | 7.46 | 202 | 447 |
| 247 | 841  | 7.51 | 202 | 446 |
| 238 | 1033 | 7.60 | 193 | 638 |
| 197 | 1003 | 7.64 | 152 | 608 |

`max_distance: 9.0` — 8Å 거리에서 10% 여유. `force: false` (soft constraint).

### ARM 구성

| ARM | 설정 | 목적 |
|-----|------|------|
| ARM-0 | vanilla, no potentials | constraints 단독 효과 격리 |
| ARM-2 | biophysical_hybrid + CRL IK, num_particles=2 | full stack: 방향 고정 + IK |

3 seeds (16/42/123) × 2 ARMs = 6 cells

### ARM-2 핵심 파라미터 (9OTY DockQ=0.738 검증 세팅, 4체인 OOM 수정)

```bash
# 샘플링
--sampling_steps 50 --recycling_steps 3 --diffusion_samples 1

# 파티클 스티어링 (OOM 방지: 8→2)
--use_potentials --potential_type vanilla
--num_particles 2

# biophysical_hybrid oracle (oracle_generation_9nfr.yaml 재사용)
--use_interface_steering
--interface_scoring_type biophysical_hybrid
--biophysical_enabled --biophysical_config ${ORACLE_CFG}
--interface_lambda 20
--interface_resampling_interval 3

# gradient descent 정제
--enable_interface_gd --interface_gd_lr 0.01 --gd_start_t 0.5

# CRL closure IK
--crl_closure_enabled
--crl_closure_config ${CLOSURE_SPEC}   # closure_spec_generic.json (9UUM 기준)
--crl_closure_weight 1.0
--crl_gd_start_t 0.5
```

### oracle_generation_9nfr.yaml (변경 없음)

기존 설정 유효:
- `chain_A: B` (VAV1), `chain_B: A` (CRBN), `chain_MG: C` (MRT23227)
- `key_residues_B: [344, 348, 350]` — CRBN anchor (CRBN prediction seqid, 방향 인식 불필요)
- `gate_source: mg_crbn_score, center: 0.55, sharpness: 14.0`
- `w_threeway: 0.65, w_dist: 0.35`
- `glueprint anchor_patch: [327, 331, 333]`

chain D(DDB1)는 oracle에 무관 — oracle은 A/B/C 삼원 기하만 본다.

## Constraints (운영)

- allowed change scope:
  - 신규 워크스페이스: `/mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/`
  - 신규 YAML: `9NFR_ddb1_fullstk.yaml` — Phase 1 YAML + 12개 DDB1-CRBN contact constraint
  - 신규 런처: `run_ddb1_fullstk_9nfr.sh` — ARM-0 + ARM-2(num_particles=2) × 3 seeds
  - 결과 문서: `/home/ubuntu/analysis/crl_integrative/ddb1_fullstk_9nfr_results.md`
- forbidden change scope:
  - Phase 1/0 워크스페이스 수정 금지
  - boltz_extension/ 소스 코드 변경 금지
  - oracle_generation_9nfr.yaml 변경 금지 (검증 세팅 보존)
- external constraints:
  - GPU: `sudo -u kim sbatch --qos=batch`
  - 출력: `/mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/` (chmod 777)
  - SLURM GPU selector: `memory.free > 75000 MiB`

## Non-Goals

- DDB1 full 1140AA
- contact constraint `force: true` (이번에는 soft로 시작)
- oracle config 수정
- ARM-1 (gradient guidance only)
- GATE 설정 없음 (탐색적)

## Done When

- `wc -l .../analysis/scores.tsv` → `7` (header + 6 rows, ARM-0/ARM-2 × 3 seeds)
- `/home/ubuntu/analysis/crl_integrative/ddb1_fullstk_9nfr_results.md` 존재
  — Phase 1 (MSA only) 대비 CRBN_RMSD 변화, Phase 2 (constraints+IK) 효과 정량화
- ARM-2 near_attack=True 달성 여부 명기

## Rollback

`sudo -u kim scancel <JOBID>` + `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/`

## Progress Log

- 2026-06-26: 초안 — Phase 1 MSA-only FAIL 확인 후 full-stack 컨트랙트 refinement.
  `contact` constraint 지원 확인(schema.py:1562). 9UUM Cα≤8Å 18쌍 계산, 상위 12쌍 확정.
