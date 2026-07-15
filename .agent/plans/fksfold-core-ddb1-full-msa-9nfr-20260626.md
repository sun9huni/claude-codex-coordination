---
contract: .agent/contracts/fksfold-core-ddb1-full-msa-9nfr-20260626.md
slice: aigen-fold-core
status: done
total_tasks: 6
estimated_total_min: 22
note: "bookkeeping reconciled 2026-07-06: T2-T6 were actually executed (job 8413, 3/3 PDBs, scored) but never marked done. Result doc analysis/crl_integrative/ddb1_full_msa_9nfr_results.md already existed as evidence."
---

# Plan: DDB1 ΔBPA + Full MSA 4체인 — 9NFR CRBN 방향 수정 (MSA 보강)

DDB1 single-seq MSA → full ColabFold MSA 교체.
ARM-0 × 3 seeds. GATE 없음 — 결과 수치만 측정.
기반: ddb1_4chain_9nfr_20260626 인프라 전체 재사용.

---

## Task 1: DDB1 ΔBPA full MSA 생성 (ColabFold API)

- **Status**: done  <!-- 1888행 (1887 hits), ColabFold uniref.a3m → Boltz CSV 변환 완료 -->
- **Prereq tasks**: none
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/msa/ddb1_chain_D.csv` (새 파일)
- **Change shape**:
  Python 스크립트를 인라인으로 실행해 ColabFold MMseqs2 API(`https://api.colabfold.com`)를
  호출, DDB1 ΔBPA 서열(745AA) MSA를 취득 후 Boltz CSV 포맷으로 저장.

  1. 기존 FASTA에서 DDB1 ΔBPA 서열 읽기
     (`/mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/inputs/ddb1_bpc_396_1140.fasta`)
  2. `POST https://api.colabfold.com/ticket/msa` (form-data: `q=<FASTA_text>`, `mode=all`)
  3. GET `/ticket/{id}` 폴링 (5s 간격, 최대 15분)
  4. 완료 시 tar.gz 다운로드 → a3m 파일 추출
  5. a3m 파싱 → `key,sequence` CSV 변환
     (행0 = 쿼리, 이후 = 갭 포함 hit 서열 — Boltz 9OTY MSA와 동일 포맷)
  6. `sudo -u kim tee /mnt/kfs2/.../ddb1_full_msa_9nfr_20260626/msa/ddb1_chain_D.csv`

  디렉토리는 이 태스크에서 먼저 생성: `sudo -u kim mkdir -p .../ddb1_full_msa_9nfr_20260626/msa`
- **Verification**: `wc -l /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/msa/ddb1_chain_D.csv` → ≥ 100 (기존 single-seq는 2행이었음)
- **Estimated time**: 5 min (API 대기 포함)
- **Rollback (if this task only)**: `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/`

---

## Task 2: 워크스페이스 생성 + 의존성 스테이징

- **Status**: done (job 8413 실행 근거로 역-확인; ddb1_4chain 인프라 패턴 재사용 확인됨)
- **Prereq tasks**: 1
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/` (디렉토리 트리)
  - `refs/9NFR.cif` (symlink)
  - `analysis/crl_integrative/refs/9UUM.cif` (복사본)
  - `stage/src` (symlink), `stage/closure_spec_generic.json` (symlink)
  - `configs/oracle_generation_9nfr.yaml` (복사본)
- **Change shape**:
  `sudo -u kim` 로:
  1. `mkdir -p inputs/ logs/ out/ refs/ analysis/crl_integrative/refs/ configs/` + `chmod 777`
  2. `ln -s /mnt/kfs2/.../ik_9nfr_20260625/stage/src stage/src`
  3. `ln -s /mnt/kfs2/.../ik_9nfr_20260625/stage/closure_spec_generic.json stage/closure_spec_generic.json`
  4. `cp /mnt/kfs2/.../ik_9nfr_20260625/configs/oracle_generation_9nfr.yaml configs/`
  5. `ln -s /mnt/kfs2/.../ik_9nfr_20260625/refs/9NFR.cif refs/9NFR.cif`
  6. `cp /mnt/kfs2/.../template_9nfr_20260626/refs/9UUM.cif analysis/crl_integrative/refs/9UUM.cif`
  7. DDB1 FASTA 복사 (inputs/ 에 기존 ddb1_bpc_396_1140.fasta 복사)
- **Verification**: `ls /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/refs/9NFR.cif /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/analysis/crl_integrative/refs/9UUM.cif /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/stage/src` → 전부 존재
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/{refs,stage,configs,analysis,inputs}`

---

## Task 3: 9NFR_ddb1_full_msa.yaml 작성

- **Status**: done (job 8413 실행 근거로 역-확인)
- **Prereq tasks**: 1, 2
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/inputs/9NFR_ddb1_full_msa.yaml`
- **Change shape**:
  기존 `ddb1_4chain_9nfr_20260626/inputs/9NFR_ddb1.yaml`을 복사 후
  chain D의 `msa:` 경로만 교체:
  ```yaml
  # 변경 전
  msa: /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/msa/ddb1_chain_D.csv
  # 변경 후
  msa: /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/msa/ddb1_chain_D.csv
  ```
  chains A/B/C(CRBN/VAV1/MRT23227) 및 모든 pocket constraints 변경 없음.
- **Verification**: `python3 -c "import yaml; d=yaml.safe_load(open('/mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/inputs/9NFR_ddb1_full_msa.yaml')); print(len(d['sequences']), [s.get('protein',s.get('ligand',{})).get('id') for s in d['sequences']])"` → `4 ['A', 'B', 'C', 'D']`
- **Estimated time**: 2 min
- **Rollback (if this task only)**: `sudo -u kim rm /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/inputs/9NFR_ddb1_full_msa.yaml`

---

## Task 4: run_ddb1_full_msa_9nfr.sh 런처 작성 + 드라이런

- **Status**: done (job 8413 실행 근거로 역-확인)
- **Prereq tasks**: 3
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/run_ddb1_full_msa_9nfr.sh`
- **Change shape**:
  기존 `ddb1_4chain_9nfr_20260626/run_ddb1_9nfr.sh` 복사 후 3가지만 변경:
  ```bash
  WS=/mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626
  YAML=${WS}/inputs/9NFR_ddb1_full_msa.yaml
  # ARMS=(arm0 arm2) → ARM-2 OOM이므로 arm0만
  ARMS=(arm0)
  # job-name
  #SBATCH --job-name=ddb1_full_msa_9nfr
  ```
  드라이런 즉시 실행:
  `bash /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/run_ddb1_full_msa_9nfr.sh`
- **Verification**: 드라이런 출력에 `CELLS=3 (ARM-0 × 3 seeds)` 포함, `[MISSING]` 없음
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `sudo -u kim rm /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/run_ddb1_full_msa_9nfr.sh`

---

## Task 5: ⛔ GPU GATE — SLURM 제출 + 모니터링

- **Status**: done (job 8413 COMPLETED, arm0×3 seeds, 3/3 PDBs)
- **Prereq tasks**: 4
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/logs/ddb1_full_msa_9nfr_<JOBID>.out`
  - `/mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/out/` (PDB 출력)
- **Change shape**:
  ```bash
  sudo -u kim sbatch /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/run_ddb1_full_msa_9nfr.sh --submit
  ```
  제출 후 첫 셀 로그 즉시 모니터링:
  - DDB1 chain D MSA 로딩 라인 확인 (`Processing 1 inputs` 또는 MSA hit 수)
  - GPU OOM 발생 시 즉시 보고
  - 오류 발견 시 사용자 요청 전 선제 보고
- **Verification**: `find /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/out/ -name "*_model_0.pdb" | wc -l` → `3`
- **Estimated time**: GPU 런타임 20-40분
- **Rollback (if this task only)**: `sudo -u kim scancel <JOBID>` + `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/out/`

---

## Task 6: 채점 + 결과 문서

- **Status**: done (analysis/crl_integrative/ddb1_full_msa_9nfr_results.md 존재. 결론: Phase1 FAIL — full MSA 단독으론 CRBN_RMSD 개선 없음(20.6-24.9Å), cone_dist는 single-seq(14.2Å)보다 악화(27.3-40.0Å). Phase2(contact constraints + IK ARM-2)로 진행 권고 → template-ddb1-combo-20260626이 그 후속.)
- **Prereq tasks**: 5
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/analysis/scores.tsv` (새 파일)
  - `/home/ubuntu/analysis/crl_integrative/ddb1_full_msa_9nfr_results.md` (새 파일)
- **Change shape**:
  PDB 경로: `out/arm0/seed{16,42,123}/boltz_results_9NFR_ddb1_full_msa/predictions/9NFR_ddb1_full_msa/9NFR_ddb1_full_msa_model_0.pdb`
  (실제 경로는 T5 완료 후 `find .../out/ -name "*_model_0.pdb"` 로 확인)

  1. `score_9nfr_dockq.py` → CRBN_RMSD, DockQ
  2. `score_ik_poscontrol.py` → cone_dist
  3. `contact_recovery.py <pdb> B A --crbn_offset 45` → CR_frac, CR_n
  4. `analysis/scores.tsv` 작성 (`arm|seed|crbn_rmsd|dockq|cr_frac|cr_n|cone_dist|near_attack`)
  5. `ddb1_full_msa_9nfr_results.md` 작성:
     - 3 seed 채점 표
     - 이전 실험 직접 비교:
       | 실험 | CRBN_RMSD 최솟값 | DockQ 최댓값 | cone_dist |
       |---|---|---|---|
       | T14 baseline (no DDB1) | 18-23Å | 0.007-0.088 | 35-64Å |
       | Template conditioning | 15.25Å | — | 34-51Å |
       | DDB1 ΔBPA single-seq MSA | 20.62Å | 0.048 | 14-18Å |
       | **DDB1 ΔBPA full MSA (이번)** | **?** | **?** | **?** |
     - 다음 실험 결정 (CRBN_RMSD 기준: <15Å이면 A(full 1140AA) 진행, <10Å이면 MRT6160 진행)
- **Verification**: `wc -l /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/analysis/scores.tsv` → `4` (header + 3 rows); `test -f /home/ubuntu/analysis/crl_integrative/ddb1_full_msa_9nfr_results.md` → 존재
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/analysis/scores.tsv /home/ubuntu/analysis/crl_integrative/ddb1_full_msa_9nfr_results.md`
