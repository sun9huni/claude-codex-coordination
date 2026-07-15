---
status: done
slice: aigen-fold-core
topic: template-ddb1-combo-9nfr
date: 2026-06-26
owner: claude
approved_by: sunghoon.kim
requested: 2026-06-26
cross_slice: []
triggers_matched:
  - "SLURM/GPU submission — 9 cells (ARM-0 × 6 seeds + ARM-2 × 3 seeds)"
  - "shared-storage writes — /mnt 워크스페이스 생성 + 출력"
  - "소스 코드 변경 — src_local PYTHONPATH 재사용 (potentials.py 기존 패치)"
---

# Template conditioning + DDB1 ΔBPA (single-seq) + force:true contacts 조합 실험

## Purpose

전체 실험 계열 재분석 결과, CRBN 방향 문제(20Å RMSD)에 대한 두 부분 해법이
한 번도 동시에 시도된 적 없음을 확인했다:

| 실험 | 효과 | 한계 |
|---|---|---|
| Template conditioning (8381) | CRBN_RMSD 15Å 달성 (–5Å) | DDB1 물리적 chain 없음 → cone_dist 34–51Å |
| DDB1 single-seq MSA (8398) | cone_dist 14.2Å (최고) | CRBN_RMSD 개선 없음(20.6Å) |
| contact_early ARM-2 seed16 (8443) | cone_dist 5.47Å (IK 로컬 프레임) | CRBN_RMSD=25Å → near_attack False |

**가설**: 세 개입을 동시에 적용하면 시너지가 발생한다.

1. **템플릿 5개** (9UUM, 9V0F, 4TZ4, 4CI3, 5HXB) → trunk conditioning으로 CRBN prior 편향
   - 4체인 입력 시 DDB1 chain D가 템플릿 DDB1과도 페어링 → 3체인 실험(8381) 대비 템플릿 신호 2배
2. **DDB1 ΔBPA single-seq chain** → 물리적 scaffold. full MSA는 cone_dist를 악화시켰으므로
   single-seq 유지 (8398과 동일, 2줄 CSV)
3. **force:true 12 contacts** → DDB1-CRBN 인터페이스 hard constraint. CRBN가 15Å까지
   접근하면 DDB1 lock-in 가능 (8443에서 7/12 달성 확인)
4. **guidance_weight=1.5 constant** → src_local 기존 패치 재사용. step 1부터 활성

ARM-2 seed16에서 5.47Å (IK 로컬 프레임 기준) 시연 완료 —
CRBN 절대 방향만 잡히면 near_attack=True 달성 가능.

## Configuration

| 항목 | 설정 |
|---|---|
| 체인 | A=CRBN, B=VAV1 SH3c, C=MRT23227, D=DDB1 ΔBPA (8398 시퀀스 동일) |
| DDB1 MSA | single-seq CSV: `ddb1_4chain_9nfr_20260626/msa/ddb1_chain_D.csv` (2줄) |
| CRBN/VAV1 MSA | 기존 CSV 재사용 (`ik_9nfr_20260625/msa/`) |
| templates | 5 CIF: `template_9nfr_20260626/refs/{9UUM,9V0F,4TZ4,4CI3,5HXB}_prot.cif` |
| contact constraints | 12쌍 force:true (contact_early YAML 재사용) |
| potentials.py | src_local 기존 패치 (guidance_weight=1.5, guidance_interval=1) |
| PYTHONPATH | `${WS}/stage/src_local` (contact_early 런처 동일 방식) |
| ARMs | ARM-0 × 6 seeds + ARM-2 × 3 seeds = 9 cells |
| ARM-0 seeds | 16, 42, 123, 200, 300, 400 |
| ARM-2 seeds | 16, 42, 123 |

ARM-0 seed 6개: template 실험(8381)에서 seed123만 15Å이었음 → 더 많은
seed 확보로 CRBN_RMSD < 15Å 달성 확률 증가.

## Constraints

- allowed change scope:
  - 신규 WS: `/mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/`
  - 신규 YAML: `9NFR_template_ddb1_combo.yaml` (template + 4체인 + 12 contacts 통합)
  - 신규 런처: `run_template_ddb1_combo_9nfr.sh`
  - src_local: contact_early 기존 src_local symlink 재사용 (새 복사 불필요, 이미 패치됨)
  - 결과 문서: `/home/ubuntu/analysis/crl_integrative/template_ddb1_combo_9nfr_results.md`
- forbidden change scope:
  - `ik_9nfr_20260625/stage/src/` 변경 금지 (공유 src)
  - `ddb1_contact_early_9nfr_20260626/stage/src_local/` 변경 금지 (이미 패치된 src_local, 재사용만)
  - 기존 실험 WS 변경 금지
  - oracle_generation_9nfr.yaml 변경 금지
- external constraints:
  - GPU: `sudo -u kim sbatch --qos=normal`
  - 출력: `/mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/` (chmod 777)
  - SLURM GPU selector: `memory.free > 75000 MiB`
  - PYTHONPATH: `ddb1_contact_early_9nfr_20260626/stage/src_local` (재사용)
  - ARM-2 num_particles=2 (OOM 방지)

## Non-Goals

- DDB1 full 1140AA (토큰 초과 위험)
- template_steering GD 설정 변경 (이전 8381에서 zero gradient 확인, 변경 불필요)
- DDB1 full MSA (8413/8415에서 cone_dist 악화 확인)
- ARM-1 (gradient guidance only)
- guidance_weight 추가 튜닝

## Done When

- `wc -l .../analysis/scores.tsv` → `10` (header + 9 rows)
- `/home/ubuntu/analysis/crl_integrative/template_ddb1_combo_9nfr_results.md` 존재
  — ARM-0 6 seeds CRBN_RMSD 표 + ARM-2 3 seeds near_attack 표

판정 기준:
- ARM-0 ≥2/6 seeds에서 CRBN_RMSD < 15Å → 조합 유효 (다음: ARM-2 near_attack 분석)
- ARM-2 ≥1 seed에서 near_attack=True → **프로그램 목표 달성**
- ARM-0 전 seeds ≥15Å → 템플릿+DDB1 조합도 CRBN 방향 부족 → 다른 전략 필요

## Rollback

`sudo -u kim scancel <JOBID>` + `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/`
src_local은 변경 없으므로 롤백 불필요.

## Progress Log

- 2026-06-26: 전체 계열 재분석 (8381, 8398, 8413, 8415, 8442, 8443) →
  template+DDB1single-seq 두 부분 해법 미조합 확인. 5.47Å IK 로컬 시연 확인.
  컨트랙트 작성. 사용자 승인.
