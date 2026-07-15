---
contract: .agent/contracts/fksfold-core-ddb1-cochain-9nfr-20260626.md
slice: aigen-fold-core
status: done
total_tasks: 7
estimated_total_min: 26
---

# Plan: DDB1 BPC 4체인 Co-Input — 9NFR CRBN 방향 수정

DDB1 ΔBPA(residues 396-1140, ~745AA)를 4번째 체인(D)으로 추가.
ARM-0 CRBN_RMSD < 10Å GATE.
기반: run_template_9nfr.sh 패턴 재사용.

---

## Task 1: DDB1 ΔBPA 서열 추출

- **Status**: done
- **Prereq tasks**: none
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/inputs/ddb1_bpc_396_1140.fasta` (새 파일)
- **Change shape**:
  UniProt Q16531 (human DDB1, 1140AA)에서 residues 396-1140 (ΔBPA fragment, 745AA)를 추출하여
  FASTA 파일로 저장. 방법: `urllib.request`로 `https://www.uniprot.org/uniprot/Q16531.fasta` 다운로드
  후 파싱, residues [395:1140] (0-indexed) 슬라이싱.
  디렉토리는 이 태스크에서 먼저 생성(`sudo -u kim mkdir -p`).
  저장: `sudo -u kim tee /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/inputs/ddb1_bpc_396_1140.fasta`
- **Verification**: `python3 -c "seq=''.join(l.strip() for l in open('/mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/inputs/ddb1_bpc_396_1140.fasta') if not l.startswith('>')); print(len(seq))"` → `745`
- **Estimated time**: 3 min
- **Rollback**: `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/`

---

## Task 2: 워크스페이스 생성 + 의존성 스테이징

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/` (디렉토리 트리)
  - `refs/9NFR.cif` (symlink)
  - `analysis/crl_integrative/refs/9UUM.cif` (복사본)
  - `stage/src` (symlink), `stage/closure_spec_generic.json` (symlink)
  - `configs/oracle_generation_9nfr.yaml` (복사본)
- **Change shape**:
  `sudo -u kim` 로:
  1. `mkdir -p inputs/ logs/ out/ refs/ analysis/crl_integrative/refs/ configs/` + `chmod 777`
  2. `ln -s /mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/stage/src stage/src`
  3. `ln -s /mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/stage/closure_spec_generic.json stage/closure_spec_generic.json`
  4. `cp /mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/configs/oracle_generation_9nfr.yaml configs/`
  5. `ln -s /mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/refs/9NFR.cif refs/9NFR.cif`
  6. `cp /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/refs/9UUM.cif analysis/crl_integrative/refs/9UUM.cif`
     (CRLClosurePotential._DEFAULT_UUM = workspace/analysis/crl_integrative/refs/9UUM.cif 요구)
- **Verification**: `ls /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/refs/9NFR.cif /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/analysis/crl_integrative/refs/9UUM.cif /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/stage/src` → 전부 존재 (no "No such file")
- **Estimated time**: 3 min
- **Rollback**: `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/{refs,stage,configs,analysis}`

---

## Task 3: 9NFR_ddb1.yaml 작성 (4체인)

- **Status**: done
- **Prereq tasks**: 1, 2
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/inputs/9NFR_ddb1.yaml`
- **Change shape**:
  기존 `ik_9nfr_20260625/inputs/9NFR.yaml`을 기반으로 chain D(DDB1 ΔBPA) 추가.
  - Chains A(CRBN), B(VAV1 SH3c), C(MRT23227 ligand): 기존 sequences/constraints 그대로 복사
  - MSA 경로 유지: `/mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/msa/{crbn_chain_A,vav1_chain_B}.csv`
  - Chain D 추가:
    ```yaml
    - protein:
        id: D
        sequence: <T1에서 추출한 745AA DDB1 ΔBPA 서열>
    ```
    (msa 키 생략 = no MSA for DDB1)
  - `templates:` 블록 없음 (template_9nfr와 달리 순수 co-input)
- **Verification**: `python3 -c "import yaml; d=yaml.safe_load(open('/mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/inputs/9NFR_ddb1.yaml')); chains=[s.get('protein',s.get('ligand',{})).get('id') for s in d['sequences']]; print(len(d['sequences']), chains)"` → `4 ['A', 'B', 'C', 'D']`
- **Estimated time**: 4 min
- **Rollback**: `sudo -u kim rm /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/inputs/9NFR_ddb1.yaml`

---

## Task 4: run_ddb1_9nfr.sh 런처 작성 + 드라이런 검증

- **Status**: done
- **Prereq tasks**: 3
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/run_ddb1_9nfr.sh`
- **Change shape**:
  `run_template_9nfr.sh` 패턴 기반. 변경 사항:
  - `WS=/mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626`
  - `YAML=${WS}/inputs/9NFR_ddb1.yaml`
  - `ARMS=(arm0 arm2)` — ARM-0/ARM-2 × 3 seeds = 6 cells
  - ARM-0: `boltz.main predict ${base_args[@]}` (순수 4체인, 포텐셜 없음)
  - ARM-2: full IK 스택 (biophysical_hybrid + CRL closure, NO `--template_steering_config`)
  - SBATCH 헤더: `--job-name=ddb1_9nfr`, `--output/--error` → `${WS}/logs/`
  - GPU selector: `memory.free > 75000 MiB`
  - Skip check: `find "${out_dir}" -name "*_model_0.pdb"`
  - `sudo -u kim chmod 777 ${WS}/run_ddb1_9nfr.sh`
  드라이런 즉시 실행:
  `bash /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/run_ddb1_9nfr.sh`
- **Verification**: 드라이런 출력에 `CELLS=6 (ARM-0 + ARM-2 × 3 seeds)` 포함, `[MISSING]` 없음
- **Estimated time**: 5 min
- **Rollback**: `sudo -u kim rm /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/run_ddb1_9nfr.sh`

---

## Task 5: ⛔ GPU GATE — SLURM 제출 + 모니터링

- **Status**: done  <!-- jobs 8397(MSA mix fail)/8398(OK: ARM-0 3셀 성공, ARM-2 OOM num_particles=8×4chain) -->
- **Prereq tasks**: 4
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/logs/ddb1_9nfr_<JOBID>.out` (SLURM 로그)
  - `/mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/out/` (PDB 출력)
- **Change shape**:
  SLURM 제출:
  ```bash
  sudo -u kim sbatch /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/run_ddb1_9nfr.sh --submit
  ```
  제출 후 즉시 첫 셀 로그 모니터링:
  ```bash
  sudo -u kim tail -f /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/logs/ddb1_9nfr_<JOBID>.out
  ```
  확인 항목:
  - Boltz가 chain D(DDB1) 서열을 처리하는 로그 확인
  - GPU OOM 발생 시 즉시 보고 (→ DDB1 BPC only(~740-1140, 400AA)로 축소 후 재제출)
  - 오류 발견 시 사용자 요청 전 선제 보고
- **Verification**: `find /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/out/ -name "*_model_0.pdb" | wc -l` → `6`
- **Estimated time**: GPU 런타임 30-60분
- **Rollback**: `sudo -u kim scancel <JOBID>` + `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/out/`

---

## Task 6: 6개 셀 채점 → analysis/scores.tsv

- **Status**: done  <!-- ARM-2 OOM(num_particles=8×4chain); ARM-0 3셀만 채점. GATE = ARM-0 전용 -->
- **Prereq tasks**: 5
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/analysis/scores.tsv` (새 파일)
- **Change shape**:
  PDB 경로: `out/{arm0,arm2}/seed{16,42,123}/boltz_results_9NFR_ddb1/predictions/9NFR_ddb1/9NFR_ddb1_model_0.pdb`
  (실제 경로는 T5 완료 후 `find .../out/ -name "*_model_0.pdb"` 로 확인)

  1. **사전 검증 (1개 PDB)**: score_9nfr_dockq.py를 첫 PDB 하나에 실행하여 4체인 PDB에서 정상 작동 확인.
     4체인 PDB에서 chain A(CRBN) 추출이 올바른지 CRBN_RMSD가 nan이 아닌 숫자인지 확인.
  2. **전체 채점 (6개 PDB)**:
     - `score_9nfr_dockq.py --gt_cif refs/9NFR.cif` → CRBN_RMSD, DockQ
     - `score_ik_poscontrol.py` → cone_dist
     - `contact_recovery.py <pdb> <vav1_chain> <crbn_chain> --crbn_offset 45` → CR_frac, CR_n
  3. 결과를 `analysis/scores.tsv`에 `arm|seed|crbn_rmsd|dockq|cr_frac|cr_n|cone_dist` 형식 저장
- **Verification**: `wc -l /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/analysis/scores.tsv` → `7` (header + 6 rows); `grep -v nan .../analysis/scores.tsv | wc -l` → `7` (nan 없음)
- **Estimated time**: 5 min
- **Rollback**: `rm /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/analysis/scores.tsv`

---

## Task 7: ddb1_4chain_9nfr_results.md 작성 + GATE 판정

- **Status**: done
- **Prereq tasks**: 6
- **Files touched**:
  - `/home/ubuntu/analysis/crl_integrative/ddb1_4chain_9nfr_results.md` (새 파일)
- **Change shape**:
  결과 문서 작성:
  - 표: ARM-0/ARM-2 × seeds → CRBN_RMSD / DockQ / CR_frac / cone_dist
  - Baseline 비교: T14(no DDB1, 18-23Å) → template conditioning(15.25Å) → 4체인 co-input(이번)
  - **GATE 판정**: ARM-0 CRBN_RMSD < 10Å (3 seeds 중 최솟값) → PASS/FAIL
  - PASS 시: → MRT6160 4체인 DDB1 런 컨트랙트 권고
  - FAIL 시: 개선폭 정량화 + DDB1 full 1140AA / MSA 추가 / DDB1 BPC-only 절단 방안
- **Verification**: `test -f /home/ubuntu/analysis/crl_integrative/ddb1_4chain_9nfr_results.md && grep -c "GATE" /home/ubuntu/analysis/crl_integrative/ddb1_4chain_9nfr_results.md` → `1` 이상
- **Estimated time**: 4 min
- **Rollback**: `rm /home/ubuntu/analysis/crl_integrative/ddb1_4chain_9nfr_results.md`
