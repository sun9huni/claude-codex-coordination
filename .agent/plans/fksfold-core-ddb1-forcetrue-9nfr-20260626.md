---
contract: .agent/contracts/fksfold-core-ddb1-forcetrue-9nfr-20260626.md
slice: aigen-fold-core
status: done
total_tasks: 5
estimated_total_min: 20
note: "bookkeeping reconciled 2026-07-06: T1-T4 executed 2026-06-26 (job 8442) but never marked done; T5 (scoring) was genuinely never run until now. Result: analysis/crl_integrative/ddb1_forcetrue_9nfr_results.md — hypothesis FAIL (3-4/12 contacts satisfied, CRBN_RMSD unchanged 20-22Å vs force:false)."
---

# Plan: DDB1 contact force:true 9NFR — BPC 재배향 hard penalty

Phase 2(force:false) 0/12 contact 충족 → force:true 교체.
ARM-0 × 3 seeds. Phase 2 인프라 최대 재사용.

---

## Task 1: 워크스페이스 생성 + 의존성 스테이징

- **Status**: done (job 8442 실행 근거로 역-확인)
- **Prereq tasks**: none
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/` (디렉토리 트리)
  - `refs/9NFR.cif` (symlink)
  - `analysis/crl_integrative/refs/9UUM.cif` (복사)
  - `stage/src` (symlink), `stage/closure_spec_generic.json` (symlink)
  - `configs/oracle_generation_9nfr.yaml` (복사)
  - `msa/ddb1_chain_D.csv` (symlink to Phase 1 MSA)
- **Change shape**:
  Phase 2 워크스페이스와 동일 패턴. ubuntu 소유이므로 sudo 불필요.
  ```bash
  WS=/mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626
  PHASE1=/mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626
  BASE=/mnt/kfs2/data/users/ubuntu

  mkdir -p ${WS}/{inputs,logs,out,refs,analysis/crl_integrative/refs,configs,stage,msa}
  chmod 777 ${WS}/logs ${WS}/out

  ln -sfn ${BASE}/ik_9nfr_20260625/stage/src ${WS}/stage/src
  ln -sfn ${BASE}/ik_poscontrol_20260625/stage/closure_spec_generic.json ${WS}/stage/closure_spec_generic.json
  ln -sfn ${BASE}/ik_9nfr_20260625/refs/9NFR.cif ${WS}/refs/9NFR.cif
  cp ${BASE}/ik_9nfr_20260625/configs/oracle_generation_9nfr.yaml ${WS}/configs/
  cp ${BASE}/ddb1_fullstk_9nfr_20260626/analysis/crl_integrative/refs/9UUM.cif ${WS}/analysis/crl_integrative/refs/9UUM.cif
  ln -sfn ${PHASE1}/msa/ddb1_chain_D.csv ${WS}/msa/ddb1_chain_D.csv
  ```
- **Verification**:
  ```bash
  ls /mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/refs/9NFR.cif \
     /mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/msa/ddb1_chain_D.csv \
     /mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/stage/src
  ```
  → 전부 존재
- **Estimated time**: 2 min
- **Rollback**: `rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/`

---

## Task 2: 9NFR_ddb1_forcetrue.yaml 작성

- **Status**: done (job 8442 실행 근거로 역-확인; YAML 12/12 force:true 확인됨, 실제 파일 확인)
- **Prereq tasks**: 1
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/inputs/9NFR_ddb1_forcetrue.yaml`
- **Change shape**:
  Phase 2 YAML(`9NFR_ddb1_fullstk.yaml`)을 복사 후 두 가지만 변경:
  1. chain D `msa:` 경로를 새 WS로 업데이트
  2. 12개 contact 블록에 `force: true` 추가

  변경 전:
  ```yaml
  - contact:
      token1: [A, 192]
      token2: [D, 638]
      max_distance: 9.0
  ```
  변경 후:
  ```yaml
  - contact:
      token1: [A, 192]
      token2: [D, 638]
      max_distance: 9.0
      force: true
  ```
  pocket constraints 2개 + chain ABCD 변경 없음.
- **Verification**:
  ```bash
  python3 -c "
  import yaml
  d = yaml.safe_load(open('/mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/inputs/9NFR_ddb1_forcetrue.yaml'))
  contacts = [c for c in d.get('constraints',[]) if 'contact' in c]
  forced = [c for c in contacts if c['contact'].get('force') == True]
  pockets = [c for c in d.get('constraints',[]) if 'pocket' in c]
  print(f'contacts={len(contacts)}, forced={len(forced)}, pockets={len(pockets)}')
  "
  ```
  → `contacts=12, forced=12, pockets=2`
- **Estimated time**: 3 min
- **Rollback**: `rm /mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/inputs/9NFR_ddb1_forcetrue.yaml`

---

## Task 3: run_ddb1_forcetrue_9nfr.sh 런처 작성 + 드라이런

- **Status**: done (job 8442 실행 근거로 역-확인)
- **Prereq tasks**: 2
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/run_ddb1_forcetrue_9nfr.sh`
- **Change shape**:
  Phase 2 런처(`run_ddb1_fullstk_9nfr.sh`) 복사 후 다음만 변경:
  ```bash
  # 변경 1: WS + YAML
  WS="/mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626"
  YAML="${WS}/inputs/9NFR_ddb1_forcetrue.yaml"

  # 변경 2: ARM 목록 (ARM-0만)
  declare -a ARMS=(arm0)

  # 변경 3: SBATCH 헤더
  #SBATCH --job-name=ddb1_forcetrue_9nfr
  #SBATCH --output=.../ddb1_forcetrue_9nfr_%j.out
  #SBATCH --error=.../ddb1_forcetrue_9nfr_%j.err
  ```
  드라이런 즉시 실행.
- **Verification**: 드라이런 출력에 `CELLS=3 (ARM-0 × 3 seeds)`, `[MISSING]` 없음
- **Estimated time**: 3 min
- **Rollback**: `rm /mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/run_ddb1_forcetrue_9nfr.sh`

---

## Task 4: ⛔ GPU GATE — SLURM 제출 + 모니터링

- **Status**: done (job 8442 COMPLETED 2026-06-26, arm0×3 seeds, 3/3 PDBs confirmed present)
- **Prereq tasks**: 3
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/logs/ddb1_forcetrue_9nfr_<JOBID>.out`
  - `/mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/out/` (PDB 출력)
- **Change shape**:
  ```bash
  sudo -u kim sbatch /mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/run_ddb1_forcetrue_9nfr.sh --submit
  ```
  제출 후 즉시 첫 셀 로그 포그라운드 모니터링:
  - ARM-0 seed16 로그 → "Processing 1 inputs", GPU active, no error → OK
  - force:true 적용 확인: 로그에 contact constraint 관련 메시지 또는 첫 PDB 출력 후 contact 거리 확인
  - OOM 발생 시 즉시 보고 (force:true는 ARM-0이므로 OOM 위험 낮음)
- **Verification**: `find /mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/out/ -name "*_model_0.pdb" | wc -l` → `3`
- **Estimated time**: GPU 런타임 20-40분
- **Rollback**: `sudo -u kim scancel <JOBID>` + `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/out/`

---

## Task 5: 채점 + 결과 문서

- **Status**: done (2026-07-06, 부기 정리 중 사후 완료. scores.tsv + ddb1_forcetrue_9nfr_results.md 작성.
  결과: contact_satisfied 3-4/12(25-33%), CRBN_RMSD 20.0-22.3Å — force:false 단계와 통계적으로 구분 안 됨 →
  **가설 FAIL**(force:true 단독으론 CRBN 재배향 불충분). 단 template-ddb1-combo(force:true + template conditioning
  결합)가 이 시리즈 최고 성과(9-11Å)를 낸 것과 대조하면, force:true는 template prior와 결합해야만 효과를 보이는
  보조 조건이라는 해석이 이 실험의 실질적 기여.)
- **Prereq tasks**: 4
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/analysis/scores.tsv`
  - `/home/ubuntu/analysis/crl_integrative/ddb1_forcetrue_9nfr_results.md`
- **Change shape**:
  ```bash
  # CRBN_RMSD + DockQ
  python3 /home/ubuntu/analysis/crl_integrative/score_9nfr_dockq.py \
    --pdb <pdb> --gt ${WS}/refs/9NFR.cif

  # cone_dist + near_attack (인라인 Kabsch)
  python3 /home/ubuntu/analysis/crl_integrative/compute_cone_dist.py \
    --pdb <pdb> --uum ${WS}/analysis/crl_integrative/refs/9UUM.cif

  # contact 충족률 (12쌍)
  python3 - <<'PYEOF'
  import gemmi, numpy as np
  # 12쌍 Cα 거리 계산, ≤9Å 충족 수 카운트
  PYEOF
  ```

  `scores.tsv` 포맷:
  ```
  arm	seed	crbn_rmsd	dockq	fnat	cone_dist	near_attack	contact_satisfied
  ```

  `ddb1_forcetrue_9nfr_results.md` 포함:
  - 3셀 채점 표 (contact_satisfied/12 포함)
  - 실험 계열 전체 비교 (force:false vs force:true)
  - 판정: CRBN_RMSD 기준 다음 실험 결정
- **Verification**:
  `wc -l /mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/analysis/scores.tsv` → `4`
  `test -f /home/ubuntu/analysis/crl_integrative/ddb1_forcetrue_9nfr_results.md` → 존재
- **Estimated time**: 6 min
- **Rollback**:
  `rm /mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/analysis/scores.tsv`
  `rm /home/ubuntu/analysis/crl_integrative/ddb1_forcetrue_9nfr_results.md`
