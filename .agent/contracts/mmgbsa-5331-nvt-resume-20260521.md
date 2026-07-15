---
slice: mmgbsa
topic: 5331-nvt-resume
status: draft
owner: claude
created: 2026-05-21
---

# mmgbsa-5331-nvt-resume

## Purpose

5331 (norm143 corrected-YAML Stage 1 prepare) 결과 분석에서 128건 prep 실패 중
49건이 **02_nvt가 정상 진행 중 walltime hit**으로 판명됨 (HARD_TIMEOUT @ step >100k,
energy/temp/constraint 모두 healthy). cpt 파일이 보존된 43건을 `gmx mdrun -cpi`로
이어 적분해 1 ns NVT를 완주시키고, 이후 03_npt → 04_npt → equi_prod → mmpbsa prep
stage까지 체이닝해 prep ready 풀에 편입. 목적은 **5331의 35.4% prep pass rate를
"진짜 prior 한계"에 가까운 수치로 정제** (현재 49건 중 43건은 protocol-walltime
mismatch artifact). 향후 같은 일이 재발하지 않도록 worker `MDP_EQUI` 또는 timeout
정책의 후속 변경 근거 데이터도 수집.

## Current State

- 5331 결과: ready 70 / failed 128, pass rate 35.4%.
- 실패 모드 정밀 분석 (2026-05-21):
  - `early_nvt_hang` 96건 — 그 중
    - HARD_TIMEOUT @ step >100k = **49건 ("healthy-but-incomplete")** ← 본 contract 대상
    - NO_PROGRESS_TIMEOUT @ step 1k-100k = ~28건 (true hang, 별도 처리)
    - 기타 = ~19건
  - 비-NVT 실패: initial_overlap_inf_force 14, acpype_timeout 7, 00_min_timeout 7, etc.
- 본 contract 대상 49건 중 **cpt-present = 43건** (resume 가능),
  **cpt-missing = 6건** (rescue 경로가 cpt 덮어쓴 듯, out of scope).
- 02_nvt mdp: `nsteps=1000000 dt=0.001` = 1 ns target. ready 컴파운드(VAV1_122)는 37 ns/day로 38분 완주, 느린 컴파운드는 60분 hard cap (`GMX_MDRUN_ABSOLUTE_MAX_02_NVT_SEC=3600`)에 671 ps 즈음 cut.
- Resume budget 분포 (43건 중):
  - 7건: 800 ps 잔여 (~30분/GPU)
  - 9건: 500-800 ps 잔여 (~20분)
  - 24건: 200-500 ps 잔여 (~10분)
  - 9건: <200 ps 잔여 (~5분)
- Worker 위치: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh` (638 lines).
- 원본 5331 SLURM: `slurm_mmgbsa_norm143_corrected_stage1.sh` (mid-split, RunA+RunB).
- Artifacts 준비됨: `.agent/scratch/5331_resume/{resume_list_full43.tsv,resume_list_smoke5.tsv,cpt_missing_6.tsv}`.

## Assumptions And Questions

- assumptions:
  - `gmx mdrun -deffnm 02_nvt -cpi 02_nvt.cpt -append`로 정확히 이어 적분되며 결과 traj/edr/log는 1 ns 완주한 ready run과 100% equivalent (gromacs 표준 동작).
  - cpt 시점의 random seed/state가 유지되므로 stochastic divergence 없음.
  - 03_npt 이후 stage들은 worker의 기존 dispatch (`gmx mdrun -cpi`가 이미 있으면 resume, 없으면 from scratch)로 자연스럽게 진행됨.
  - 1 ns NVT가 *의미상 동일하게* completed 되므로 production traj 분포에 영향 없음.
- open questions:
  - 본 contract는 **resume만 수행**하고 mdp를 변경하지 않음. NVT 1 ns → 500 ps 표준화는 별도 contract 필요 (ready vs short-NVT paired 검증 게이트).
  - cpt-missing 6건은 일단 out of scope. 추후 03_npt부터 from-scratch retry 옵션 가능.
- tradeoffs:
  - cpt resume = 정합성 ↑, 비용 ↓. 단 작업 1회성, pipeline 표준화는 별도.
  - 대신 mdp 단축 표준화는 향후 batch 전체에 효과 있으나 production 분포 검증 비용 발생.

## Constraints

- allowed change scope:
  - 새 SLURM submit script `scripts/mmgbsa_16gpu_multidir/slurm_mmgbsa_5331_nvt_resume.sh`
  - 새 resume worker `scripts/mmgbsa_16gpu_multidir/nvt_resume_worker.sh` (단일 컴파운드, run_dir 인자)
  - 5331 OUT_BASE 하위 `nvt_resume_ready.tsv`, `nvt_resume_failed.tsv` 새 ledger
  - `.agent/scratch/5331_resume/` 아래 진행 상황 로그
- forbidden change scope:
  - 02_nvt.mdp 수정 (resume 의미가 변형됨)
  - 기존 `failed_stage.tsv` / `ready_for_mmpbsa_prod.tsv` 무단 수정 (resume 성공 시 별도 ledger에 append, 사용자 승인 후 merge)
  - 다른 128 실패건의 retry (out of scope)
  - corrected YAML 자체 변경
- external constraints:
  - SLURM submit은 `sudo -u kim` 필수
  - host-10-0-5-232 (node1) GPU 동기 stall 의심 있어 가능하면 node0 단일 노드 사용 (--nodes=1)

## Non-Goals

- NVT mdp 단축 표준화 (별도 contract)
- True-hang 28건 retry
- Pre-NVT 실패 (initial_overlap, acpype) retry
- node1 hardware 진단/제외 정책
- Stage 2 production submit

## Done When

1. Smoke phase (5 compounds): 5/5이 1 ns 완주 + NVT log 마지막 energy/temp/constraint가 ready 컴파운드와 동일 자릿수.
2. Full phase (38 추가 컴파운드 = 총 43): ≥35건 (≥81%)이 1 ns 완주.
3. 완주한 컴파운드들이 03_npt → 04_npt → equi_prod → mmpbsa_prep까지 도달, `nvt_resume_ready.tsv`에 등록.
4. 본 contract 완료 시점에 prep ready pool: 기존 70 + resume-derived ≥35 = **≥105 / 198 attempts = ≥53%** (50% 게이트 통과).
5. `nvt_resume_failed.tsv`에 실패건의 root cause (post-resume LINCS, hardware re-stall, etc.) 분류.

## Implementation Steps

1. **Reconnaissance (완료)**: 49 후보 도출, cpt 검증, smoke list, contract artifact 준비.
   verify: `.agent/scratch/5331_resume/resume_list_full43.tsv` 43 lines, `resume_list_smoke5.tsv` 5 lines.

2. **resume worker 작성**: 단일 컴파운드용 `nvt_resume_worker.sh`. 인자: run_dir, target_nsteps=1000000. 동작: cd $run_dir/equi → `gmx mdrun -deffnm 02_nvt -cpi 02_nvt.cpt -append -ntmpi 1 -ntomp 8 -gpu_id $CUDA_VISIBLE_DEVICES` → 성공 시 03_npt부터 worker pipeline 호출 (기존 worker의 stage runner 재사용). 실패 모드 분류해 `nvt_resume_failed.tsv`에 기록.
   verify: dry-run으로 한 컴파운드 echo만 출력 확인.

3. **SLURM submit script 작성**: `slurm_mmgbsa_5331_nvt_resume.sh`. 인자: `RESUME_LIST=<tsv>`. 동작: --nodes=1 (node0 단일), 8 GPU, 4시간 walltime, GNU parallel로 GPU=8 jobslot으로 dispatch. smoke=5 / full=43 분기는 RESUME_LIST 파일 선택으로.
   verify: smoke=5 expected wallclock ≤30 min, full=43 expected ≤90 min (most need <500 ps).

4. **Smoke 제출 (사용자 승인 게이트)**: 5건 resume. 모니터.
   verify: 5/5 cpt resume → 1 ns 완주 + 03_npt 진입.

5. **Full 제출 (사용자 승인 게이트, smoke 통과 시)**: 나머지 38건.
   verify: ≥35/43 ready_for_mmpbsa_prod 등록.

6. **Ledger merge + 상태 갱신**: `nvt_resume_ready.tsv`를 원본 `ready_for_mmpbsa_prod.tsv`에 추가 (status="ready_via_resume" 플래그). `.agent/status/mmgbsa.md` 업데이트.
   verify: row count delta = resume-derived ready count.

## Change Discipline

- simplest adequate approach: cpt resume + 기존 worker stage runner 재사용. 새 mdp 안 만듦.
- new abstractions introduced: 단일 컴파운드 resume worker (재사용 가능)
- unrelated code touched: 없음
- pre-existing dead code noticed: 5330 zombie partial dir (정리 안 함)
- request-to-diff trace: 사용자 "진행" (2026-05-21) → 본 contract.

## Verification

- task-specific:
  - smoke 종료 후: `sudo -u ubuntu tail -10 $OUT/node*/VAV1_<smoke>/run*/equi/02_nvt.log` 5건 → "Finished mdrun" + temp ~298 K + LINCS RMSD < 1e-4
  - full 종료 후: `wc -l $OUT/nvt_resume_ready.tsv` ≥ 36 (header + 35건)
  - production traj 정합성 확인: smoke 5건의 equi_prod xtc nframes == ready 컴파운드 xtc nframes
- manual check: VAV1_302 (946k step, 거의 완주) 1분 resume으로 끝나는지

## Risks

- regression risk: cpt resume이 traj/edr append 시 timestep gap 발생 → mmpbsa frame extraction에 영향. 완화: `-append` 옵션과 `02_nvt.cpt` (not _prev.cpt) 사용.
- integration risk: worker pipeline의 03_npt가 cpt-resumed 02_nvt.gro를 input으로 받을 때 동등 처리 보장 필요. 완화: worker가 이미 `-cpi` 패턴 사용 중이므로 stage-stage 입력은 .gro/.tpr 기반.
- hidden dependency risk: 일부 cpt가 사실 손상 (rescue path가 partial write). 완화: 각 cpt에 대해 `gmx check -f 02_nvt.cpt` 사전 검증.

## Rollback

- revert strategy: nvt_resume_ready.tsv를 원본 ready_for_mmpbsa_prod.tsv에 merge 안 했으면 그냥 무시. merge 후 회귀 필요 시 plain row 삭제로 복구.
- containment strategy: cpt resume은 새 .log/.edr 파일에 append하지만 원본 cpt는 보존. resume 실패 시 원본 cpt로 회귀.
- failure mode: smoke 5건 중 2건 이상 실패 시 contract suspend, NO_PROGRESS 28건과 함께 별도 진단.
