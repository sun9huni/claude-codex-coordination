# fragmap-mdsilcs-rebuild-v2

**Status:** approved
**Slice:** fragmap (SILCS-Lite map build + scoring)
**Approval:** requested 2026-06-02 · approved by: user 2026-06-02

## Purpose

현재 GCMC 기반 SILCS 맵은 random-insertion NCMC acceptance rate 3%로 인한 구조적
under-sampling 문제가 있어 binding site deep hotspot과 crystal ligand 원자 간 최소 거리가
3.91Å(target <3Å)에 달함. MacKerell 오리지널 방법론인 **MD-SILCS** (explicit probe MD)로
전환해 근본적으로 해결한다.

MD-SILCS: probe 분자를 물 안에 직접 배치 → 자유 diffusion → 알아서 favorable site 탐색.
acceptance rate 개념 없음. 4 probe type × 2 system × 3 replica = 24 jobs, 100 ns each.

## Current State

- Frozen GCMC 맵: `data/silcs_oracle_real/ternary_r{1,2}_maps.npz` (2026-04-30, 변경 금지)
- sampling/voxel in binding site: 0.56 (목표 ≥3)
- crystal ligand → nearest deep hotspot: **최소 3.91Å** (목표 <3Å)
- 재사용 가능 인프라:
  - `scripts/grandlig_common.py:build_ternary_solvated_model` (단백질+물 박스)
  - probe ff params: `data/silcs_oracle_real/probes/{formamide,imidazole,dimethyl_ether,acetate}/`
  - `scripts/convert_grandlig_traj_to_npz.py` (traj→occupancy→GFE, plain MD traj 재사용 가능)
  - `scripts/finalize_grandlig_atom_specific_channels.py` (atom-specific GFE 빌드)
  - 기존 equilibrated PDB: `data/silcs_oracle_real/ternary_r{1,2}/ternary_r{1,2}_equil.pdb`
- 새로 필요한 스크립트:
  - `scripts/prepare_mdsilcs_box.py` — 기존 solvated PDB에 N개 probe 분자 배치
  - `scripts/run_mdsilcs_production.py` — plain NVT→NPT MD (no GCMC)
  - `scripts/slurm_mdsilcs_array.sh` — 24-job SLURM array

## Assumptions And Questions

- assumptions:
  - A100 기준 111k atoms + ~200 probe atoms: ~120 ns/day → 100ns/job ≈ 20h
  - probe 분자 수: 25개/type (0.03 M 농도, 기존 SILCS Lite 수준; 더 늘리면 box 재빌드 필요)
  - acetate는 음이온이라 Na⁺ counter-ion 추가 필요 (OpenMM Modeller 자동 처리)
  - `convert_grandlig_traj_to_npz.py`의 ghost 필터링 로직을 제거/bypass하면 plain MD traj 처리 가능
  - atom-specific 채널: formamide(N1→amide_donor, O1→amide_acceptor),
    imidazole(N1→imidazole_acceptor, N2→imidazole_donor),
    DME(O1→acceptor_ether), acetate(O1/O2→carboxylate_acceptor)
- open questions:
  - probe 분자 배치 시 clashing 처리: OpenMM energy minimize가 충분한가,
    아니면 packmol 별도 도구 필요한가? → Task 1 dry-run에서 확인
  - `convert_grandlig_traj_to_npz.py`의 ghost resid 의존성 제거 범위:
    단순 플래그 추가로 가능한지, 아니면 fork 필요한지 → Task 1에서 확인
- tradeoffs:
  - 25 probe/type (0.03 M): 충분히 sparse해 비현실적 probe-probe 상호작용 없음.
    MacKerell 원본은 0.25 M 사용하나 더 큰 box 필요 — 이 scope에서는 0.03 M으로 시작
  - replica 3개: GCMC의 5개보다 적지만 MD가 더 잘 수렴. 수렴 못하면 +2 replica 추가 (별도 submit)

## Constraints

- allowed change scope:
  - `scripts/prepare_mdsilcs_box.py` (신규)
  - `scripts/run_mdsilcs_production.py` (신규)
  - `scripts/slurm_mdsilcs_array.sh` (신규)
  - `scripts/convert_grandlig_traj_to_npz.py` — `--no-ghost-filter` 플래그 추가만 허용
  - `/mnt/data/.../mdsilcs_ternary_v2/` 아래 신규 MD 출력 디렉토리
  - `data/silcs_oracle_real/ternary_r{1,2}_maps_v2.npz` (신규)
  - `data/silcs_oracle_real/atom_specific_channel_manifest_v2.json` (신규)
  - `analysis/silcs_map_revival_20260601/REPORT.md` — §Rebuild-v2 결과 섹션 추가
- forbidden change scope:
  - `data/silcs_oracle_real/ternary_r{1,2}_maps.npz` (frozen v1, 절대 수정 금지)
  - `src/boltz_extension/steering/fragmap_steering.py` (미접촉)
  - production YAML/config (v2 adoption은 별도 contract)
  - `grandlig_common.py` 이외의 기존 스크립트 본체 수정
- external constraints:
  - 8 GPU(A100), GPU-hour 무제한
  - wall-clock 목표: 5일 (setup 2일 + 시뮬 2.5일 + 분석 0.5일)
  - SLURM qos: batch, `--time=24:00:00` (20h + buffer)

## Non-Goals

- v2 맵을 production steering pipeline에 adoption (별도 contract)
- GCMC 스크립트 개선/수정
- replica 10개로 확장 (v2 수렴 확인 후 필요시 별도)
- probe 농도 0.25 M (MacKerell 원본) — box 재빌드 필요, 이번 scope 밖
- pyridine, methylamine 신규 probe (scope 외)

## Done When

1. **24 MD jobs 완료 (100 ns each)**
   - verify: `ls /mnt/data/.../mdsilcs_ternary_v2/*/traj_production.dcd | wc -l` = 24
2. **v2 NPZ 생성 + acetate 채널 포함**
   - verify: `python3 -c "import numpy as np; d=np.load('.../ternary_r2_maps_v2.npz',allow_pickle=True); assert any('carboxylate' in k or 'acetate' in k for k in d.files); print('OK')"` exit 0
3. **Sampling depth 목표 달성**: binding site samples/voxel ≥ 3
   - verify: `python3 /tmp/map_completeness.py` (v2 NPZ 대상) → UNION non-cap ≥ 15% accessible
4. **Crystal ligand 근접도 개선**: 최소 1개 채널에서 deep hotspot < 3Å
   - verify: `python3 /tmp/hotspot_geometry.py` (v2 NPZ 대상) → min_dist_to_lig < 3Å
5. **V1 frozen 보존**
   - verify: `stat .../ternary_r{1,2}_maps.npz | grep Modify` = 2026-04-30 불변

## Implementation Steps

1. **Setup (zero-GPU)** — `prepare_mdsilcs_box.py` + `run_mdsilcs_production.py` 작성
   - 기존 `ternary_r{1,2}_equil.pdb`에 25개 probe 분자 추가 (Modeller.add × N)
   - 에너지 최소화 + 1 ns NVT equilibration + 100 ns NPT production
   - verify: 1 ps dry-run (probe FF loads, no clashes) → exit 0

2. **Traj 분석 파이프라인 검증 (zero-GPU)**
   - `convert_grandlig_traj_to_npz.py --no-ghost-filter` 가능한지 확인
   - 필요시 플래그 추가 (10줄 이내)
   - verify: 기존 r2/formamide replica_1 traj에 --no-ghost-filter 적용 → npz 생성 확인

3. **SLURM array 제출** (24 jobs, `--array=1-24%8`)
   - verify: `squeue -u kim | grep mdsilcs | wc -l` = running jobs

4. **시뮬레이션 모니터링** — 첫 job 완료 후 probe sampling 확인
   - verify: replica_1 traj에서 probe 분자들이 binding site 근처 접근 여부 시각화

5. **NPZ 빌드** — 모든 24 jobs 완료 후
   - `finalize_grandlig_atom_specific_channels.py` v2 경로로 실행
   - verify: Done-When 1-4 점검 스크립트 전부 통과

6. **REPORT.md 업데이트 + baton**
   - `analysis/silcs_map_revival_20260601/REPORT.md` §Rebuild-v2 섹션 추가
   - crystal ligand coverage v1→v2 비교, sampling/voxel v1→v2
   - verify: REPORT.md §Rebuild-v2 exists, fragmap baton updated

## Triggers Matched (WORKFLOW §2)

- SLURM 제출: **YES** → contract 필수
- `/mnt/data` shared-storage 쓰기: **YES**
- FragMap scoring 채널 변경: **YES** (acetate 신규 + 전체 재빌드)
- 4+ 파일: YES (3 신규 스크립트 + 24 MD outputs + 2 NPZ + manifest + report)

## Resource Budget

- GPU: 8 × A100, CUDA
- Wall-clock: ~5일 (setup 2일 + 시뮬 2.5일 + 분석 0.5일)
- 총 GPU-hours: ~480 (24 jobs × 20h)
- Disk: 24 × ~10GB traj (100ns, 10ps stride) ≈ 240 GB 추가

## Verification

```bash
# 완료 체크
ls /mnt/data/.../mdsilcs_ternary_v2/*/traj_production.dcd | wc -l          # = 24
python3 /tmp/map_completeness.py --maps .../ternary_r2_maps_v2.npz          # UNION ≥ 15%
python3 /tmp/hotspot_geometry.py --maps .../ternary_r2_maps_v2.npz          # min_dist < 3Å
python3 analysis/silcs_map_revival_20260601/crystal_ligand_ceiling.py \
    --maps .../ternary_r2_maps_v2.npz                                        # coverage > 0 여부 기록
stat .../ternary_r{1,2}_maps.npz | grep Modify                               # v1 불변
```

## Risks

- **probe diffusion 느림**: 25개 probe가 100ns 안에 binding site를 충분히 탐색 못할 수 있음
  → 4 replica(3+1)로 대응; probe concentration 높이면 더 빠른 탐색 (별도 scope)
- **acetate 전하 균형**: 25 acetate × 2 systems = 50 Na⁺ 추가 → 이온 강도 약간 변화
  → 허용 가능 (0.15 M NaCl 배경 대비 미미한 변화)
- **클래시 제거 실패**: probe 배치 후 에너지 최소화로 해결 안 되면 배치 위치 변경
  → Task 1 dry-run에서 사전 확인
- **traj 분석 ghost 의존성**: convert 스크립트가 ghost resid에 강하게 의존하면
  분석 fork 필요 (추가 ~1일) → Task 2에서 10줄 이내로 해결 안 되면 사용자 알림

## Rollback

- revert strategy: `sudo -u kim rm -rf /mnt/data/.../mdsilcs_ternary_v2/`
  + `rm data/silcs_oracle_real/ternary_r{1,2}_maps_v2.npz`
  → V1 frozen 자산 완전 미접촉, downstream 영향 0
- 새 스크립트 3개: `git revert` 또는 삭제
- containment: V2 adoption은 별도 contract이므로 이 범위 내 rollback은 파일 삭제로 완결

## Progress Log

- 2026-06-02: /brainstorm 완료
  - GCMC acceptance 3% 원인 분석: NCMC 9.9ps → wrong-position insertion 대다수 (W>10 kcal/mol)
  - NCMC 100ps로 늘려도 수락률 상한 ~12%, 효율 GCMC 대비 0.83× → 근본 해결 못함
  - MD-SILCS 채택: acceptance bottleneck 없음, wall-clock 2.5일(vs GCMC 11.5일), GPU-hr 480(vs 2,200)
  - 기존 인프라 재사용 확인: solvated model builder, probe ff params, GFE analysis 모두 존재
  - Status: pending
