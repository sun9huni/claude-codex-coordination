---
contract: .agent/contracts/fragmap-mdsilcs-rebuild-v2-20260602.md
slice: fragmap
status: in-progress
total_tasks: 7
estimated_total_min: 90
---

# Plan — fragmap MD-SILCS rebuild v2

> Contract approved 2026-06-02. 4 probe × 2 system × 3 replica = 24 SLURM jobs,
> 100 ns each. Key insight: `finalize_grandlig_atom_specific_channels.py` uses
> `ghosts.txt` / `with_ghosts.pdb` deeply → new `analyze_mdsilcs_traj.py` needed
> (ghost-free occupancy → GFE pipeline). Probe resnames from PROBES dict:
> formamide=FMD, imidazole=IMD, DME=DME, acetate=ACX.

## Task 1: prepare_mdsilcs_box.py — probe 배치 + minimize

- **Status**: done (2026-06-02; water-removal placement + convergence minimize; dry-run OK)
- **Prereq tasks**: none
- **Files touched**: `scripts/prepare_mdsilcs_box.py` (신규)
- **Change shape**:
  기존 `ternary_r{1,2}_equil.pdb`에 N개 probe 분자를 물 영역에 배치 후 에너지 최소화.
  - `grandlig_common.build_ternary_solvated_model` 결과물을 입력으로 사용
  - OpenMM Modeller로 probe PDB를 N회 add (random water-region position)
  - 클래시 해소: 에너지 최소화 500 steps + 10 ps NVT pre-equilibration
  - 출력: `{output_dir}/{system}_{probe}_N{n_probe}_box.pdb` + `system.xml`
  - CLI: `python prepare_mdsilcs_box.py --system ternary_r2 --probe formamide --n-probe 25 --out-dir /mnt/data/.../mdsilcs_ternary_v2/r2_formamide_rep1/`
- **Verification**:
  ```bash
  python scripts/prepare_mdsilcs_box.py --system ternary_r2 --probe formamide \
    --n-probe 25 --out-dir /tmp/mdsilcs_dryrun/ --dry-run
  # → exit 0, 출력 PDB 존재, probe residue 25개 포함 확인
  grep "FMD" /tmp/mdsilcs_dryrun/ternary_r2_formamide_N25_box.pdb | wc -l  # > 0
  ```
- **Estimated time**: 20 min

## Task 2: run_mdsilcs_production.py — plain NVT→NPT MD

- **Status**: done (2026-06-02; --platform flag, box vector fix, pre-NVT mini; 1ps CPU test OK)
- **Prereq tasks**: 1
- **Files touched**: `scripts/run_mdsilcs_production.py` (신규)
- **Change shape**:
  Task 1 출력 PDB+XML로부터 plain OpenMM MD 실행.
  - 단계: NVT 1 ns (protein heavy-atom restraint k=10 kcal/mol/Å²) → NPT 100 ns (restraint 제거)
  - 저장: 10 ps stride DCD + acceptance_summary 유사 `run_summary.json`
  - CUDA 플랫폼 (choose_platform 재사용 from `run_grandlig_charge_pair_gcmc.py`)
  - CLI: `python run_mdsilcs_production.py --box-pdb .../box.pdb --system-xml .../system.xml \
      --out-dir .../rep1/ --nvt-ns 1 --npt-ns 100 --stride-ps 10`
  - 출력: `traj_production.dcd`, `topology.pdb`, `run_summary.json`
- **Verification**:
  ```bash
  python scripts/run_mdsilcs_production.py --box-pdb /tmp/mdsilcs_dryrun/ternary_r2_formamide_N25_box.pdb \
    --system-xml /tmp/mdsilcs_dryrun/system.xml --out-dir /tmp/mdsilcs_dryrun/rep1/ \
    --nvt-ns 0.001 --npt-ns 0.001 --stride-ps 1  # 1 ps dry-run
  # → exit 0, traj_production.dcd 존재 (≥1 frame), run_summary.json 존재
  ```
- **Estimated time**: 25 min

## Task 3: analyze_mdsilcs_traj.py — ghost-free occupancy → GFE

- **Status**: done (2026-06-02; raw DCD binary parser; 1ps traj → NPZ with amide_donor/acceptor OK)
- **Prereq tasks**: none (독립, 병렬 작업 가능)
- **Files touched**: `scripts/analyze_mdsilcs_traj.py` (신규)
- **Change shape**:
  `finalize_grandlig_atom_specific_channels.py` fork — ghost 로직 제거, plain MD traj 처리.
  - `compute_occupancy_grid` + `occupancy_to_gfe` 재사용 (from `precompute_oracle_silcs_maps.py`)
  - probe resname + atom_name으로 좌표 선택 (ghosts.txt 불필요)
  - Kabsch align to reference protein CA (기존 `align_atom_indices` 로직 재사용)
  - 채널 매핑: `ATOM_CHANNELS` dict (formamide: N1→amide_donor / O1→amide_acceptor,
    imidazole: N1→imidazole_acceptor / N2→imidazole_donor,
    DME: O1→acceptor_ether, acetate: O1+O2→carboxylate_acceptor)
  - 출력: 시스템별 채널 NPZ (나중에 merge)
  - CLI: `python analyze_mdsilcs_traj.py --traj-dirs .../rep{1,2,3}/ \
      --probe formamide --system ternary_r2 --out-npz .../r2_formamide.npz`
- **Verification**:
  ```bash
  # 기존 GCMC traj를 ghost-free 모드로 테스트 (ghosts.txt 무시)
  python scripts/analyze_mdsilcs_traj.py \
    --traj-dirs /mnt/data/.../ternary_r2/formamide/muex_neg5p0/replica_1/ \
    --probe formamide --system ternary_r2 --no-ghost-check \
    --out-npz /tmp/test_r2_formamide.npz
  # → exit 0, grid_amide_donor / grid_amide_acceptor 채널 존재
  python3 -c "import numpy as np; d=np.load('/tmp/test_r2_formamide.npz', allow_pickle=True); print('OK', [k for k in d.files if k.startswith('grid_')])"
  ```
- **Estimated time**: 20 min

## Task 4: Dry-run end-to-end validation (zero-GPU)

- **Status**: done (2026-06-02; formamide full pipeline CPU 1ps: prepare→minimize→1ps NVT+NPT→analyze→NPZ all OK. Note: OpenCL NaN on this login node → SLURM script must use CUDA env)
- **Prereq tasks**: 1, 2, 3
- **Files touched**: 없음 (출력만)
- **Change shape**:
  Task 1→2→3 파이프라인 전체를 최소 입력으로 검증.
  - T1: r2/formamide 박스 준비 (25 probes, /tmp/)
  - T2: 1 ps MD (DCD 생성 확인)
  - T3: 1 ps traj 분석 → NPZ 생성 확인 (n_frames=1이라 GFE 의미 없음, 파이프라인만 확인)
  - acetate probe도 별도 dry-run: counter-ion 처리 정상 동작 확인
- **Verification**:
  ```bash
  # 전체 파이프라인
  python scripts/prepare_mdsilcs_box.py --system ternary_r2 --probe formamide --n-probe 25 --out-dir /tmp/dr/
  python scripts/run_mdsilcs_production.py --box-pdb /tmp/dr/*.pdb --system-xml /tmp/dr/system.xml \
    --out-dir /tmp/dr/rep1/ --nvt-ns 0.001 --npt-ns 0.001 --stride-ps 1
  python scripts/analyze_mdsilcs_traj.py --traj-dirs /tmp/dr/rep1/ \
    --probe formamide --system ternary_r2 --out-npz /tmp/dr/test.npz
  python3 -c "import numpy as np; d=np.load('/tmp/dr/test.npz',allow_pickle=True); assert 'grid_amide_donor' in d.files; print('PIPELINE OK')"
  # acetate counter-ion 확인
  python scripts/prepare_mdsilcs_box.py --system ternary_r2 --probe acetate --n-probe 25 --out-dir /tmp/dr_ace/
  grep "NA\|ACX" /tmp/dr_ace/*.pdb | wc -l  # Na⁺ counter-ion 25개 확인
  ```
- **Estimated time**: 10 min

## Task 5: SLURM array script 작성 + 제출

- **Status**: done (2026-06-02; job 6208 submitted, 8 RUNNING + 16 PENDING; output dirs confirmed; scripts in shared workspace)
- **Prereq tasks**: 4
- **Files touched**: `scripts/slurm_mdsilcs_array.sh` (신규)
- **Change shape**:
  24 jobs (4 probe × 2 system × 3 replica) SLURM array.
  - `--array=1-24%8` (8 GPU 동시 실행)
  - `--time=24:00:00` (100 ns at 120 ns/day + buffer)
  - `--gres=gpu:1`, `--qos=batch`
  - job-index → (probe, system, replica) 매핑 테이블 내장
  - 각 job: prepare_mdsilcs_box.py → run_mdsilcs_production.py 순서로 실행
  - OUT_BASE: `/mnt/data/users/kim/code/.../mdsilcs_ternary_v2/`
  - 사전 승인 확인: `.agent/contracts/fragmap-mdsilcs-rebuild-v2-20260602.md` Status=approved
- **Verification**:
  ```bash
  # dry-run 먼저
  bash scripts/slurm_mdsilcs_array.sh --dry-run  # → 24개 job 파라미터 출력, sbatch 미실행
  # 제출
  sbatch scripts/slurm_mdsilcs_array.sh
  squeue -u kim | grep mdsilcs | wc -l  # ≥ 1
  ```
- **Estimated time**: 15 min

## Task 6: v2 NPZ 빌드 (모든 24 job 완료 후)

- **Status**: pending (SLURM jobs 완료 대기)
- **Prereq tasks**: 5 (24 jobs 완료)
- **Files touched**:
  - `data/silcs_oracle_real/ternary_r{1,2}_maps_v2.npz` (신규)
  - `data/silcs_oracle_real/atom_specific_channel_manifest_v2.json` (신규)
- **Change shape**:
  각 probe-system별 intermediate NPZ를 merge해 최종 v2 NPZ 생성.
  - `analyze_mdsilcs_traj.py`를 4 probe × 2 system 조합 전체로 실행 (3 replica 합산)
  - 기존 `ternary_r2_maps.npz`에서 whole-probe 채널(aromatic, hydrophobe, positive) 복사
    (이 채널들은 GCMC whole-probe로 이미 충분히 샘플링됨)
  - 새 atom-specific 채널(amide_donor/acceptor, imidazole_donor/acceptor,
    acceptor_ether, carboxylate_acceptor) 추가
  - v1 NPZ mtime 불변 확인
- **Verification**:
  ```bash
  stat data/silcs_oracle_real/ternary_r{1,2}_maps.npz | grep Modify  # 2026-04-30 불변
  python3 -c "
  import numpy as np
  d = np.load('data/silcs_oracle_real/ternary_r2_maps_v2.npz', allow_pickle=True)
  required = ['grid_amide_donor','grid_amide_acceptor','grid_imidazole_donor',
              'grid_imidazole_acceptor','grid_acceptor_ether','grid_carboxylate_acceptor']
  for ch in required:
      assert ch in d.files, f'missing {ch}'
  print('v2 NPZ OK:', [k for k in d.files if k.startswith('grid_')])
  "
  ```
- **Estimated time**: 15 min

## Task 7: 검증 + REPORT.md 업데이트 + baton

- **Status**: pending
- **Prereq tasks**: 6
- **Files touched**:
  - `analysis/silcs_map_revival_20260601/REPORT.md` (§Rebuild-v2 섹션 추가)
  - `.agent/status/fragmap.md` (baton 업데이트)
  - `.agent/contracts/fragmap-mdsilcs-rebuild-v2-20260602.md` (Status→done)
- **Change shape**:
  Done-When 기준 전부 점검 후 결과 기록.
  - `map_completeness.py` → v2: UNION non-cap ≥ 15% (vs v1 5.9%)
  - `hotspot_geometry.py` → v2: min_dist_to_crystal_lig < 3Å (vs v1 3.91Å)
  - `crystal_ligand_ceiling.py` → v2: coverage_heavy > 0 여부 기록
  - REPORT.md §Rebuild-v2: v1/v2 수치 비교 표 + 결론
  - baton remaining_actions 맨 앞에 ✅ 추가
  - contract Status: done + Progress Log 업데이트
  - `./scripts/handoff.sh claude fragmap` + `./scripts/status.sh index`
- **Verification**:
  ```bash
  grep "Rebuild-v2" analysis/silcs_map_revival_20260601/REPORT.md  # exists
  grep "^version:" .agent/status/fragmap.md  # bumped
  ./scripts/status.sh index 2>&1 | tail -1   # no warnings
  ```
- **Estimated time**: 15 min
