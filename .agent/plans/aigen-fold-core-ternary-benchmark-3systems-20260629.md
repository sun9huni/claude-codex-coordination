---
contract: .agent/contracts/aigen-fold-core-ternary-benchmark-3systems-20260629.md
slice: aigen-fold-core
status: done
total_tasks: 6
estimated_total_min: 55
---

# Plan: Ternary Benchmark — BRD4 / IKZF1 (CRBN pipeline)

contact_fix_9nfr과 동일 파이프라인 아키텍처를 BRD4(6BN7) + IKZF1(6H0F)에 적용.
ARM-0 × 3 + ARM-2 × 3 = 6 cells per system, 12 cells total.

핵심 사전 계산 결과 (플랜에 인라인):

BRD4(6BN7): CRBN Y_pos = resid−43, DDB1 resid-map 필요(gaps), BRD4 Y_pos = resid−41.
K99(Y58) Nζ=12.3Å, K91(Y50) Nζ=12.5Å → ARM-2 generic mode 자동 탐색.
cone_apex = [143.54, 80.855, 132.198] (9UUM frame, 재사용).

IKZF1(6H0F): CRBN Y_pos = resid−68, DDB1 resid-map 필요(gaps), IKZF1 Y_pos = resid−137.
K157(Y20) Nζ≈40Å, K165(Y28) Nζ≈34Å → 9UUM Kabsch 품질 미검증(RMSD 10.7Å);
IKZF1 ZnF는 degron fragment이므로 ARM-2 cone steering 결과가 near_attack=False일 수 있음.
ARM-2도 포함하되 near_attack 통계는 결과 해석에서 주석.

---

## Task 1: 워크스페이스 디렉토리 + symlinks + MSA CSVs + closure_spec 복사

- **Status**: done
- **Prereq tasks**: none
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/benchmark_ternary/inputs/`
  - `/mnt/kfs2/data/users/ubuntu/benchmark_ternary/logs/`
  - `/mnt/kfs2/data/users/ubuntu/benchmark_ternary/out/`
  - `/mnt/kfs2/data/users/ubuntu/benchmark_ternary/msa/`
  - `/mnt/kfs2/data/users/ubuntu/benchmark_ternary/stage/`
  - `/mnt/kfs2/data/users/ubuntu/benchmark_ternary/stage/src_local` (symlink)
  - `/mnt/kfs2/data/users/ubuntu/benchmark_ternary/stage/closure_spec_benchmark.json`
  - `/mnt/kfs2/data/users/ubuntu/benchmark_ternary/msa/{crbn_brd4,ddb1_brd4,brd4,crbn_ikzf1,ddb1_ikzf1,ikzf1}.csv`

- **Change shape**:
  ```bash
  WS=/mnt/kfs2/data/users/ubuntu/benchmark_ternary
  EARLY=/mnt/kfs2/data/users/ubuntu/ddb1_contact_early_9nfr_20260626
  PREV=/mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626

  sudo -u kim mkdir -p ${WS}/{inputs,logs,out,msa,stage}
  sudo -u kim chmod 777 ${WS}/logs ${WS}/out

  # src_local: 기존 패치 재사용
  sudo -u kim ln -sfn ${EARLY}/stage/src_local ${WS}/stage/src_local

  # closure_spec 복사 (cone_apex 동일, near_attack_A=20.0)
  sudo -u kim cp ${PREV}/stage/closure_spec_contact_fix.json \
      ${WS}/stage/closure_spec_benchmark.json
  python3 -c "
  import json
  s=json.load(open('${WS}/stage/closure_spec_benchmark.json'))
  s['provenance']['note']='benchmark BRD4+IKZF1 2026-06-29'
  json.dump(s,open('${WS}/stage/closure_spec_benchmark.json','w'),indent=2)
  "

  # MSA single-seq CSVs — 각 체인 시퀀스 추출 후 작성
  python3 << 'INNER'
  import gemmi, csv, os
  REF='/mnt/kfs2/data/users/ubuntu/benchmark_ternary/refs'
  WS='/mnt/kfs2/data/users/ubuntu/benchmark_ternary/msa'

  def get_seq(ch):
      return ''.join(gemmi.find_tabulated_residue(r.name).one_letter_code
                     for r in ch if gemmi.find_tabulated_residue(r.name).is_amino_acid())

  def write_csv(path, seq):
      with open(path,'w') as f:
          f.write('sequence\n'+seq+'\n')
  os.makedirs(WS,exist_ok=True)

  st6 = gemmi.read_structure(f'{REF}/6BN7.cif')
  write_csv(f'{WS}/crbn_brd4.csv', get_seq(st6[0]['B']))   # CRBN
  write_csv(f'{WS}/ddb1_brd4.csv', get_seq(st6[0]['A']))   # DDB1
  write_csv(f'{WS}/brd4.csv',      get_seq(st6[0]['C']))   # BRD4_BD2

  st6h = gemmi.read_structure(f'{REF}/6H0F.cif')
  write_csv(f'{WS}/crbn_ikzf1.csv', get_seq(st6h[0]['B'])) # CRBN
  write_csv(f'{WS}/ddb1_ikzf1.csv', get_seq(st6h[0]['A'])) # DDB1
  write_csv(f'{WS}/ikzf1.csv',      get_seq(st6h[0]['C'])) # IKZF1 ZnF
  print('MSA CSVs written')
  INNER
  ```

- **Verification**:
  ```bash
  WS=/mnt/kfs2/data/users/ubuntu/benchmark_ternary
  ls -la ${WS}/stage/src_local/boltz_extension/steering/potentials.py \
         ${WS}/stage/closure_spec_benchmark.json
  ls ${WS}/msa/*.csv | wc -l
  python3 -c "import json; s=json.load(open('${WS}/stage/closure_spec_benchmark.json')); print('near_attack_A=',s['near_attack_A'])"
  ```
  → `potentials.py` 존재, `6개 CSV`, `near_attack_A= 20.0`

- **Estimated time**: 4 min
- **Rollback**: `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/benchmark_ternary/{inputs,logs,out,msa,stage}/`

---

## Task 2: BRD4 YAML 작성 (brd4_benchmark.yaml)

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/benchmark_ternary/inputs/brd4_benchmark.yaml`

- **Change shape**:
  Python으로 6BN7 chain sequences 추출 + resid→YAML_pos 매핑으로 contacts 계산 후 YAML 작성.
  체인: A=CRBN(375aa, 6BN7-B resid 44-427), B=BRD4_BD2(127aa, 6BN7-C resid 42-168),
  C=dBET23 SMILES, D=DDB1(803aa, 6BN7-A resid 1-1140 gaps포함).

  CRBN YAML_pos = crystal_resid − 43
  BRD4 YAML_pos = crystal_resid − 41
  DDB1: resid-map(gap 고려, 직접 계산)

  contacts (force:true, max_distance:8.0):
  CRBN-DDB1 10쌍 (6BN7 crystal <4Å, YAML A↔D):
    A:185↔D:677, A:196↔D:597, A:157↔D:320, A:186↔D:400, A:164↔D:188
    A:148↔D:625, A:165↔D:183, A:158↔D:305, A:153↔D:644, A:161↔D:259
  CRBN-BRD4 8쌍 (6BN7 crystal <4Å, YAML A↔B):
    A:300↔B:37, A:60↔B:104, A:108↔B:111, A:60↔B:102
    A:300↔B:38, A:107↔B:37, A:107↔B:36, A:60↔B:107

  templates: 9UUM_prot, 9V0F_prot, 4TZ4_prot, 4CI3_prot, 5HXB_prot
  (symlink 경로: /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/refs/*.cif)

  MSA 경로: /mnt/kfs2/data/users/ubuntu/benchmark_ternary/msa/{crbn_brd4,brd4,ddb1_brd4}.csv
  DDB1 MSA: single-seq (ddb1_brd4.csv)

  pocket constraints: C(dBET23) binder — CRBN 및 BRD4 side pocket 잔기 (<5Å heavy atom)

  ```python
  # contacts를 YAML 형식으로 출력하는 스크립트를 작성하고 YAML 생성
  import gemmi, yaml

  REF = '/mnt/kfs2/data/users/ubuntu/benchmark_ternary/refs'
  WS  = '/mnt/kfs2/data/users/ubuntu/benchmark_ternary'
  TMPL = '/mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/refs'

  st = gemmi.read_structure(f'{REF}/6BN7.cif')
  # 시퀀스 추출 (chain B=CRBN, C=BRD4, A=DDB1)
  # resid map 빌드, contacts 하드코딩(pre-computed), YAML 직렬화
  ```

- **Verification**:
  ```bash
  python3 -c "
  import yaml
  d=yaml.safe_load(open('/mnt/kfs2/data/users/ubuntu/benchmark_ternary/inputs/brd4_benchmark.yaml'))
  contacts=[c for c in d.get('constraints',[]) if 'contact' in c]
  ab=[c for c in contacts if c['contact'].get('token2',[''])[0]=='B']
  ad=[c for c in contacts if c['contact'].get('token2',[''])[0]=='D']
  tmpl=d.get('templates',[])
  print(f'contacts={len(contacts)}, CRBN-BRD4={len(ab)}, CRBN-DDB1={len(ad)}, templates={len(tmpl)}')
  "
  ```
  → `contacts=18, CRBN-BRD4=8, CRBN-DDB1=10, templates=5`

- **Estimated time**: 6 min
- **Rollback**: `rm /mnt/kfs2/data/users/ubuntu/benchmark_ternary/inputs/brd4_benchmark.yaml`

---

## Task 3: IKZF1 YAML 작성 (ikzf1_benchmark.yaml)

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/benchmark_ternary/inputs/ikzf1_benchmark.yaml`

- **Change shape**:
  6H0F chain B=CRBN(374aa, resid 69-), C=IKZF1_ZnF(32aa, resid 138-169), A=DDB1(826aa).
  CRBN YAML_pos = crystal_resid − 68
  IKZF1 YAML_pos = crystal_resid − 137
  DDB1: resid-map 직접 계산

  contacts (force:true, max_distance:8.0):
  CRBN-DDB1 10쌍 (6H0F crystal <4Å, YAML A↔D):
    A:306↔D:526, A:304↔D:526, A:65↔D:244, A:71↔D:120, A:55↔D:571
    A:101↔D:623, A:72↔D:115, A:306↔D:543, A:103↔D:188, A:100↔D:183
    (실제 YAML pos는 Task 실행 시 resid-map으로 정확히 계산)
  CRBN-IKZF1 8쌍 (6H0F crystal <4.5Å, YAML A↔B):
    A:237↔B:4, A:215↔B:11, A:264↔B:13, A:221↔B:12
    A:215↔B:12, A:252↔B:13, A:217↔B:11, A:219↔B:11
    (실제 YAML pos는 Task 실행 시 crystal resid 기준으로 재계산)

  NOTE: IKZF1 ZnF(32aa) K157(Y20)=39.6Å, K165(Y28)=33.8Å — cone apex 거리 큼.
  ARM-2 near_attack=False 예상; 이는 정상(ZnF=degron fragment, 실제 ubiq site 아님).
  ARM-2 포함하되 결과 해석에서 주석 처리.

  템플릿, degrader SMILES(lenalidomide=`O=C1NC(=O)CCC1N3C(=O)c2cccc(c2C3=O)N`),
  MSA 경로: msa/{crbn_ikzf1,ikzf1,ddb1_ikzf1}.csv

- **Verification**:
  ```bash
  python3 -c "
  import yaml
  d=yaml.safe_load(open('/mnt/kfs2/data/users/ubuntu/benchmark_ternary/inputs/ikzf1_benchmark.yaml'))
  contacts=[c for c in d.get('constraints',[]) if 'contact' in c]
  ab=[c for c in contacts if c['contact'].get('token2',[''])[0]=='B']
  ad=[c for c in contacts if c['contact'].get('token2',[''])[0]=='D']
  tmpl=d.get('templates',[])
  print(f'contacts={len(contacts)}, CRBN-IKZF1={len(ab)}, CRBN-DDB1={len(ad)}, templates={len(tmpl)}')
  "
  ```
  → `contacts=18, CRBN-IKZF1=8, CRBN-DDB1=10, templates=5`

- **Estimated time**: 5 min
- **Rollback**: `rm /mnt/kfs2/data/users/ubuntu/benchmark_ternary/inputs/ikzf1_benchmark.yaml`

---

## Task 4: 런처 작성 + 드라이런

- **Status**: done
- **Prereq tasks**: 2, 3
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/benchmark_ternary/run_benchmark.sh`

- **Change shape**:
  contact_fix_9nfr 런처 기반. 변경점:
  - WS, YAML 2개(brd4/ikzf1), job-name, --output/--error, SPEC 경로 교체
  - `SPEC=${WS}/stage/closure_spec_benchmark.json`
  - `SEEDS=(16 42 123)` (ARM-0용)
  - `ARM2_SEEDS=(16 42 123)` (ARM-2용)
  - CELLS: brd4-arm0×3 + brd4-arm2×3 + ikzf1-arm0×3 + ikzf1-arm2×3 = 12 cells
  - YAML 선택: brd4_benchmark.yaml for brd4 cells, ikzf1_benchmark.yaml for ikzf1 cells
  - GPU 선택: nvidia-smi memory.free>75000 MiB

  ```bash
  # dry-run (submit 없이 cell 목록 확인)
  bash /mnt/kfs2/data/users/ubuntu/benchmark_ternary/run_benchmark.sh
  ```

- **Verification**:
  ```bash
  bash /mnt/kfs2/data/users/ubuntu/benchmark_ternary/run_benchmark.sh
  ```
  → `CELLS=12 (brd4-ARM0×3 + brd4-ARM2×3 + ikzf1-ARM0×3 + ikzf1-ARM2×3)`, `[MISSING]` 없음

- **Estimated time**: 5 min
- **Rollback**: `rm /mnt/kfs2/data/users/ubuntu/benchmark_ternary/run_benchmark.sh`

---

## Task 5: ⛔ GPU GATE — SLURM 제출 + 모니터링

- **Status**: done
- **Note**: ARM-0 6/6 완료 (brd4×3, ikzf1×3). ARM-2 전부 OOM (oracle config VAV1-전용 + BRD4 1305잔기×2particles 메모리 초과). 계약서 ARM-2:사용안함 기준 충족.
- **Prereq tasks**: 4
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/benchmark_ternary/logs/`
  - `/mnt/kfs2/data/users/ubuntu/benchmark_ternary/out/`

- **Change shape**:
  ```bash
  sudo -u kim sbatch /mnt/kfs2/data/users/ubuntu/benchmark_ternary/run_benchmark.sh --submit
  ```
  제출 직후 포그라운드 감시 (첫 셀 로그):
  - `Processing 1 inputs` — 정상 시작
  - `templates: 5` 확인
  - OOM 발생 시 즉시 보고
  - ARM-2 BRD4 로그에서 `[CRLClosureIK] ... K58` or `K50` near_attack 확인

- **Verification**:
  ```bash
  find /mnt/kfs2/data/users/ubuntu/benchmark_ternary/out/ \
    -name "*_model_0.pdb" | wc -l
  ```
  → `12`

- **Estimated time**: GPU 런타임 ~120분 (12 cells × ~10min, 4 GPU 병렬 → wall ~35min)
- **Rollback**: `sudo -u kim scancel <JOBID>`

---

## Task 6: 채점 + 결과 문서

- **Status**: done
- **Prereq tasks**: 5
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/benchmark_ternary/analysis/scores.tsv`
  - `/home/ubuntu/analysis/crl_integrative/ternary_benchmark_results.md`
  - `/home/ubuntu/analysis/crl_integrative/png/ternary_benchmark_overlay.png`

- **Change shape**:
  score_cells.py 작성 (contact_fix_9nfr/analysis/score_cells.py 기반):
  - GT PDB: 6BN7(BRD4), 6H0F(IKZF1)
  - DockQ --mapping: pred(A=CRBN,B=neo,D=DDB1) → GT chains 매핑
    - BRD4: pred ABD → GT BAC (A→B=CRBN, B→C=BRD4, D→A=DDB1)
    - IKZF1: pred ABD → GT BAC (A→B=CRBN, B→C=IKZF1, D→A=DDB1)
  - 지표: DQcv(CRBN-neo), DQcd(CRBN-DDB1), DQ_total, neo_RMSD, cone_dist, near_attack, contact_sat

  결과 문서:
  - BRD4/IKZF1 DQcv 비교 표 (vs CRBN-VAV1 baseline DQcv=0.084)
  - PASS/FAIL 판정: DQcv ≥ 0.10 = 파이프라인 기본 작동 확인
  - 해석: 파이프라인 한계 vs VAV1 특이 문제

  PNG: Cα overlay (GT + best ARM-0 + best ARM-2, CRBN Kabsch)

- **Verification**:
  ```bash
  wc -l /mnt/kfs2/data/users/ubuntu/benchmark_ternary/analysis/scores.tsv
  test -f /home/ubuntu/analysis/crl_integrative/ternary_benchmark_results.md
  ```
  → `13` (header+12), 파일 존재

- **Estimated time**: 12 min
- **Rollback**: `rm .../scores.tsv /home/ubuntu/analysis/crl_integrative/ternary_benchmark_results.md`
