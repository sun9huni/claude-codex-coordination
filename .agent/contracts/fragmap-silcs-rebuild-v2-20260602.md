# fragmap-silcs-rebuild-v2

**Status:** superseded → see fragmap-mdsilcs-rebuild-v2-20260602.md
**Slice:** fragmap (SILCS-Lite map build + scoring)
**Approval:** requested 2026-06-02 · approved by: N/A (superseded before approval)

## Purpose

현재 frozen SILCS 맵(`ternary_r{1,2}_maps.npz`)은 replica당 100 frames, binding site
samples/voxel 0.56으로 심각하게 under-sampled돼 있음. 오리지널 SILCS 퀄리티 수준의 새 맵
`ternary_r{1,2}_maps_v2.npz`을 빌드한다:
- 기존 3 probe(formamide, imidazole, dimethyl_ether) 10× 재샘플링 (100→1,000 cycles)
- acetate probe 추가 (anionic H-bond acceptor 채널, 파라미터 파일 기존재)

## Current State

- Frozen 맵: `data/silcs_oracle_real/ternary_r{1,2}_maps.npz` (2026-04-30, 변경 금지)
- 샘플링 부족: 100 cycles/rep, 5 rep, mean_N≈3–4 → 0.56 sample/voxel in binding site
- Deep hotspot(<−1.0): 채널당 ~40–88 voxels, crystal ligand와 최소 3.91Å 간격
- acetate probe 파라미터: `data/silcs_oracle_real/probes/acetate/{acetate.pdb, acetate.xml}` 존재
- GCMC 스크립트: `scripts/run_grandlig_charge_pair_gcmc.py`, `prepare_grandlig_ternary_inputs.py`
- Finalize 스크립트: `scripts/finalize_grandlig_atom_specific_channels.py`
- muex 참고값: formamide/imidazole −5.0, DME −3.5, acetate는 결정 필요(−3.0~−5.0 범위)

## Assumptions And Questions

- assumptions:
  - 기존 GCMC 스크립트가 acetate probe에 대해 probe resname/atom_names만 변경하면 동작함
  - acetate atom-specific 채널: carboxylate O1/O2 → `acetate_acceptor` (또는 `carboxylate_acceptor`)
  - 1 job = 1 GPU (OpenCL), 기존 실측 ~5.5h/100 cycles → 1,000 cycles ≈ 55h/rep
  - 8 GPU SLURM array: `--array=1-40%8` (4 probe × 2 system × 5 rep = 40 jobs)
- open questions:
  - acetate muex 최적값: 기존 retuning matrix나 reference 없으면 −4.0 (benzamidine 유사류 기준)
  - finalize_grandlig_atom_specific_channels.py가 acetate O1/O2를 새 채널명으로 처리하는지
    → Task 1에서 dry-run으로 확인
- tradeoffs:
  - 5 rep 유지(10 rep 대비): wall-clock 11.5일 vs 23일. 5 rep로 먼저 수렴 확인 후 확장 가능
  - 10× cycles: binding site samples/voxel 0.56→5.6 (목표 ≥3 달성), 오리지널 SILCS 수준

## Constraints

- allowed change scope:
  - `/mnt/data/.../ternary_expanded_*_v2/` 아래 새 GCMC 출력 디렉토리
  - `data/silcs_oracle_real/ternary_r{1,2}_maps_v2.npz` (새 파일)
  - `data/silcs_oracle_real/atom_specific_channel_manifest_v2.json`
  - SLURM array script `scripts/slurm_gcmc_rebuild_v2.sh` (신규)
  - `analysis/silcs_map_revival_20260601/REPORT.md` 업데이트 (결과 기록)
- forbidden change scope:
  - `data/silcs_oracle_real/ternary_r{1,2}_maps.npz` (frozen v1, 절대 수정 금지)
  - `src/boltz_extension/steering/fragmap_steering.py` (steering 엔진 미접촉)
  - production YAML/config 파일 (v2 맵 adoption은 별도 contract)
- external constraints:
  - 8 GPU 사용 가능, GPU-hour 제한 없음
  - wall-clock 목표: ~11.5일 (40 jobs × 55h ÷ 8 GPU)
  - SLURM qos: batch (qos=high는 MaxSubmit=15 < 40 → batch 사용)

## Non-Goals

- v2 맵을 production steering pipeline에 adoption (별도 contract)
- MD-based SILCS 방식으로 전환 (GCMC 유지)
- pyridine, methylamine, acetaldehyde probe 추가 (이번 scope 밖)
- 기존 frozen v1 맵의 채널 수정/repoint
- replica 수 10개로 증가 (v1 완료 후 수렴 확인 시 별도로)

## Done When

1. **40 GCMC jobs 완료**: `ternary_expanded_*_v2/` 아래 4 probe × 2 system × 5 rep 디렉토리
   존재, 각 `acceptance_summary.json` + `traj.dcd` 존재
   - verify: `find /mnt/data/.../ternary_expanded_*_v2 -name acceptance_summary.json | wc -l` = 40
2. **v2 NPZ 빌드**: `ternary_r{1,2}_maps_v2.npz` 생성, acetate 포함 채널 확인
   - verify: `python3 -c "import numpy as np; d=np.load('...ternary_r2_maps_v2.npz',allow_pickle=True); assert 'grid_acetate_acceptor' in d.files or 'grid_carboxylate_acceptor' in d.files; print('OK', [k for k in d.files if k.startswith('grid_')])"` exit 0
3. **Sampling depth 목표 달성**: binding site samples/voxel ≥ 3
   - verify: `python3 /tmp/map_completeness.py` (v2 NPZ 지정) → UNION non-cap ≥ 15% accessible
4. **V1 동결 보존**: v1 NPZ mtime 불변
   - verify: `stat ternary_r{1,2}_maps.npz` mtime = 2026-04-30 (변경 없음)
5. **결과 기록**: `analysis/silcs_map_revival_20260601/REPORT.md` §Rebuild-v2 섹션 추가
   (deep hotspot count before/after, crystal ligand coverage v1→v2 비교)

## Triggers Matched (WORKFLOW §2)

- SLURM 제출: **YES** → contract 필수
- `/mnt/data` shared-storage 쓰기: **YES**
- FragMap scoring 모드 변경: **YES** (acetate 신규 채널)
- 4+ 파일: YES (40 GCMC outputs + 2 NPZ + manifest + report)

## Resource Budget

- GPU: 8 × A100, OpenCL
- Wall-clock: ~11.5일 (40 jobs ÷ 8 GPU × 55h/job)
- Disk: ~40 replica × ~250MB traj.dcd ≈ 10 GB 추가

## Verification

- task-specific:
  ```bash
  # 완료 체크
  find /mnt/data/users/kim/code/.../ternary_expanded_*_v2 -name acceptance_summary.json | wc -l  # = 40
  python3 /tmp/map_completeness.py  # binding site union non-cap ≥ 15%
  python3 /tmp/hotspot_geometry.py  # deep hotspot min_dist_to_crystal_lig < 3Å (최소 1채널)
  python3 /home/ubuntu/FKSFold-Boltz_Advancement/analysis/silcs_map_revival_20260601/crystal_ligand_ceiling.py \
      --maps .../ternary_r2_maps_v2.npz  # coverage_heavy > 0 여부 기록
  ```
- V1 frozen guard:
  ```bash
  stat .../ternary_r1_maps.npz .../ternary_r2_maps.npz | grep Modify  # 2026-04-30 불변
  ```

## Risks

- regression risk: NONE — v2 NPZ는 신규 파일, v1 모든 consumer 미접촉
- acetate muex 미조율: acceptance rate가 너무 낮거나 높으면 채널이 sparse/dense 편향
  → Task 1에서 acceptance_summary dry-run으로 사전 확인 (target: 2-8%)
- SLURM 55h/job이 timeout 걸릴 가능성: qos=batch time limit 확인 필요
  → Task 2에서 time limit 확인, 필요시 `--time=60:00:00` 설정

## Rollback

- revert strategy: `rm -rf /mnt/data/.../ternary_expanded_*_v2/ .../ternary_r{1,2}_maps_v2.npz`
  → V1 frozen 자산 완전 미접촉, downstream 영향 0
- containment strategy: V2 adoption은 별도 contract이므로 이 contract 범위 내 rollback은
  파일 삭제만으로 완결

## Progress Log

- 2026-06-02: /brainstorm 완료 — gap 분석(0.56 sample/voxel, probe 4종 확정, acetate params 기존재),
  타임라인 계산(40 jobs, 8 GPU, ~11.5일). Status: pending.
