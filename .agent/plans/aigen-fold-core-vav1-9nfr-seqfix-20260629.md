---
contract: .agent/contracts/aigen-fold-core-vav1-9nfr-seqfix-20260629.md
slice: aigen-fold-core
status: in-progress
total_tasks: 7
estimated_total_min: 55
---

# Plan: VAV1 9NFR 서열 정합 재구성

9NFR 결정체 체인 서열로 YAML/MSA/contacts 완전 재구성 → 진짜 DQcv 측정.

사전 확인된 9NFR 체인:
- Chain A: DDB1 1119aa, resid 2-1140 (gaps 있음, enumerate map 필요)
- Chain B: CRBN 353aa, resid 77-436 → YAML_pos = resid − 76
- Chain C: VAV1-SH3c 55aa, resid 785-839 → YAML_pos = resid − 784
- 리간드: A1BYX (MRT-23227), SMILES = `Cn1ccc(COc2ccc(-c3cccc([C@H]4CCC(=O)NC4=O)c3Cl)cc2)n1`

9NFR.cif 경로: `/mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/refs/9NFR.cif`

---

## Task 1: 워크스페이스 디렉토리 + symlinks + closure_spec 복사

- **Status**: done
- **Prereq tasks**: none
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/{inputs,logs,out,msa,stage}/`
  - `stage/src_local` → symlink
  - `stage/closure_spec_seqfix.json`

- **Change shape**:
  ```bash
  WS=/mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629
  EARLY=/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626
  PREV=/mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626

  sudo -u kim mkdir -p ${WS}/{inputs,logs,out,msa,stage}
  sudo -u kim chmod 777 ${WS}/logs ${WS}/out
  sudo -u kim ln -sfn ${EARLY}/stage/src_local ${WS}/stage/src_local
  sudo -u kim cp ${PREV}/stage/closure_spec_contact_fix.json \
      ${WS}/stage/closure_spec_seqfix.json
  ```
  near_attack_A=20.0 유지, provenance note만 수정.

- **Verification**:
  ```bash
  WS=/mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629
  ls -la ${WS}/stage/src_local/boltz_extension/steering/potentials.py
  python3 -c "import json; s=json.load(open('${WS}/stage/closure_spec_seqfix.json')); print('near_attack_A=',s['near_attack_A'])"
  ```
  → `potentials.py` 존재, `near_attack_A= 20.0`

- **Estimated time**: 3 min
- **Rollback**: `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/`

---

## Task 2: 9NFR 서열 추출 + MSA CSVs 작성

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/msa/{crbn,ddb1,vav1}.csv`

- **Change shape**:
  Python + gemmi로 9NFR.cif에서 체인 서열 추출 후 `key,sequence` 포맷 CSV 작성:
  ```python
  import gemmi, os
  REF = '/mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/refs/9NFR.cif'
  WS  = '/mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/msa'
  st = gemmi.read_structure(REF)
  # chain B → crbn.csv (353aa)
  # chain A → ddb1.csv (1119aa)
  # chain C → vav1.csv (55aa)
  # format: key,sequence\n0,<seq>\n
  ```
  ubuntu 소유 디렉토리라 직접 write 가능.

- **Verification**:
  ```bash
  for f in crbn ddb1 vav1; do
    wc -c /mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/msa/${f}.csv
  done
  head -1 /mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/msa/crbn.csv
  ```
  → header=`key,sequence`, crbn≥360chars, ddb1≥1120chars, vav1≥58chars

- **Estimated time**: 3 min
- **Rollback**: `rm /mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/msa/*.csv`

---

## Task 3: Contacts 재추출 + YAML 작성 (vav1_9nfr_seqfix.yaml)

- **Status**: done
- **Prereq tasks**: 1, 2
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/inputs/vav1_9nfr_seqfix.yaml`

- **Change shape**:
  Python + gemmi로 9NFR.cif contacts 재추출:
  - CRBN-DDB1: B↔A heavy-atom 최소거리 top 10 쌍 <5Å
  - CRBN-VAV1: B↔C heavy-atom 최소거리 top 8 쌍 <6Å
  - DDB1 resid-map: enumerate over chain A 잔기 (1119aa, gaps 존재)
  - CRBN YAML_pos = crystal_resid − 76
  - VAV1 YAML_pos = crystal_resid − 784

  YAML 체인:
  - A = CRBN (353aa, MSA: msa/crbn.csv)
  - B = VAV1 (55aa, MSA: msa/vav1.csv)
  - C = degrader SMILES: `Cn1ccc(COc2ccc(-c3cccc([C@H]4CCC(=O)NC4=O)c3Cl)cc2)n1`
  - D = DDB1 (1119aa, MSA: msa/ddb1.csv)

  Templates: 9UUM_prot, 9V0F_prot, 4TZ4_prot, 4CI3_prot, 5HXB_prot
  (경로: /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/refs/*.cif)

  Pocket constraints: chain B (CRBN) + chain C (VAV1) 잔기 중 A1BYX 리간드
  5Å 이내 heavy atom.

  force:true, max_distance:8.0

  sudo -u kim tee 또는 /tmp 경유 cp.

- **Verification**:
  ```bash
  python3 -c "
  import yaml
  d=yaml.safe_load(open('/mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/inputs/vav1_9nfr_seqfix.yaml'))
  contacts=[c for c in d.get('constraints',[]) if 'contact' in c]
  ab=[c for c in contacts if c['contact'].get('token2',[''])[0]=='B']
  ad=[c for c in contacts if c['contact'].get('token2',[''])[0]=='D']
  tmpl=d.get('templates',[])
  seqs=d.get('sequences',[])
  print(f'contacts={len(contacts)}, CRBN-VAV1={len(ab)}, CRBN-DDB1={len(ad)}, templates={len(tmpl)}, chains={len(seqs)}')
  "
  ```
  → `contacts=18, CRBN-VAV1=8, CRBN-DDB1=10, templates=5, chains=4`

- **Estimated time**: 8 min
- **Rollback**: `rm .../inputs/vav1_9nfr_seqfix.yaml`

---

## Task 4: 런처 작성 + 드라이런

- **Status**: done
- **Prereq tasks**: 3
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/run_seqfix.sh`

- **Change shape**:
  contact_fix_9nfr 런처(`run_ddb1_contact_early_9nfr.sh`) 기반 복사:
  - WS, YAML, SPEC 경로 교체
  - job-name: `vav1_9nfr_seqfix`
  - CELLS: arm0×3 + arm2×3 = 6 cells
  - ARM-2: `--num_particles 1` (OOM 방지, benchmark ARM-2 OOM 전례 반영)
  - GPU 선택: memory.free > 75000 MiB

- **Verification**:
  ```bash
  bash /mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/run_seqfix.sh
  ```
  → `CELLS=6 (ARM-0 × 3 + ARM-2 × 3)`, `[MISSING]` 없음

- **Estimated time**: 4 min
- **Rollback**: `rm .../run_seqfix.sh`

---

## Task 5: ⛔ GPU GATE — SLURM 제출 + 모니터링

- **Status**: pending
- **Prereq tasks**: 4
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/logs/`
  - `/mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/out/`

- **Change shape**:
  ```bash
  sudo -u kim sbatch /mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/run_seqfix.sh --submit
  ```
  제출 직후 포그라운드 감시: `Processing 1 inputs` 확인, OOM 시 즉시 보고.

- **Verification**:
  ```bash
  find /mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/out/ \
    -name "*_model_0.pdb" | wc -l
  ```
  → `≥3` (ARM-0 최소)

- **Estimated time**: GPU ~35분
- **Rollback**: `sudo -u kim scancel <JOBID>`

---

## Task 6: 채점 + 결과 문서

- **Status**: pending
- **Prereq tasks**: 5
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/analysis/scores.tsv`
  - `/home/ubuntu/analysis/crl_integrative/vav1_9nfr_seqfix_results.md`
  - `/home/ubuntu/analysis/crl_integrative/png/vav1_9nfr_seqfix_overlay.png`

- **Change shape**:
  benchmark Task 6 score_cells.py 패턴 재사용:
  - GT: 9NFR_crystal.pdb (chains A=DDB1, B=CRBN, C=VAV1)
  - DockQ `--mapping ABD:BCA`
  - native=(B,C) → dq_cv, native=(B,A) → dq_cd
  - 서열 정합이므로 DockQ 정상 정렬 기대
  결과 문서: old DQcv=0.084 vs new DQcv 비교표, 해석

- **Verification**:
  ```bash
  wc -l /mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/analysis/scores.tsv
  test -f /home/ubuntu/analysis/crl_integrative/vav1_9nfr_seqfix_results.md && echo ok
  ```
  → `≥4` (header + ≥3 ARM-0), `ok`

- **Estimated time**: 10 min
- **Rollback**: `rm .../scores.tsv /home/ubuntu/analysis/crl_integrative/vav1_9nfr_seqfix_results.md`
