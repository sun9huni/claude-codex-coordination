---
contract: .agent/contracts/fksfold-core-template-ddb1-combo-9nfr-20260626.md
slice: aigen-fold-core
status: done
total_tasks: 5
estimated_total_min: 45
---

# Plan: Template + DDB1 single-seq + force:true contacts 조합 실험

템플릿 conditioning(8381) + DDB1 single-seq(8398) + force:true contacts(8443) 조합.
CRBN RMSD < 15Å 달성 시 IK(ARM-2)로 near_attack 시도.
src_local (potentials.py 패치) 재사용 — 수정 없음.

---

## Task 1: 워크스페이스 생성 + symlinks

- **Status**: done
- **Prereq tasks**: none
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/` (디렉토리 트리)
  - symlinks: refs/9NFR.cif, stage/src_local, stage/closure_spec_generic.json,
    refs/*_prot.cif (5개), msa/ddb1_single_seq.csv, configs/oracle_generation_9nfr.yaml
- **Change shape**:
  ```bash
  BASE=/mnt/kfs2/data/users/ubuntu
  WS=${BASE}/template_ddb1_combo_9nfr_20260626
  EARLY=${BASE}/ddb1_contact_early_9nfr_20260626
  TMPL=${BASE}/template_9nfr_20260626
  ORIG=${BASE}/ik_9nfr_20260625

  mkdir -p ${WS}/{inputs,logs,out,refs,analysis/crl_integrative/refs,configs,stage,msa}
  chmod 777 ${WS}/logs ${WS}/out

  # src_local symlink (이미 패치됨, 재사용)
  ln -sfn ${EARLY}/stage/src_local ${WS}/stage/src_local

  # 기타 symlinks
  ln -sfn ${ORIG}/refs/9NFR.cif ${WS}/refs/9NFR.cif
  ln -sfn ${ORIG}/stage/closure_spec_generic.json ${WS}/stage/closure_spec_generic.json
  cp ${ORIG}/configs/oracle_generation_9nfr.yaml ${WS}/configs/

  # 템플릿 CIF symlinks (5개)
  for name in 9UUM 9V0F 4TZ4 4CI3 5HXB; do
    ln -sfn ${TMPL}/refs/${name}_prot.cif ${WS}/refs/${name}_prot.cif
  done

  # DDB1 single-seq MSA symlink (2줄 CSV, 8398에서 cone_dist=14.2Å)
  ln -sfn ${BASE}/ddb1_4chain_9nfr_20260626/msa/ddb1_chain_D.csv \
      ${WS}/msa/ddb1_single_seq.csv

  # 9UUM 참조 (cone_dist 계산용)
  cp ${EARLY}/analysis/crl_integrative/refs/9UUM.cif \
      ${WS}/analysis/crl_integrative/refs/9UUM.cif
  ```
- **Verification**:
  ```bash
  WS=/mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626
  ls -la ${WS}/stage/src_local/boltz_extension/steering/potentials.py \
         ${WS}/refs/9NFR.cif \
         ${WS}/msa/ddb1_single_seq.csv \
         ${WS}/refs/9UUM_prot.cif
  wc -l ${WS}/msa/ddb1_single_seq.csv
  ```
  → 4개 파일 존재, CSV wc=2 (header+1행)
- **Estimated time**: 3 min
- **Rollback**: `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/`

---

## Task 2: YAML 작성 — template + 4체인 + 12 contacts 통합

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/inputs/9NFR_template_ddb1_combo.yaml`
- **Change shape**:
  contact_early YAML에서 출발해 두 가지 추가:
  1. `templates:` 블록 (5 CIF) — template_9nfr YAML에서 복사
  2. DDB1 MSA 경로를 single-seq CSV로 교체

  핵심 diff (contact_early YAML 대비):
  ```yaml
  # 추가: templates 블록 (version: 1 바로 뒤)
  templates:
  - cif: /mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/refs/9UUM_prot.cif
  - cif: /mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/refs/9V0F_prot.cif
  - cif: /mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/refs/4TZ4_prot.cif
  - cif: /mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/refs/4CI3_prot.cif
  - cif: /mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/refs/5HXB_prot.cif

  # 변경: chain D MSA (full MSA → single-seq)
  - protein:
      id: D
      sequence: IHEHASID...
      msa: /mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/msa/ddb1_single_seq.csv
  ```
  나머지 (CRBN/VAV1 시퀀스·MSA·pocket constraints·12 force:true contacts) 는 contact_early YAML과 동일.
- **Verification**:
  ```bash
  python3 -c "
  import yaml
  d = yaml.safe_load(open('/mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/inputs/9NFR_template_ddb1_combo.yaml'))
  contacts = [c for c in d.get('constraints',[]) if 'contact' in c]
  forced = [c for c in contacts if c['contact'].get('force')]
  tmpl = d.get('templates',[])
  chains = [s.get('protein',{}).get('id') or s.get('ligand',{}).get('id') for s in d.get('sequences',[])]
  ddb1_msa = [s['protein']['msa'] for s in d['sequences'] if s.get('protein',{}).get('id')=='D'][0]
  print(f'chains={chains}, templates={len(tmpl)}, contacts={len(contacts)}, forced={len(forced)}')
  print(f'DDB1 msa={ddb1_msa}')
  "
  ```
  → `chains=['A','B','C','D'], templates=5, contacts=12, forced=12`
  → `DDB1 msa=.../ddb1_single_seq.csv`
- **Estimated time**: 4 min
- **Rollback**: `rm /mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/inputs/9NFR_template_ddb1_combo.yaml`

---

## Task 3: 런처 작성 + 드라이런

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/run_template_ddb1_combo_9nfr.sh`
- **Change shape**:
  contact_early 런처 기반, 변경점:
  - `WS`, `YAML`, `job-name`, `--output/--error` 경로 교체
  - `SEEDS=(16 42 123 200 300 400)` (ARM-0용 6 seeds)
  - `ARM2_SEEDS=(16 42 123)` (ARM-2용 3 seeds)
  - ARM별 seed 분기: ARM-0은 SEEDS 전체, ARM-2는 ARM2_SEEDS만
  - CELLS 구성: ARM-0 × 6 + ARM-2 × 3 = 9 cells
  - `SRC_LOCAL="${BASE}/ddb1_contact_early_9nfr_20260626/stage/src_local"` (기존 패치 재사용)
  - `export PYTHONPATH="${SRC_LOCAL}"` (동일)
- **Verification**:
  ```bash
  bash /mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/run_template_ddb1_combo_9nfr.sh
  ```
  → `CELLS=9 (ARM-0 × 6 + ARM-2 × 3 seeds)`, `[MISSING]` 없음
- **Estimated time**: 5 min
- **Rollback**: `rm /mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/run_template_ddb1_combo_9nfr.sh`

---

## Task 4: ⛔ GPU GATE — SLURM 제출 + 모니터링

- **Status**: done  <!-- job 8444 완료, 9 cells PDB 생성 확인 -->
- **Prereq tasks**: 3
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/logs/`
  - `/mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/out/` (PDB)
- **Change shape**:
  ```bash
  sudo -u kim sbatch /mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/run_template_ddb1_combo_9nfr.sh --submit
  ```
  제출 직후 첫 셀(ARM-0/seed16) 로그 포그라운드 감시:
  - `Processing 1 inputs` — 정상 시작 확인
  - OOM 발생 시 즉시 보고 (ARM-2 num_particles=2, 9 cells × ~1227 토큰)
  - ARM-2 로그에서 `[CRLClosureIK] generic mode: N LYS NZ found` (N ≥ 4) 확인
- **Verification**:
  ```bash
  find /mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/out/ \
    -name "*_model_0.pdb" | wc -l
  ```
  → `9`
- **Estimated time**: GPU 런타임 60–90분 (9 cells × ~10min/cell, 4 GPU 병렬)
- **Rollback**: `sudo -u kim scancel <JOBID>` + `sudo -u kim rm -rf .../out/`

---

## Task 5: 채점 + 결과 문서

- **Status**: done
- **Prereq tasks**: 4
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/analysis/scores.tsv`
  - `/home/ubuntu/analysis/crl_integrative/template_ddb1_combo_9nfr_results.md`
  - `/home/ubuntu/analysis/crl_integrative/png/template_ddb1_combo_overlay.png`
- **Change shape**:
  contact_early 채점 스크립트 재사용 (inline Kabsch + SequenceMatcher 방식):
  - CRBN_RMSD, DockQ, Fnat, lRMSD, iRMSD (vs 9NFR crystal)
  - cone_dist, near_attack (9UUM Kabsch, sequence-alignment)
  - contact_satisfied (12쌍, max_distance=9.0Å)

  scores.tsv 포맷:
  `arm  seed  crbn_rmsd  dockq  fnat  lrmsd  irmsd  cone_dist  near_attack  contact_satisfied`

  결과 문서:
  - 9 cell 채점 표
  - ARM-0 6 seeds CRBN_RMSD 분포 (목표: ≥2개 < 15Å)
  - ARM-2 3 seeds near_attack 여부
  - 전체 계열 비교 표 (8381/8398/8443 포함)
  - PASS/FAIL 판정

  PNG: overlay (crystal + best ARM-0 + best ARM-2, CRBN Kabsch 수퍼포즈)
- **Verification**:
  ```bash
  wc -l /mnt/kfs2/data/users/ubuntu/template_ddb1_combo_9nfr_20260626/analysis/scores.tsv
  test -f /home/ubuntu/analysis/crl_integrative/template_ddb1_combo_9nfr_results.md
  ```
  → `10` (header + 9 rows), 파일 존재
- **Estimated time**: 10 min
- **Rollback**: `rm .../scores.tsv /home/ubuntu/analysis/crl_integrative/template_ddb1_combo_9nfr_results.md`
