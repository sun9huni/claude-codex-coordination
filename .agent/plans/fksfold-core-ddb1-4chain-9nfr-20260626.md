---
contract: .agent/contracts/fksfold-core-ddb1-4chain-9nfr-20260626.md
slice: aigen-fold-core
status: done
total_tasks: 7
estimated_total_min: 28
---

# Plan: DDB1-CRBN Template Steering — 9NFR Validation

Boltz 트렁크 컨디셔닝으로 CRBN 방향 수정 테스트.
5개 DDB1-CRBN 템플릿(9UUM+9V0F+4TZ4+4CI3+5HXB) → ARM-0/ARM-2 × 3 seeds = 6 cells.
GATE: ARM-0 CRBN_RMSD < 10Å (현재 기준선: 18-23Å).

---

## Task 1: Create workspace and stage dependencies

- **Status**: done
- **Prereq tasks**: none
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/` (new dir tree)
- **Change shape**:
  Workspace 생성 + 의존성 준비. `sudo -u kim`:
  1. mkdir -p inputs/ logs/ out/ refs/ analysis/
  2. chmod 777 all
  3. Symlink stage/: `ln -s /mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/stage/src stage/src`
  4. Symlink stage closure spec: `ln -s /mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/stage/closure_spec_generic.json stage/closure_spec_generic.json`
  5. Copy oracle cfg: `cp /mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/configs/oracle_generation_9nfr.yaml configs/`
  6. Copy 5 DDB1-CRBN CIFs from /home/ubuntu/analysis/crl_integrative/refs/ → refs/ (compute nodes don't mount /home/ubuntu)
  7. Symlink 9NFR crystal GT: `ln -s /mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/refs/9NFR.cif refs/9NFR.cif`
- **Verification**: `ls /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/refs/*.cif | wc -l` → `6` (5 DDB1-CRBN + 9NFR GT)
- **Estimated time**: 3 min
- **Rollback**: `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/`

---

## Task 2: Write 9NFR_template.yaml with templates block

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/inputs/9NFR_template.yaml`
- **Change shape**:
  기존 9NFR.yaml 기반으로 `templates:` 블록 추가. 시퀀스/constraints/MSA 경로는 그대로 유지.
  MSA paths: `/mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/msa/{crbn_chain_A,vav1_chain_B}.csv` (절대경로, 기존 WS 재사용).
  Templates block (5개 CIF, 모두 /mnt/kfs2 하위):
  ```yaml
  templates:
  - cif: /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/refs/9UUM.cif
  - cif: /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/refs/9V0F.cif
  - cif: /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/refs/4TZ4.cif
  - cif: /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/refs/4CI3.cif
  - cif: /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/refs/5HXB.cif
  ```
  Boltz featurizer가 서열 유사도로 CRBN 체인을 자동 매핑. DDB1 체인은 입력과 매칭 없음(무시됨).
- **Verification**: `python3 -c "import yaml; d=yaml.safe_load(open('/mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/inputs/9NFR_template.yaml')); print(len(d['sequences']), len(d.get('templates',[])))"` → `3 5`
- **Estimated time**: 3 min
- **Rollback**: `sudo -u kim rm /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/inputs/9NFR_template.yaml`

---

## Task 3: Write run_template_9nfr.sh launcher

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/run_template_9nfr.sh`
- **Change shape**:
  run_ik_9nfr.sh 패턴 기반. 변경 사항:
  - WS = `/mnt/kfs2/data/users/ubuntu/template_9nfr_20260626`
  - YAML = `${WS}/inputs/9NFR_template.yaml` (templates 블록 포함)
  - ARMS = (arm0 arm2) — ARM-1(guidance-only) 제외, 6 cells 총 (ARM-0/ARM-2 × 3 seeds)
  - ARM-0: `boltz.main predict ${base_args[@]}` — 순수 vanilla + templates (trunk conditioning만)
  - ARM-2: `boltz.main predict ${base_args[@]} --use_potentials ... --crl_closure_enabled --crl_closure_config ${CLOSURE_SPEC} ...`
  - `--template_steering_config` 인수 없음 (GD no-op 확인됨)
  - dry_run() 셀 목록: "6 cells (ARM-0 + ARM-2 × 3 seeds)"
  - SBATCH 헤더: --job-name=tmpl_9nfr, --output/--error 경로 WS 기준
  - chmod: `sudo -u kim chmod 777 ${WS}/run_template_9nfr.sh`
- **Verification**: `bash /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/run_template_9nfr.sh` → 드라이런 출력에 `CELLS=6 (ARM-0 + ARM-2 × 3 seeds)` 포함
- **Estimated time**: 5 min
- **Rollback**: `sudo -u kim rm /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/run_template_9nfr.sh`

---

## Task 4: Dry-run verify (all inputs present, 6 cells listed)

- **Status**: done
- **Prereq tasks**: 3
- **Files touched**: none (read-only)
- **Change shape**:
  드라이런 실행 + 모든 파일 존재 확인:
  ```bash
  bash /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/run_template_9nfr.sh
  ```
  확인 항목: YAML [ok], oracle_cfg [ok], closure_spec [ok], 9NFR.cif [ok], 5개 template CIF [ok], CELLS=6.
- **Verification**: 드라이런 출력에 `[ok]`만 있고 `[MISSING]` 없음; `CELLS=6` 라인 존재
- **Estimated time**: 2 min
- **Rollback**: n/a (read-only)

---

## Task 5: ⛔ GPU GATE — SLURM submission

- **Status**: done  <!-- jobs 8371(CCD fail)/8380(9UUM path fail)/8381(OK) -->
- **Prereq tasks**: 4
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/logs/` (SLURM log 생성)
  - `/mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/out/` (PDB 생성)
- **Change shape**:
  SLURM 제출:
  ```bash
  sudo -u kim sbatch /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/run_template_9nfr.sh --submit
  ```
  제출 후 즉시 첫 셀 로그 모니터링:
  ```bash
  sudo -u kim tail -f /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/logs/tmpl_9nfr_<JOBID>.out
  ```
  확인: Boltz `Preprocessing templates` 로그 등장 + `.npz` 파일 생성 → 트렁크 컨디셔닝 활성화 증거.
  오류 발견 시 즉시 보고 (사용자 요청 전 선제 보고).
- **Verification**: `find /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/out/ -name "*_model_0.pdb" | wc -l` → `6` (전 6 cells 완료)
- **Estimated time**: GPU 런타임 (30-60분) — 완료 알림 대기
- **Rollback**: `sudo -u kim scancel <JOBID>` + `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/out/`

---

## Task 6: Score all 6 cells (CRBN_RMSD + DockQ + contact_recovery)

- **Status**: done
- **Prereq tasks**: 5
- **Files touched**:
  - `/mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/analysis/scores.tsv` (새 파일)
- **Change shape**:
  6개 PDB에 대해 scoring 실행:
  1. `score_9nfr_dockq.py` → CRBN_RMSD, DockQ (9NFR GT 대비)
  2. `score_ik_poscontrol.py` → cone_dist, near_attack
  3. `contact_recovery.py` → CR_n/3
  결과를 `analysis/scores.tsv`에 arm|seed|crbn_rmsd|dockq|cone_dist|near_attack|cr_frac 형식으로 저장.
  PDB 경로: `/mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/out/{arm0,arm2}/seed{16,42,123}/boltz_results_9NFR_template/predictions/9NFR_template_model_0.pdb`
  (정확한 경로는 T5 완료 후 `find` 로 확인)
- **Verification**: `wc -l /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/analysis/scores.tsv` → `7` (header + 6 rows)
- **Estimated time**: 5 min
- **Rollback**: `rm /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/analysis/scores.tsv`

---

## Task 7: Write template_9nfr_results.md + gate verdict

- **Status**: done
- **Prereq tasks**: 6
- **Files touched**:
  - `/home/ubuntu/analysis/crl_integrative/template_9nfr_results.md` (새 파일)
- **Change shape**:
  결과 문서 작성:
  - 표: ARM-0/ARM-2 × seeds → CRBN_RMSD / DockQ / CR_frac / cone_dist / near_attack
  - 기존 baseline 비교: T14 ARM-0 CRBN_RMSD 18-23Å (no template) → 현재 값
  - GATE 판정: ARM-0 CRBN_RMSD < 10Å (3 seeds 중 최솟값) → PASS/FAIL
  - PASS 시: → MRT6160 template steering 컨트랙트 권고
  - FAIL 시: 개선 정도 정량화 → 추가 조정 또는 DDB1 4체인 접근 에스컬레이션 권고
- **Verification**: `test -f /home/ubuntu/analysis/crl_integrative/template_9nfr_results.md && grep -c "GATE" /home/ubuntu/analysis/crl_integrative/template_9nfr_results.md` → `1` 이상
- **Estimated time**: 5 min
- **Rollback**: `rm /home/ubuntu/analysis/crl_integrative/template_9nfr_results.md`
