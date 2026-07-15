---
contract: .agent/contracts/fksfold-core-ddb1-fullstk-9nfr-20260626.md
slice: aigen-fold-core
status: pending
total_tasks: 5
estimated_total_min: 25
---

# Plan: DDB1 full-stack 9NFR — contact constraints + CRL IK (ARM-2)

9UUM-검증 DDB1-CRBN contact constraint 12쌍 + CRL closure IK(ARM-2 num_particles=2).
ARM-0 × 3 seeds + ARM-2 × 3 seeds = 6 cells.
기반: ddb1_full_msa_9nfr_20260626 인프라 전체 재사용.

---

## Task 1: 워크스페이스 생성 + 의존성 스테이징

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/` (디렉토리 트리)
  - `refs/9NFR.cif` (symlink)
  - `analysis/crl_integrative/refs/9UUM.cif` (복사본)
  - `stage/src` (symlink), `stage/closure_spec_generic.json` (symlink)
  - `configs/oracle_generation_9nfr.yaml` (복사본)
  - `msa/` symlink or hardlink (Phase 1 MSA 재사용)
- **Change shape**:
  Phase 1 워크스페이스와 동일한 구조. ubuntu 소유이므로 sudo 불필요.
  ```bash
  WS=/mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626
  PHASE1=/mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626
  BASE=/mnt/kfs2/data/users/ubuntu

  mkdir -p ${WS}/{inputs,logs,out,refs,analysis/crl_integrative/refs,configs,stage,msa}
  chmod 777 ${WS}/logs ${WS}/out

  # symlinks
  ln -sfn ${BASE}/ik_9nfr_20260625/stage/src ${WS}/stage/src
  ln -sfn ${BASE}/ik_9nfr_20260625/stage/closure_spec_generic.json ${WS}/stage/closure_spec_generic.json
  ln -sfn ${BASE}/ik_9nfr_20260625/refs/9NFR.cif ${WS}/refs/9NFR.cif

  # 파일 복사
  cp ${BASE}/ik_9nfr_20260625/configs/oracle_generation_9nfr.yaml ${WS}/configs/
  cp ${BASE}/template_9nfr_20260626/refs/9UUM.cif ${WS}/analysis/crl_integrative/refs/9UUM.cif

  # MSA 재사용 (Phase 1 CSV symlink)
  ln -sfn ${PHASE1}/msa/ddb1_chain_D.csv ${WS}/msa/ddb1_chain_D.csv
  ```
- **Verification**:
  ```bash
  ls /mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/refs/9NFR.cif \
     /mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/analysis/crl_integrative/refs/9UUM.cif \
     /mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/stage/src \
     /mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/msa/ddb1_chain_D.csv
  ```
  → 전부 존재
- **Estimated time**: 2 min
- **Rollback**: `rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/`

---

## Task 2: 9NFR_ddb1_fullstk.yaml 작성

- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/inputs/9NFR_ddb1_fullstk.yaml`
- **Change shape**:
  Phase 1 YAML(`9NFR_ddb1_full_msa.yaml`)을 베이스로:
  1. chain D `msa:` 경로를 새 워크스페이스로 업데이트
  2. 기존 pocket constraints 2개(CRBN TBD + VAV1 surface) 유지
  3. DDB1(D)-CRBN(A) `contact` constraint 12개 추가

  추가할 contact constraint 블록:
  ```yaml
  # DDB1(D)-CRBN(A) interface — 9UUM Cα≤8Å top-12 pairs (pred seqid)
  # CRBN pred = 9UUM seqid - 45, DDB1 pred = 9UUM seqid - 395
  - contact:
      token1: [A, 192]
      token2: [D, 638]
      max_distance: 9.0
  - contact:
      token1: [A, 193]
      token2: [D, 610]
      max_distance: 9.0
  - contact:
      token1: [A, 151]
      token2: [D, 576]
      max_distance: 9.0
  - contact:
      token1: [A, 258]
      token2: [D, 556]
      max_distance: 9.0
  - contact:
      token1: [A, 194]
      token2: [D, 610]
      max_distance: 9.0
  - contact:
      token1: [A, 151]
      token2: [D, 575]
      max_distance: 9.0
  - contact:
      token1: [A, 194]
      token2: [D, 327]
      max_distance: 9.0
  - contact:
      token1: [A, 145]
      token2: [D, 557]
      max_distance: 9.0
  - contact:
      token1: [A, 202]
      token2: [D, 447]
      max_distance: 9.0
  - contact:
      token1: [A, 202]
      token2: [D, 446]
      max_distance: 9.0
  - contact:
      token1: [A, 193]
      token2: [D, 638]
      max_distance: 9.0
  - contact:
      token1: [A, 152]
      token2: [D, 608]
      max_distance: 9.0
  ```

- **Verification**:
  ```bash
  python3 -c "
  import yaml
  d = yaml.safe_load(open('/mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/inputs/9NFR_ddb1_fullstk.yaml'))
  chains = [s.get('protein', s.get('ligand', {})).get('id') for s in d['sequences']]
  contacts = [c for c in d.get('constraints', []) if 'contact' in c]
  pockets = [c for c in d.get('constraints', []) if 'pocket' in c]
  print(f'chains={chains}, contacts={len(contacts)}, pockets={len(pockets)}')
  "
  ```
  → `chains=['A', 'B', 'C', 'D'], contacts=12, pockets=2`
- **Estimated time**: 4 min
- **Rollback**: `rm /mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/inputs/9NFR_ddb1_fullstk.yaml`

---

## Task 3: run_ddb1_fullstk_9nfr.sh 런처 작성 + 드라이런

- **Status**: pending
- **Prereq tasks**: 2
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/run_ddb1_fullstk_9nfr.sh`
- **Change shape**:
  Phase 1 런처(`run_ddb1_full_msa_9nfr.sh`)를 베이스로 다음만 변경:
  ```bash
  # 변경 1: WS + YAML + 런처명
  WS="/mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626"
  YAML="${WS}/inputs/9NFR_ddb1_fullstk.yaml"
  ORACLE_CFG="${WS}/configs/oracle_generation_9nfr.yaml"
  CLOSURE_SPEC="${WS}/stage/closure_spec_generic.json"

  # 변경 2: ARM 목록
  declare -a ARMS=(arm0 arm2)

  # 변경 3: SBATCH 헤더
  #SBATCH --job-name=ddb1_fullstk_9nfr
  #SBATCH --output=.../ddb1_fullstk_9nfr_%j.out
  #SBATCH --error=.../ddb1_fullstk_9nfr_%j.err

  # 변경 4: arm2 case 추가
  arm2)
    CUDA_VISIBLE_DEVICES="${gpu}" \
      "${ROOT}/opt/conda/bin/python" -m boltz.main predict \
        "${base_args[@]}" \
        --use_potentials --potential_type vanilla \
        --num_particles 2 \
        --use_interface_steering \
        --interface_scoring_type biophysical_hybrid \
        --biophysical_enabled --biophysical_config "${ORACLE_CFG}" \
        --interface_lambda 20 --interface_resampling_interval 3 \
        --enable_interface_gd --interface_gd_lr 0.01 --gd_start_t 0.5 \
        --crl_closure_enabled \
        --crl_closure_config "${CLOSURE_SPEC}" \
        --crl_closure_weight 1.0 \
        --crl_gd_start_t 0.5 \
        > "${log}" 2>&1 || true
    ;;
  ```
  드라이런 즉시 실행.
- **Verification**: 드라이런 출력에 `CELLS=6 (ARM-0 + ARM-2 × 3 seeds)`, `[MISSING]` 없음
- **Estimated time**: 4 min
- **Rollback**: `rm /mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/run_ddb1_fullstk_9nfr.sh`

---

## Task 4: ⛔ GPU GATE — SLURM 제출 + 모니터링

- **Status**: pending
- **Prereq tasks**: 3
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/logs/ddb1_fullstk_9nfr_<JOBID>.out`
  - `/mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/out/` (PDB 출력)
- **Change shape**:
  ```bash
  sudo -u kim sbatch /mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/run_ddb1_fullstk_9nfr.sh --submit
  ```
  제출 후 즉시 첫 셀 로그 모니터링:
  - ARM-0 seed16 로그 → "Processing 1 inputs", GPU active, no error → OK
  - ARM-2 seed16 로그 → CRL closure 초기화 로그 확인:
    `[CRLClosureIK] generic mode: N LYS NZ found in chain B` → N ≥ 4 이어야 정상
  - ARM-2 OOM 여부: num_particles=2에서도 OOM 발생 시 즉시 보고
    (대응: num_particles=1로 재시도)
- **Verification**: `find /mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/out/ -name "*_model_0.pdb" | wc -l` → `6`
- **Estimated time**: GPU 런타임 30-60분
- **Rollback**: `sudo -u kim scancel <JOBID>` + `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/out/`

---

## Task 5: 채점 + 결과 문서

- **Status**: pending
- **Prereq tasks**: 4
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/analysis/scores.tsv`
  - `/home/ubuntu/analysis/crl_integrative/ddb1_fullstk_9nfr_results.md`
- **Change shape**:
  ```bash
  # CRBN_RMSD + DockQ
  python3 /home/ubuntu/analysis/crl_integrative/score_9nfr_dockq.py \
    --pdb <pdb> --gt ${WS}/refs/9NFR.cif

  # cone_dist + near_attack (인라인 Kabsch 스크립트 재사용)
  python3 /home/ubuntu/analysis/crl_integrative/compute_cone_dist.py \
    --pdb <pdb> --uum ${WS}/analysis/crl_integrative/refs/9UUM.cif

  # contact_recovery (DDB1-CRBN 인터페이스 복구율)
  python3 /home/ubuntu/analysis/crl_integrative/contact_recovery.py \
    <pdb> A D --ddb1_offset 395 --crbn_offset 45
  ```

  `analysis/scores.tsv` 포맷:
  ```
  arm	seed	crbn_rmsd	dockq	fnat	cone_dist	near_attack	ddb1_cr_frac
  ```

  `ddb1_fullstk_9nfr_results.md` 포함 내용:
  - 6셀 채점 표 (ARM-0 + ARM-2 × seeds)
  - 실험 계열 비교:

    | 실험 | CRBN_RMSD (Å) 최솟값 | cone_dist (Å) 최솟값 | near_attack |
    |---|---|---|---|
    | T14 baseline (no DDB1) | 18-23 | 35-64 | False |
    | Template conditioning | 15.25 | 34-51 | False |
    | DDB1 ΔBPA single-seq MSA | 20.6 | 14.2 | False |
    | DDB1 ΔBPA full MSA (Phase 1) | 20.6 | 27.3 | False |
    | **DDB1 ΔBPA full MSA + contact + IK (이번)** | **?** | **?** | **?** |

  - 다음 실험 결정:
    - ARM-0 CRBN_RMSD < 10Å → contact constraint 단독으로 충분 (IK 필요 없음)
    - ARM-2 near_attack=True → CRBN_RMSD가 OK이고 IK 작동 → MRT6160 런 진행
    - ARM-2 CRBN_RMSD > 15Å → constraint 효과 미달 → DDB1 full 1140AA + contact 시도
    - ARM-2 OOM(num_particles=2) → num_particles=1 재시도

- **Verification**:
  `wc -l /mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/analysis/scores.tsv` → `7`
  `test -f /home/ubuntu/analysis/crl_integrative/ddb1_fullstk_9nfr_results.md` → 존재
- **Estimated time**: 8 min
- **Rollback**:
  `rm /mnt/kfs2/data/users/ubuntu/ddb1_fullstk_9nfr_20260626/analysis/scores.tsv`
  `rm /home/ubuntu/analysis/crl_integrative/ddb1_fullstk_9nfr_results.md`
