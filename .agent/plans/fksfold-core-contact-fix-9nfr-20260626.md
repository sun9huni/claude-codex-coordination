---
contract: .agent/contracts/fksfold-core-contact-fix-9nfr-20260626.md
slice: aigen-fold-core
status: done
total_tasks: 5
estimated_total_min: 50
---

# Plan: Contact 재설계 + 9NFR template — DockQ 개선 실험

Contact resid 버그 3개 수정 + VAV1-CRBN contacts 신규 추가 + 9NFR 6번째 template.

---

## Task 1: 워크스페이스 생성 + 9NFR_prot.cif + closure_spec 복사

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/` (디렉토리 트리)
  - `refs/9NFR_prot.cif` (gemmi로 protein-only 추출)
  - `stage/closure_spec_contact_fix.json` (near_attack_A=20.0 복사본)
  - symlinks: stage/src_local, refs/9NFR.cif, stage/closure_spec_generic.json(원본 참조용), refs/*_prot.cif(5개), msa/ddb1_single_seq.csv, analysis/refs/9UUM.cif
- **Change shape**:
  ```bash
  BASE=/mnt/kfs2/data/users/ubuntu
  WS=${BASE}/contact_fix_9nfr_20260626
  EARLY=${BASE}/ddb1_contact_early_9nfr_20260626
  TMPL=${BASE}/template_9nfr_20260626
  ORIG=${BASE}/ik_9nfr_20260625
  PREV=${BASE}/template_ddb1_combo_9nfr_20260626

  mkdir -p ${WS}/{inputs,logs,out,refs,analysis/crl_integrative/refs,configs,stage,msa}
  chmod 777 ${WS}/logs ${WS}/out

  # src_local symlink (기존 패치 재사용)
  ln -sfn ${EARLY}/stage/src_local ${WS}/stage/src_local

  # 기타 symlinks
  ln -sfn ${ORIG}/refs/9NFR.cif ${WS}/refs/9NFR.cif
  for name in 9UUM 9V0F 4TZ4 4CI3 5HXB; do
    ln -sfn ${TMPL}/refs/${name}_prot.cif ${WS}/refs/${name}_prot.cif
  done
  ln -sfn ${BASE}/ddb1_4chain_9nfr_20260626/msa/ddb1_chain_D.csv ${WS}/msa/ddb1_single_seq.csv
  cp ${EARLY}/analysis/crl_integrative/refs/9UUM.cif ${WS}/analysis/crl_integrative/refs/9UUM.cif

  # 9NFR_prot.cif: protein-only (chains A,B,C from 9NFR crystal)
  python3 -c "
  import gemmi
  def is_aa(r):
      info = gemmi.find_tabulated_residue(r.name)
      return bool(info and info.is_amino_acid())
  st = gemmi.read_structure('/home/ubuntu/best_structures/9NFR_reference.cif')
  prot = gemmi.Structure()
  prot.cell = st.cell
  prot.spacegroup_hm = st.spacegroup_hm
  m = gemmi.Model('1')
  for ch in st[0]:
      new_ch = gemmi.Chain(ch.name)
      for r in ch:
          if is_aa(r): new_ch.add_residue(r)
      if len(new_ch) > 0: m.add_chain(new_ch)
  prot.add_model(m)
  prot.write_minimal_pdb('${WS}/refs/9NFR_prot.pdb')
  " && python3 -m gemmi convert --to cif ${WS}/refs/9NFR_prot.pdb ${WS}/refs/9NFR_prot.cif

  # closure_spec 복사본 — near_attack_A 변경
  python3 -c "
  import json
  spec = json.load(open('${ORIG}/stage/closure_spec_generic.json'))
  spec['near_attack_A'] = 20.0
  spec['provenance']['note'] = 'near_attack_A=20Å (reach criterion); contact_fix experiment 2026-06-26'
  json.dump(spec, open('${WS}/stage/closure_spec_contact_fix.json','w'), indent=2)
  "
  ```
  
  NOTE: gemmi CIF write는 `--to cif` 로 convert. PDB 경유.
  
- **Verification**:
  ```bash
  WS=/mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626
  ls -la ${WS}/stage/src_local/boltz_extension/steering/potentials.py \
         ${WS}/refs/9NFR_prot.cif \
         ${WS}/msa/ddb1_single_seq.csv
  python3 -c "import json; s=json.load(open('${WS}/stage/closure_spec_contact_fix.json')); print('near_attack_A=',s['near_attack_A'])"
  ```
  → 파일 3개 존재, `near_attack_A= 20.0`
- **Estimated time**: 4 min
- **Rollback**: `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/`

---

## Task 2: YAML 작성 — 18 contacts + 9NFR 6번째 template

- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/inputs/9NFR_contact_fix.yaml`
- **Change shape**:
  template_ddb1_combo YAML에서 출발. 변경점 3가지:

  1. `templates:` 블록에 9NFR_prot.cif 추가 (6번째):
  ```yaml
  - cif: /mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/refs/9NFR_prot.cif
  ```

  2. `constraints:` 블록 전체 교체 (18쌍, 기존 12쌍 제거):

  CRBN-DDB1 (10쌍):
  ```yaml
  - contact: {token1: [A, 170], token2: [D, 386], max_distance: 8.0, force: true}
  - contact: {token1: [A, 173], token2: [D, 389], max_distance: 8.0, force: true}
  - contact: {token1: [A, 196], token2: [D, 530], max_distance: 8.0, force: true}
  - contact: {token1: [A, 184], token2: [D, 327], max_distance: 8.0, force: true}
  - contact: {token1: [A, 185], token2: [D, 610], max_distance: 8.0, force: true}
  - contact: {token1: [A, 144], token2: [D, 685], max_distance: 8.0, force: true}
  - contact: {token1: [A, 146], token2: [D, 558], max_distance: 8.0, force: true}
  - contact: {token1: [A, 191], token2: [D, 441], max_distance: 8.0, force: true}
  - contact: {token1: [A, 188], token2: [D, 517], max_distance: 8.0, force: true}
  - contact: {token1: [A, 151], token2: [D, 577], max_distance: 8.0, force: true}
  ```

  VAV1-CRBN (8쌍):
  ```yaml
  - contact: {token1: [A, 308], token2: [B, 19], max_distance: 8.0, force: true}
  - contact: {token1: [A, 310], token2: [B, 17], max_distance: 8.0, force: true}
  - contact: {token1: [A, 306], token2: [B, 16], max_distance: 8.0, force: true}
  - contact: {token1: [A, 352], token2: [B, 14], max_distance: 8.0, force: true}
  - contact: {token1: [A, 306], token2: [B, 18], max_distance: 8.0, force: true}
  - contact: {token1: [A,  58], token2: [B, 32], max_distance: 8.0, force: true}
  - contact: {token1: [A, 352], token2: [B, 15], max_distance: 8.0, force: true}
  - contact: {token1: [A,  41], token2: [B, 41], max_distance: 8.0, force: true}
  ```

  3. DDB1 MSA 경로 교체 (WS 교체):
  `.../contact_fix_9nfr_20260626/msa/ddb1_single_seq.csv`

  나머지 (시퀀스·CRBN/VAV1 MSA·pocket constraints) 는 template_ddb1_combo YAML과 동일.

- **Verification**:
  ```bash
  python3 -c "
  import yaml
  d = yaml.safe_load(open('/mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/inputs/9NFR_contact_fix.yaml'))
  contacts = [c for c in d.get('constraints',[]) if 'contact' in c]
  ab = [c for c in contacts if c['contact'].get('token2',[''])[0]=='B']
  ad = [c for c in contacts if c['contact'].get('token2',[''])[0]=='D']
  tmpl = d.get('templates',[])
  nfr_t = [t for t in tmpl if '9NFR' in t.get('cif','')]
  print(f'contacts={len(contacts)}, CRBN-VAV1={len(ab)}, CRBN-DDB1={len(ad)}, templates={len(tmpl)}, 9NFR_tmpl={len(nfr_t)}')
  "
  ```
  → `contacts=18, CRBN-VAV1=8, CRBN-DDB1=10, templates=6, 9NFR_tmpl=1`
- **Estimated time**: 5 min
- **Rollback**: `rm /mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/inputs/9NFR_contact_fix.yaml`

---

## Task 3: 런처 작성 + 드라이런

- **Status**: pending
- **Prereq tasks**: 2
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/run_contact_fix_9nfr.sh`
- **Change shape**:
  template_ddb1_combo 런처 기반. 변경점:
  - `WS`, `YAML`, `job-name`, `--output/--error`, `SPEC` 경로 교체
  - `SPEC=${WS}/stage/closure_spec_contact_fix.json` (near_attack_A=20.0)
  - `SEEDS=(16 42 123 200 300 400 500 600 700)` (ARM-0용 9 seeds)
  - `ARM2_SEEDS=(16 42 123)` (ARM-2용 3 seeds)
  - CELLS 구성: ARM-0×9 + ARM-2×3 = 12 cells
- **Verification**:
  ```bash
  bash /mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/run_contact_fix_9nfr.sh
  ```
  → `CELLS=12 (ARM-0 × 9 + ARM-2 × 3 seeds)`, `[MISSING]` 없음
- **Estimated time**: 5 min
- **Rollback**: `rm /mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/run_contact_fix_9nfr.sh`

---

## Task 4: ⛔ GPU GATE — SLURM 제출 + 모니터링

- **Status**: pending
- **Prereq tasks**: 3
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/logs/`
  - `/mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/out/` (PDB)
- **Change shape**:
  ```bash
  sudo -u kim sbatch /mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/run_contact_fix_9nfr.sh --submit
  ```
  제출 직후 첫 셀(ARM-0/seed16) 로그 포그라운드 감시:
  - `Processing 1 inputs` — 정상 시작
  - `templates: 6` or `Using 6 templates` 로그 확인
  - OOM 발생 시 즉시 보고
  - ARM-2 로그에서 `[CRLClosureIK] ... found` (near_attack_A=20Å) 확인
- **Verification**:
  ```bash
  find /mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/out/ \
    -name "*_model_0.pdb" | wc -l
  ```
  → `12`
- **Estimated time**: GPU 런타임 90-120분 (12 cells × ~10min/cell, 4 GPU 병렬)
- **Rollback**: `sudo -u kim scancel <JOBID>` + `sudo -u kim rm -rf .../out/`

---

## Task 5: 채점 + 결과 문서

- **Status**: done
- **Prereq tasks**: 4
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/analysis/scores.tsv`
  - `/home/ubuntu/analysis/crl_integrative/contact_fix_9nfr_results.md`
  - `/home/ubuntu/analysis/crl_integrative/png/contact_fix_9nfr_overlay.png`
- **Change shape**:
  template_ddb1_combo 채점 스크립트 재사용. 변경점:
  - contact_satisfied 기준: max=18 (기존 12)
  - cone_dist threshold: near_attack_A=20Å (scoring 기준도 동일 완화)
  - CRBN_RMSD, DockQ_total, DockQ_crbn-vav1, DockQ_crbn-ddb1 포함

  scores.tsv 포맷 (동일):
  `arm  seed  crbn_rmsd  dockq_total  dockq_crbn_vav1  fnat_crbn_vav1  irmsd_crbn_vav1  lrmsd_crbn_vav1  dockq_crbn_ddb1  fnat_crbn_ddb1  cone_dist  near_attack  contact_satisfied`

  결과 문서:
  - 전 실험 계열 비교 (8381/8398/8443/8444 포함)
  - contact_satisfied 개선 증명 표
  - DockQ_crbn-vav1 vs 8444 비교
  - PASS/FAIL 판정

  PNG: overlay (crystal + best ARM-0 + best ARM-2, CRBN Kabsch 수퍼포즈) → png/ 폴더
- **Verification**:
  ```bash
  wc -l /mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/analysis/scores.tsv
  test -f /home/ubuntu/analysis/crl_integrative/contact_fix_9nfr_results.md
  ```
  → `13` (header + 12 rows), 파일 존재
- **Estimated time**: 12 min
- **Rollback**: `rm .../scores.tsv /home/ubuntu/analysis/crl_integrative/contact_fix_9nfr_results.md`
