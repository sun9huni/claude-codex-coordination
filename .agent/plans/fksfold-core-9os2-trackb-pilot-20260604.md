---
contract: .agent/contracts/fksfold-core-9os2-trackb-pilot-20260604.md
slice: fksfold-core
status: done
total_tasks: 6
estimated_total_min: 22
---

# Plan: 9OS2 Track B pilot (steering parameter sensitivity)

작업 기반: `slurm_ood_rescue_20260602.sh` + `ood_rescue_jobs.tsv` 패턴 재사용.
출력 scratch: `/mnt/data/users/ubuntu/workspace/9os2_trackb_20260604/`

---

## Task 1: jobs TSV 생성 (24행)

- **Status**: done
- **Prereq tasks**: none
- **Files touched**:
  `FKSFold-Boltz_Advancement/analysis/heldout_placement_20260601/ood_rescue_20260602/9os2_trackb_jobs.tsv`
- **Change shape**:
  신규 TSV. 컬럼: `target  condition  seed  param_set` (탭 구분).
  enhanced arm (16행): target=9OS2, condition=nativeAB,
    seeds=16 42 123 7 99 256 314 512 1 2 3 4 5 6 8 9, param_set=enhanced
  replication arm (8행): 동일 target/condition,
    seeds=16 42 123 7 99 256 314 512, param_set=replication
  총 24행 (헤더 포함 25줄).
- **Verification**:
  `wc -l FKSFold-Boltz_Advancement/analysis/heldout_placement_20260601/ood_rescue_20260602/9os2_trackb_jobs.tsv`
  → `25` (헤더 1 + 데이터 24)
- **Estimated time**: 2 min
- **Rollback**: 파일 삭제

---

## Task 2: SLURM array 스크립트 작성

- **Status**: done
- **Prereq tasks**: none
- **Files touched**:
  `FKSFold-Boltz_Advancement/workflow/slurm_9os2_trackb_20260604.sh`
- **Change shape**:
  `slurm_ood_rescue_20260602.sh` 기반 신규 스크립트. 변경점:
  - `#SBATCH --array=1-24%8` (24 jobs)
  - `#SBATCH --time=00:30:00` (9OS2 단일 타깃, 빠름)
  - `JOBS_TSV` → `9os2_trackb_jobs.tsv` 경로
  - TSV 4번째 컬럼 `param_set` 읽어 분기:
    - `enhanced`: `--num_particles 8 --interface_lambda 20`
    - `replication`: `--num_particles 4 --interface_lambda 0.5` (OOD rescue와 동일)
  - 두 arm 모두 `--interface_resampling_interval 3 --sampling_steps 50`
  - 9OS2 w400_residue_index=345 하드코딩 (단일 타깃)
  - OUT_BASE = `/mnt/data/users/ubuntu/workspace/9os2_trackb_20260604/outputs`
  - GPU UUID fix 그대로 유지 (per-task nvidia-smi UUID)
  - idempotent SKIP (confidence json 존재 시)
- **Verification**:
  `bash -n FKSFold-Boltz_Advancement/workflow/slurm_9os2_trackb_20260604.sh`
  → 오류 없음 (bash syntax check)
- **Estimated time**: 5 min
- **Rollback**: 파일 삭제

---

## Task 3: stage + smoke test

- **Status**: done
- **Prereq tasks**: 1, 2
- **Files touched**:
  `FKSFold-Boltz_Advancement/workflow/stage_9os2_trackb.sh`
  (staging script — shared FS로 미러)
- **Change shape**:
  신규 stage 스크립트. OOD rescue의 `stage_heldout_stageB.sh` 패턴.
  다음 파일을 `/mnt/data/users/ubuntu/workspace/9os2_trackb_20260604/stage/` 로 복사:
  - `examples/heldout/9OS2.yaml`
  - `analysis/heldout_placement_20260601/configs/oracle_generation_heldout_9OS2.yaml`
  - `analysis/heldout_placement_20260601/ood_rescue_20260602/9os2_trackb_jobs.tsv`
  - src/ superset (main.py, diffusionv2*.py, steering/)
  스크립트 실행 후 smoke 체크 5가지 출력:
  1. 9OS2.yaml 존재
  2. oracle_generation_heldout_9OS2.yaml 존재
  3. TSV 24행
  4. docker image `fksfold-boltz:glueplex-v2` 로드 가능
  5. OUT_BASE 디렉토리 생성 가능
- **Verification**:
  `bash FKSFold-Boltz_Advancement/workflow/stage_9os2_trackb.sh 2>&1 | grep -c "OK"`
  → `5`
- **Estimated time**: 3 min
- **Rollback**: staged 파일 삭제 (`rm -rf /mnt/data/.../9os2_trackb_20260604/stage/`)

---

## Task 4: SLURM 제출 ⚠️ APPROVAL GATE

- **Status**: done  (job 6403, 2026-06-05; 6338=MSA rate-limit fail, 6390=NVML/UUID fail on host-10-0-5-36; fix: SLURM_JOB_GPUS priority over UUID; task 1 DONE iptm=0.75)
- **Prereq tasks**: 3
- **Files touched**: 없음 (제출만)
- **Change shape**:
  `sbatch FKSFold-Boltz_Advancement/workflow/slurm_9os2_trackb_20260604.sh`
  job array 1-24%8. 예상 완료 ~30-60분.
  제출 후 job ID 기록.
- **Verification**:
  `squeue -u ubuntu --name=9os2_trackb | grep -c RUNNING` → `>0` (제출 직후)
- **Estimated time**: 1 min (제출만; job 실행은 async)
- **Rollback**: `scancel <jobid>`

---

## Task 5: DockQ 채점

- **Status**: done  (enhanced 9/16 acc, median DockQ=0.707; replication 2/8 repro OOD)
- **Prereq tasks**: 4 (job 완료 후)
- **Files touched**:
  `FKSFold-Boltz_Advancement/analysis/heldout_placement_20260601/ood_rescue_20260602/run_trackb_scoring.py`
- **Change shape**:
  `run_ood_scoring.py` 기반 신규 스크립트. 변경:
  - `OUT_BASE` = `/mnt/data/users/ubuntu/workspace/9os2_trackb_20260604/outputs`
  - TSV에서 param_set 컬럼 추가 읽기
  - 출력: `9os2_trackb_dockq.tsv` (컬럼: target, condition, seed, param_set, DockQ, status)
  - arm별 집계 (enhanced vs replication) 출력
- **Verification**:
  `wc -l FKSFold-Boltz_Advancement/analysis/heldout_placement_20260601/ood_rescue_20260602/9os2_trackb_dockq.tsv`
  → `25` (헤더+24행, status=ok인 행 수 = completed runs)
- **Estimated time**: 3 min
- **Rollback**: TSV 삭제

---

## Task 6: TRACKB_RESULTS.md 작성

- **Status**: done  (verdict: GO — commit 88c60d5)
- **Prereq tasks**: 5
- **Files touched**:
  `FKSFold-Boltz_Advancement/analysis/heldout_placement_20260601/ood_rescue_20260602/TRACKB_RESULTS.md`
- **Change shape**:
  보고서. 섹션:
  - §1 데이터: arm별 median DockQ + acceptable-rate 표
  - §2 판정: GO / KILL / INCONCLUSIVE (사전동결 기준 적용)
    GO: enhanced ≥5/16 AND > replication AND wrongAB=0/8(기존)
    KILL: enhanced ≤2/16
  - §3 해석 + 다음 액션 권고
  판정 키워드 `GO`, `KILL`, `INCONCLUSIVE` 중 하나 반드시 포함.
- **Verification**:
  `grep -cE '^## §2|GO|KILL|INCONCLUSIVE' FKSFold-Boltz_Advancement/analysis/heldout_placement_20260601/ood_rescue_20260602/TRACKB_RESULTS.md`
  → `≥2`
- **Estimated time**: 3 min
- **Rollback**: 파일 삭제
