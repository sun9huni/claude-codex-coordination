---
contract: .agent/contracts/fksfold-core-ddb1-contact-early-9nfr-20260626.md
slice: aigen-fold-core
status: done
total_tasks: 5
estimated_total_min: 35
---

# Plan: DDB1 contact-early — ContactPotentital guidance 조기 활성화

ContactPotentital guidance_weight = 0 (steps 1-15) 제거 → constant 1.5 (step 1부터).
force:true YAML 재사용. ARM-0 × 3 seeds + ARM-2 × 3 seeds = 6 cells.
핵심 변경: `potentials.py` 2줄 (guidance_interval + guidance_weight).

---

## Task 1: 워크스페이스 생성 + src 로컬 복사

- **Status**: done
- **Prereq tasks**: none
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/` (디렉토리 트리)
  - `/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/stage/src_local/` (src 전체 복사)
  - symlinks: refs/9NFR.cif, stage/closure_spec_generic.json, msa/ddb1_chain_D.csv
  - copies: configs/oracle_generation_9nfr.yaml, analysis/crl_integrative/refs/9UUM.cif
- **Change shape**:
  ```bash
  WS=/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626
  BASE=/mnt/kfs2/data/users/ubuntu
  SRC_ORIG=${BASE}/ik_9nfr_20260625/stage/src
  FORCETRUE=${BASE}/ddb1_forcetrue_9nfr_20260626

  mkdir -p ${WS}/{inputs,logs,out,refs,analysis/crl_integrative/refs,configs,stage,msa}
  chmod 777 ${WS}/logs ${WS}/out

  # src 로컬 복사 (공유 symlink 대신 실제 복사본)
  cp -rp ${SRC_ORIG} ${WS}/stage/src_local

  # symlinks (src_local 제외 나머지는 symlink OK)
  ln -sfn ${BASE}/ik_9nfr_20260625/refs/9NFR.cif ${WS}/refs/9NFR.cif
  ln -sfn ${BASE}/ik_9nfr_20260625/stage/closure_spec_generic.json \
      ${WS}/stage/closure_spec_generic.json
  ln -sfn ${FORCETRUE}/msa/ddb1_chain_D.csv ${WS}/msa/ddb1_chain_D.csv

  # 복사본
  cp ${BASE}/ik_9nfr_20260625/configs/oracle_generation_9nfr.yaml ${WS}/configs/
  cp ${BASE}/template_9nfr_20260626/refs/9UUM.cif \
      ${WS}/analysis/crl_integrative/refs/9UUM.cif
  ```
- **Verification**:
  ```bash
  ls /mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/stage/src_local/boltz_extension/steering/potentials.py \
     /mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/refs/9NFR.cif \
     /mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/msa/ddb1_chain_D.csv
  ```
  → 셋 다 존재. src_local이 symlink가 아닌 실제 파일인지 확인:
  ```bash
  file /mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/stage/src_local/boltz_extension/steering/potentials.py
  ```
  → `Python script, ...` (symlink이면 FAIL)
- **Estimated time**: 3 min
- **Rollback**: `rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/`

---

## Task 2: potentials.py 패치 — guidance_interval + guidance_weight

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/stage/src_local/boltz_extension/steering/potentials.py`
- **Change shape**:
  lines 771-774 (ContactPotentital base_params):
  ```python
  # 변경 전 (lines 771-774)
  "guidance_interval": 4,
  "guidance_weight": PiecewiseStepFunction(
      thresholds=[0.25, 0.75], values=[0.0, 0.5, 1.0]
  ),

  # 변경 후
  "guidance_interval": 1,
  "guidance_weight": 1.5,
  ```
  2줄 수정 (interval 1줄 + weight 3줄 → 1줄). PiecewiseStepFunction import는 여전히
  다른 곳에서 사용 중이므로 제거 금지.
- **Verification**:
  ```bash
  grep -n "guidance_interval\|guidance_weight\|PiecewiseStep" \
    /mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/stage/src_local/boltz_extension/steering/potentials.py \
    | grep -A2 -B2 "ContactPotentital" | head -20
  ```
  ContactPotentital 블록 내: `"guidance_interval": 1` + `"guidance_weight": 1.5` 확인.
  공유 src는 변경 없어야 함:
  ```bash
  grep "guidance_interval" /mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/stage/src/boltz_extension/steering/potentials.py | grep -c "4"
  ```
  → `1` (공유 src는 여전히 4)
- **Estimated time**: 3 min
- **Rollback**: `cp /mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/stage/src/boltz_extension/steering/potentials.py /mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/stage/src_local/boltz_extension/steering/potentials.py`

---

## Task 3: YAML 복사 + 런처 작성 + 드라이런

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/inputs/9NFR_ddb1_contact_early.yaml`
  - `/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/run_ddb1_contact_early_9nfr.sh`
- **Change shape**:
  YAML: forcetrue YAML 복사 후 msa 경로만 확인 (이미 절대경로이므로 변경 불필요할 수 있음).
  ```bash
  cp /mnt/kfs2/data/users/ubuntu/ddb1_forcetrue_9nfr_20260626/inputs/9NFR_ddb1_forcetrue.yaml \
     /mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/inputs/9NFR_ddb1_contact_early.yaml
  ```
  YAML 내 msa 경로 확인: 절대경로면 변경 불필요. 상대경로면 절대경로로 교체.

  런처 핵심 변경 (forcetrue 런처 대비):
  - `WS`, `YAML`, `job-name`, `--output/--error` 경로
  - `ARMS=(arm0 arm2)` (arm2 추가)
  - `PYTHONPATH="${WS}/stage/src_local:${WS}/stage/src_local/boltz_extension:$PYTHONPATH"` 우선 적용
  - arm2 case 블록 추가 (biophysical_hybrid + CRL IK, num_particles=2)

  런처 PYTHONPATH 설정 방식:
  ```bash
  # src_local을 Python이 먼저 보도록 prepend
  export PYTHONPATH="/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/stage/src_local:${PYTHONPATH:-}"
  ```
  실제 Python 실행 시 `-m boltz.main` → src_local 내 boltz + boltz_extension이 우선 임포트됨.
- **Verification**:
  드라이런: `bash .../run_ddb1_contact_early_9nfr.sh` (--submit 없이)
  → `CELLS=6 (ARM-0 × 3 + ARM-2 × 3)`, `[MISSING]` 없음.
  YAML 검증:
  ```bash
  python3 -c "
  import yaml
  d = yaml.safe_load(open('/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/inputs/9NFR_ddb1_contact_early.yaml'))
  contacts = [c for c in d.get('constraints',[]) if 'contact' in c]
  forced = [c for c in contacts if c['contact'].get('force')]
  print(f'contacts={len(contacts)}, forced={len(forced)}')
  "
  ```
  → `contacts=12, forced=12`
- **Estimated time**: 5 min
- **Rollback**: `rm /mnt/.../inputs/9NFR_ddb1_contact_early.yaml /mnt/.../run_ddb1_contact_early_9nfr.sh`

---

## Task 4: ⛔ GPU GATE — SLURM 제출 + 모니터링

- **Status**: done
- **Prereq tasks**: 3
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/logs/ddb1_contact_early_9nfr_<JOBID>.out`
  - `/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/out/` (PDB)
- **Change shape**:
  ```bash
  sudo -u kim sbatch /mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/run_ddb1_contact_early_9nfr.sh --submit
  ```
  제출 직후 첫 셀 로그 포그라운드 감시:
  - `boltz_extension.steering.potentials` import 로그에서 ContactPotentital 설정 확인
  - ARM-0 seed16 로그: GPU active, "Processing 1 inputs"
  - ARM-2 seed16 로그: `[CRLClosureIK] generic mode: N LYS NZ found` (N ≥ 4)
  - OOM 발생 시 즉시 보고 (num_particles=2에서도 OOM → num_particles=1 재시도)
- **Verification**: `find /mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/out/ -name "*_model_0.pdb" | wc -l` → `6`
- **Estimated time**: GPU 런타임 40-70분
- **Rollback**: `sudo -u kim scancel <JOBID>` + `sudo -u kim rm -rf /mnt/.../out/`

---

## Task 5: 채점 + 결과 문서

- **Status**: done
- **Prereq tasks**: 4
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/analysis/scores.tsv`
  - `/home/ubuntu/analysis/crl_integrative/ddb1_contact_early_9nfr_results.md`
- **Change shape**:
  기존 채점 스크립트 재사용:
  ```bash
  # CRBN_RMSD + DockQ
  python3 /home/ubuntu/analysis/crl_integrative/score_9nfr_dockq.py \
    --pdb <pdb> --gt .../refs/9NFR.cif

  # cone_dist + near_attack
  python3 /home/ubuntu/analysis/crl_integrative/compute_cone_dist.py \
    --pdb <pdb> --uum .../refs/9UUM.cif

  # contact_satisfied (DDB1-CRBN 12쌍)
  python3 /home/ubuntu/analysis/crl_integrative/contact_recovery.py \
    <pdb> A D --ddb1_offset 395 --crbn_offset 45
  ```
  `scores.tsv` 포맷: `arm  seed  crbn_rmsd  dockq  fnat  lrmsd  irmsd  cone_dist  near_attack  contact_satisfied`

  `ddb1_contact_early_9nfr_results.md`:
  - 6 cell 채점 표
  - 실험 계열 비교 표 (전 4개 실험 + 이번)
  - PASS/FAIL 판정 + 다음 실험 결정

- **Verification**:
  `wc -l /mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626/analysis/scores.tsv` → `7`
  `test -f /home/ubuntu/analysis/crl_integrative/ddb1_contact_early_9nfr_results.md`
- **Estimated time**: 8 min
- **Rollback**: `rm .../scores.tsv /home/ubuntu/analysis/crl_integrative/ddb1_contact_early_9nfr_results.md`
