---
status: done
slice: aigen-fold-core
topic: ternary-benchmark-3systems
date: 2026-06-29
owner: claude
approved_by: sunghoon.kim
requested: 2026-06-29
cross_slice: []
triggers_matched:
  - "SLURM/GPU 제출 — 6 cells (BRD4×3 + IKZF1×3 ARM-0)"
  - "shared-storage writes — /mnt/kfs2 워크스페이스 + 출력"
  - "신규 YAML 2개 + YAML contacts 추출 (6BN7, 6H0F crystal)"
---

# Ternary Complex 예측 벤치마크 — BRD4 / IKZF1/3 (CRBN pipeline, GT 검증)

## Purpose

CRBN-VAV1 시스템(DQcv=0.084)이 파이프라인 한계인지 VAV1 degron 특이 문제인지 판별하기 위해,
**동일 파이프라인 아키텍처**(9UUM 템플릿 + DDB1-CRBN contacts + neo-substrate-CRBN contacts
+ Lys-Ub cone steering)를 GT PDB가 있는 CRBN 시스템에 적용하고 DockQ로 직접 채점한다.

대상:
- **BRD4**: GT=6BN7 (DDB1/CRBN/BRD4_BD2, dBET23). neo-substrate 127aa.
- **IKZF1/3**: GT=6H0F chain A/B/C (DDB1/CRBN/IKZF1_ZnF, lenalidomide). neo-substrate 32aa.

VHL 기반 KRAS는 별도 파이프라인(VHL 템플릿, VHL-Cullin contacts) 필요 → 이번 범위 외.

## 파이프라인 아키텍처 (contact_fix_9nfr 동일)

| 구성요소 | BRD4 | IKZF1/3 | 비고 |
|---|---|---|---|
| Templates | 9UUM, 9V0F, 4TZ4, 4CI3, 5HXB | 동일 | 기존 CRBN 템플릿 재사용 |
| DDB1-CRBN contacts | 10쌍 (<4Å, 6BN7 crystal) | 10쌍 (<4Å, 6H0F crystal) | force:true, max_dist=8Å |
| neo-CRBN contacts | 8쌍 (<4Å, 6BN7 crystal) | 8쌍 (<4Å, 6H0F crystal) | force:true, max_dist=8Å |
| Lys-Ub cone | K99(Y58), near_attack_A=20Å | IKZF1 ZnF Lys 분석 필요 | 동일 closure_spec |
| ARM | ARM-0 × 3 seeds | ARM-0 × 3 seeds | |
| ARM-2 | 사용 안 함 | 사용 안 함 | MGD/짧은 PROTAC엔 불필요 |

## BRD4 시스템 분석 결과 (6BN7)

9UUM→6BN7 CRBN Kabsch: 372쌍 matched, RMSD=1.619Å

cone_apex (Gly76 C, 6BN7 frame): [65.21, 21.81, 49.67]

BRD4 Lys → cone_apex 거리:
- **K99 (YAML 58)**: Nζ=12.3Å ★ (primary target)
- K91 (YAML 50): Nζ=12.5Å

CRBN-DDB1 contacts (top 10, YAML positions, A=CRBN/D=DDB1):
| CRBN(A) | DDB1(D) | 거리 |
|---|---|---|
| 185 | 677 | 2.58Å |
| 196 | 597 | 2.64Å |
| 157 | 320 | 2.73Å |
| 186 | 400 | 2.74Å |
| 164 | 188 | 2.77Å |
| 148 | 625 | 2.80Å |
| 165 | 183 | 3.04Å |
| 158 | 305 | 3.06Å |
| 153 | 644 | 3.10Å |
| 161 | 259 | 3.16Å |

CRBN-BRD4 contacts (top 8, YAML positions, A=CRBN/B=BRD4):
| CRBN(A) | BRD4(B) | 거리 |
|---|---|---|
| 300 |  37 | 3.13Å |
|  60 | 104 | 3.14Å |
| 108 | 111 | 3.18Å |
|  60 | 102 | 3.26Å |
| 300 |  38 | 3.27Å |
| 107 |  37 | 3.30Å |
| 107 |  36 | 3.34Å |
|  60 | 107 | 3.38Å |

CRBN YAML offset: YAML_pos = crystal_resid - 43  
DDB1 YAML offset: resid-to-pos map (gaps 있음, 직접 계산)  
BRD4 YAML offset: YAML_pos = crystal_resid - 41

## YAML 체인 구성

BRD4:
- A=CRBN (375aa, 6BN7 chain B resid 44-427)
- B=BRD4_BD2 (127aa, 6BN7 chain C resid 42-168)
- C=dBET23 SMILES: `n6c(C)n7c4c(c(c(C(=O)NCCCCCCCCNC(=O)COc1cccc2c1C(=O)N(C2=O)C3C(=O)NC(CC3)=O)s4)C)C(c5ccc(cc5)Cl)=NC(C)n67`
- D=DDB1 (803aa, 6BN7 chain A resid 1-1140 gaps포함)
- MSA: single-seq CSV (all chains)

IKZF1:
- A=CRBN (374aa, 6H0F chain B)
- B=IKZF1_ZnF (32aa, 6H0F chain C)
- C=lenalidomide SMILES: `O=C1NC(=O)CCC1N3C(=O)c2cccc(c2C3=O)N`
- D=DDB1 (826aa, 6H0F chain A)
- MSA: single-seq CSV

## Scoring

DockQ --model pred.pdb --native gt.pdb --mapping <pred→crystal chain>

지표:
- DQcv: CRBN–neo_substrate (BRD4/IKZF1)
- DQcd: CRBN–DDB1
- DQ_total
- neo_RMSD to GT

비교 기준: CRBN-VAV1 DQcv=0.084

## Constraints

- allowed change scope:
  - WS: `/mnt/kfs2/data/users/ubuntu/benchmark_ternary/` (refs/ 생성됨)
  - 신규 디렉토리: inputs/, logs/, out/, msa/, stage/
  - 신규 YAML 2개: brd4_benchmark.yaml, ikzf1_benchmark.yaml
  - 런처: run_benchmark.sh
  - closure_spec 복사본: stage/closure_spec_benchmark.json (near_attack_A=20.0)
  - src_local: contact_early 기존 symlink 재사용
  - 결과 문서: /home/ubuntu/analysis/crl_integrative/ternary_benchmark_results.md
- forbidden:
  - 기존 실험 WS 변경 금지
  - 공유 closure_spec_generic.json 변경 금지
- external:
  - GPU: `sudo -u kim sbatch --qos=normal`
  - chmod 777 logs/ out/
  - SLURM GPU: memory.free > 75000 MiB

## Non-Goals

- KRAS-VHL (VHL 파이프라인 별도 컨트랙트)
- ARM-2 / IK closure
- MSA 최적화
- BRD4 BD1 / 다른 degrader variant

## Done When

```bash
find /mnt/kfs2/data/users/ubuntu/benchmark_ternary/out/ -name "*_model_0.pdb" | wc -l
# → 6
test -f /home/ubuntu/analysis/crl_integrative/ternary_benchmark_results.md
```

판정 기준:
- 6/6 cells 완료
- BRD4 DQcv, IKZF1 DQcv 계산됨
- CRBN-VAV1 baseline(DQcv=0.084)과 비교 표 작성

## Rollback

```bash
sudo -u kim scancel <JOBID>
sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/benchmark_ternary/{out,logs}/
```
refs/는 보존.

## Progress Log

- 2026-06-29: PDB 다운로드(15종) + chain 분석 완료.
  BRD4(6BN7): Kabsch RMSD=1.619Å, cone_apex=[65.21,21.81,49.67], K99 Nζ=12.3Å.
  CRBN-DDB1 10쌍, CRBN-BRD4 8쌍 contacts 산출 완료. YAML pos 매핑 완료.
  IKZF1(6H0F): contacts + Lys 분석은 Task 2에서 수행.
  사용자 승인 대기.
