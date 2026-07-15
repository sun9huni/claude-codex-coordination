---
status: done
slice: mmgbsa
topic: worker-status-bug
date: 2026-05-26
owner: claude
approved_by: user (2026-05-26, "approved" after /brainstorm round 2 Done When 구체화)
decisions:
  - Scope: Minimal fix in mmgbsa worker script (1 file, ~30-50 lines edit)
  - Target file: `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh`
  - Sync order: shared-first (concurrent edit lock), then local-mirror preserving 3-line diff
  - Validation: zero-compute regression on 5627 ledger + smoke SLURM 1-2 compound on host-10-0-5-36
  - Resource budget: ~1 GPU-h smoke (1-2 compound × ~30 min wall × 1 GPU)
  - Bugs to fix:
    - stage hardcoded "prepare" (line 420) → detect from artifact presence (mmpbsa_prod.tpr / equi_prod.gro / 02_nvt.gro / 00_min.gro)
    - classify_prepare_failure cascade catches "acpype" mention even in successful prep → add early-exit when equi_prod.gro + "Finished mdrun" present
    - new error_reason "mmpbsa_grompp_failed" branch (grompp_multidir.log error pattern)
  - Out of scope (this contract):
    - ready_for_mmpbsa_prod.tsv schema extension (e.g., equi_ready intermediate state)
    - retroactive 5331/5627 ledger re-classification script
    - wall_sec=0 fix (separate, lower priority)
    - worker patch에서 발생할 수 있는 다른 모든 status-tracking 잠재 bug (이번엔 stage+reason만)
---

# mmgbsa worker `failed_stage.tsv` status-tracking bug fix

## Purpose

5627 node disambiguation (10/10 compounds equi 완주 + mmpbsa grompp 실패)에서 `failed_stage.tsv`가 모든 row를 `stage=prepare, error_reason=parameterization_failed`로 mis-record함을 발견. 코드 inspection 결과 두 bug 확인:

1. **stage hardcoded "prepare"** (worker:420) — `prepare_equi_one` 함수가 prepare + equi + mmpbsa grompp 세 단계를 다 실행하지만 실패 row의 stage column이 무조건 "prepare"
2. **classify_prepare_failure false-positive** (worker:97-98) — log에 "acpype" 또는 "parameteriz" 한 번이라도 나오면 `parameterization_failed`로 분류. 정상 prep 로그에도 acpype 호출 흔적이 있어 post-equi 실패도 잘못 분류됨

향후 모든 mmgbsa 분석 신뢰성에 영향. 본 contract는 worker 1개 파일에 minimal patch + zero-compute regression test + smoke SLURM verification.

## Current State

- Bug 발견: 5627 분석 (P1, 2026-05-26)
  - 10/10 compounds 모두 equi_prod.xtc 7-10MB + cpt 2.3-3.3MB 정상 생성 (equi 완주 증거)
  - 동일 10 compounds 모두 failed_stage.tsv에 `stage=prepare, error_reason=parameterization_failed` 기록
  - mmpbsa/ dir에 grompp_multidir.log + mmpbsa_prod.mdp만 존재 (mmpbsa_prod.tpr 없음 → grompp 실패)
- 코드 inspection (read-only) 완료:
  - 함수 `prepare_equi_one` [worker:300-388]: prepare → equi → mmpbsa grompp 세 단계 실행
  - 함수 `classify_prepare_failure` [worker:61-101]: log content 키워드 cascade로 reason 분류
  - 함수 `prepare_failure_metadata` [worker:104-160]: phase log에서 last_step/last_time 추출
  - 함수 `prepare_chunk` [worker:390-432]: 실패 시 `stage="prepare"` hardcoded row write [worker:420]
- Local vs shared diff: 3줄 (shared가 MDP_MMPBSA_FILE override 추가). Sync 시 보존 필수.
- 다른 agent와 concurrent edit 위험 → shared-first lock 전략

## Assumptions And Questions

- assumptions:
  - failed_stage 스키마 변경 없이 stage column 값만 정확하게 — header 변경 불필요
  - mmpbsa_prod.tpr/equi_prod.gro/04_npt.gro/03_npt.gro/02_nvt.gro/01_nvt.gro/00_min.gro 존재 여부로 도달 stage 신뢰성 있게 추론 가능 (atomic file writes 가정)
  - "mmpbsa_grompp_failed"는 새 error_reason이지만 downstream 분석 (`merge_normtest143_stage4_ddg.py` 등)이 이 값을 ignore 또는 unknown으로 처리 — backward compat
  - smoke 1-2 compound 가 worker 정상 동작 확인에 충분 (regression test가 분류 logic 검증)
- open questions:
  - host-10-0-5-36에서 mmpbsa grompp가 실패한 정확한 원인은 별도 조사 필요 (gmx binary 차이? topology issue?) — 본 contract scope 아님
  - smoke compound로 어떤 것 선택할지: VAV1_357 (5627 PASS) + VAV1_411 (top hit, cross-workstream) 추천
- tradeoffs:
  - Stage detection을 artifact presence로 하면 cleanup race condition 위험 (rm -rf 중에 stage 판정?) — set -eo pipefail이 mid-run cleanup 막아주므로 안전
  - 새 error_reason 추가는 downstream 호환성 risk — 단순 string column이라 schema break 없음

## Constraints

- allowed change scope:
  - shared `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh` 단일 파일
  - local mirror (3줄 diff 보존)
  - 새 smoke SLURM script: `scripts/mmgbsa_16gpu_multidir/slurm_mmgbsa_worker_smoke.sh` (derive from `slurm_mmgbsa_5331_node0_disambig.sh`)
  - 새 regression test: `scripts/mmgbsa_16gpu_multidir/tests/test_classify_prepare_failure.sh` (또는 .py)
  - report: `analysis/mmgbsa/reports/worker_status_bug_fix_20260526.md`
- forbidden change scope:
  - `run_equilibration.py` / `parameterize_ligand_standalone.py` 등 worker 호출하는 dep script 변경 금지
  - 02_nvt.mdp / 03_npt.mdp / etc. 변경 금지
  - failed_stage.tsv schema (header) 변경 금지 — column 의미만 정확하게
  - ready_for_mmpbsa_prod.tsv 변경 금지 (out of scope)
  - 5331/5627 OUT_BASE 디렉토리 내용 변경 금지
- external constraints:
  - SLURM submit: `sbatch` (ubuntu user), partition=gpu, qos=normal, walltime 01:00:00, --exclude=host-10-0-5-232
  - Smoke output dir: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/outputs/mmgbsa_worker_smoke_<TS>/`
  - Logs: `/mnt/data/users/ubuntu/logs/mmgbsa_worker_smoke_<jobid>.{out,err}`
  - 자원 예산: 1 node × 1-2 GPU × ~30 min wall ≈ **~1 GPU-h**

## Non-Goals

- ready_for_mmpbsa_prod.tsv schema 확장 (equi_ready 중간 상태) — out of scope
- 5331/5627 ledger 재분류 script — 별도 작업 (필요하면 후속 contract)
- wall_sec=0 metadata bug — lower priority, 별도
- mmpbsa grompp가 실패한 근본 원인 진단 (gmx version, topology issue 등) — 본 contract는 ledger 정확도만
- 다른 worker (stage2/3) status-tracking bug — 본 contract는 stage1 prepare path만
- Worker 전체 refactor (예: status tracking을 Python module로 분리) — over-engineering

## Done When

1. **Bug fix applied to shared worker** (1 file, ~30-50 lines edit):
   - stage detection: artifact presence 기반 (mmpbsa_grompp / equi_prod / 04_npt / 03_npt / 02_nvt / 01_nvt / 00_min / prepare)
   - classify_prepare_failure early-exit: equi_prod.gro 존재 + "Finished mdrun" 시 acpype keyword cascade skip
   - new "mmpbsa_grompp_failed" branch with grompp_multidir.log error pattern detection

2. **Local mirror sync** (3-line diff preserved): `diff local shared` = 3줄 (MDP_MMPBSA_FILE block만)

3. **Zero-compute regression test on 5627 logs** — **expected output 명시 표**:

   5627 OUT_BASE: `/mnt/data/users/kim/mmgbsa_outputs/node_disambig_5331_20260526_104912/node0/`. 모든 10 compound가 equi_prod.gro 정상 생성 + mmpbsa_prod.tpr 부재 → fix 후 동일 분류 기대:

   | compound | expected stage | expected error_reason |
   |---|---|---|
   | VAV1_357 | mmpbsa_grompp | mmpbsa_grompp_failed |
   | VAV1_364 | mmpbsa_grompp | mmpbsa_grompp_failed |
   | VAV1_369 | mmpbsa_grompp | mmpbsa_grompp_failed |
   | VAV1_375 | mmpbsa_grompp | mmpbsa_grompp_failed |
   | VAV1_376 | mmpbsa_grompp | mmpbsa_grompp_failed |
   | VAV1_377 | mmpbsa_grompp | mmpbsa_grompp_failed |
   | VAV1_411 | mmpbsa_grompp | mmpbsa_grompp_failed |
   | VAV1_419 | mmpbsa_grompp | mmpbsa_grompp_failed |
   | VAV1_438 | mmpbsa_grompp | mmpbsa_grompp_failed |
   | VAV1_469 | mmpbsa_grompp | mmpbsa_grompp_failed |

   Acceptance: 10/10 rows match (deviation 0).

4. **5331 regression sample (7 compounds, 1 per existing reason)** — **expected: stage 컬럼은 정정 (prepare → 실제 stage), reason 유지**:

   5331 OUT_BASE: `outputs/norm143_corrected_seed16_stage1_20260520_111530/`

   | compound | CURRENT (buggy) stage | CURRENT reason | EXPECTED stage (fix) | EXPECTED reason |
   |---|---|---|---|---|
   | VAV1_309 | prepare | early_nvt_hang | 02_nvt (또는 01_nvt) | early_nvt_hang |
   | VAV1_370 | prepare | initial_overlap_inf_force | 00_min | initial_overlap_inf_force |
   | VAV1_352 | prepare | acpype_timeout | prepare | acpype_timeout |
   | VAV1_353 | prepare | 00_min_timeout | 00_min | 00_min_timeout |
   | VAV1_193 | prepare | 04_npt_lincs_after_rescue | 04_npt | 04_npt_lincs_after_rescue |
   | VAV1_211 | prepare | grompp_failed | prepare | grompp_failed |
   | VAV1_508 | prepare | post_rescue_02_nvt_lincs | 02_nvt | post_rescue_02_nvt_lincs |

   Acceptance: 7/7 reason 유지, 5/7 stage 정정 (2/7은 진짜 prepare 실패라 stage 그대로).

5. **5331 ready boundary sample (1 compound)**:

   | compound | run_type | EXPECTED behavior |
   |---|---|---|
   | VAV1_122 | RunA | classify+stage detection 시 mmpbsa_prod.tpr 존재 → ready 로우 정상 기록, failed_stage에 entry 없음 |

   Acceptance: 1/1 정상 (no regression on ready path).

6. **Smoke SLURM 2 compound on host-10-0-5-36**:
   - VAV1_357 (5627 PASS confirmed: equi_prod 완주) + VAV1_411 (top hit DC50 1.99nM, cross-workstream gain)
   - 새 worker로 run → ledger에 정확한 stage + reason
   - **시나리오 A (mmpbsa grompp 또 실패)**: 2/2 cells stage=mmpbsa_grompp, reason=mmpbsa_grompp_failed (5627 패턴 재현 + ledger 정확)
   - **시나리오 B (mmpbsa grompp 성공)**: 2/2 cells ready_for_mmpbsa_prod에 entry 정상 기록, failed_stage에 entry 없음 (boundary case 통과)

   Acceptance: 시나리오 A 또는 B 둘 다 fix 성공 (ledger 정확이 핵심, mmpbsa 자체 성공 여부는 본 contract scope 아님).

7. **Report 작성**: `analysis/mmgbsa/reports/worker_status_bug_fix_20260526.md`
   - before/after 표 (위 §3-5 결과)
   - smoke 결과 (시나리오 A/B 판정)
   - 새 worker behavior summary + stage detection logic 설명

8. **`.agent/status/mmgbsa.md` §Closed에 worker bug fix entry 추가** + ledger 신뢰도 회복 명시 + 5331 통계 재해석 가능성 언급

9. **`.agent/handoffs/CURRENT.md` remaining_actions 갱신**

## Implementation Steps

1. **Worker patch on shared** (lock 잡고 진행)
   - Edit `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh`
   - 새 helper function `detect_failed_stage`: 도달한 stage를 artifact presence 기반 추론
   - `classify_prepare_failure`에 early-exit 추가 (equi_prod.gro + Finished mdrun)
   - `classify_prepare_failure`에 "mmpbsa_grompp_failed" 새 branch 추가
   - `prepare_chunk` [worker:420] 의 stage hardcoded "prepare"를 `$(detect_failed_stage "$failed_run_dir")`로 교체
   - verify: `bash -n` 통과, shellcheck (있으면) warning 없음

2. **Local mirror sync** (3줄 diff 보존)
   - `git diff` shared vs local로 보존할 영역 (lines 48-50, MDP_MMPBSA_FILE) 확인
   - patched file을 local에 cp + 3줄 diff re-apply
   - verify: `diff local shared` = 3줄 (MDP_MMPBSA_FILE block만)

3. **Zero-compute regression test**
   - 5627 logs/artifacts에서 worker function들을 standalone shell test로 호출 (sourcing worker로 helper expose)
   - 10 compound × (detect_failed_stage + classify_prepare_failure) = 20 calls
   - 기대 결과 표:
     | compound | new stage | new reason |
     |---|---|---|
     | VAV1_357 | mmpbsa_grompp | mmpbsa_grompp_failed |
     | ... (10개) | | |
   - 5331 sample (진짜 prep 실패 + 진짜 02_nvt fail) regression: 분류 유지
   - verify: 모든 5627 row가 `stage=mmpbsa_grompp`, 5331 regression sample 분류 유지

4. **Smoke SLURM 1-2 compound on host-36**
   - 새 SLURM script `slurm_mmgbsa_worker_smoke.sh`: `slurm_mmgbsa_5331_node0_disambig.sh`에서 derive, sources.tsv를 VAV1_357 (+411) 2-row subset으로 교체, --time=01:00:00, --exclude=host-232
   - 출력 dir: `outputs/mmgbsa_worker_smoke_<TS>/`
   - 사용자 승인 후 `sbatch` 제출
   - verify: 종료 후 ledger 확인 — stage 컬럼이 정확 (mmpbsa_grompp 또는 ready)

5. **Report 작성**
   - `analysis/mmgbsa/reports/worker_status_bug_fix_20260526.md`
   - before/after 비교 표, smoke 결과, behavior summary
   - verify: report markdown valid

6. **Status doc + CURRENT.md 업데이트**
   - verify: `./scripts/handoff.sh claude` clean

## Change Discipline

- simplest adequate approach: 단일 파일 patch, helper function 추가, classify cascade에 early-exit + 새 branch. Refactor 안 함.
- new abstractions introduced: `detect_failed_stage` helper function (worker 내부 함수)
- unrelated code touched: 없음
- pre-existing dead code noticed: 없음
- request-to-diff trace: 5627 P1 분석 시 ledger lies 발견 → 사용자 "D 진행" → /brainstorm → 본 contract

## Verification

각 Done When 항목별 verify 명령:

- §1: `bash -n scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh` (exit 0)
- §2: `diff /home/ubuntu/FKSFold-Boltz_Advancement/scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh | wc -l` = 3 (또는 같은 패턴 줄 수)
- §3: regression test script가 10 row 비교 결과 `0 mismatches` 출력
- §4: regression test script가 7 row 비교 결과 `7/7 reason 일치, 5/7 stage 정정` 출력
- §5: regression test가 VAV1_122 RunA에 대해 `ready row generated, no failed entry` 출력
- §6: `sacct -j <jobid>` State=COMPLETED + smoke OUT_BASE의 ledger 분석
- §7: report markdown 존재 + 3 표 (5627, 5331 reason, 5331 ready) + smoke section
- §8-9: `./scripts/handoff.sh claude` clean

## Risks

- regression risk: classify cascade 순서 바꿔서 기존 분류 깨질 위험 → mitigation = early-exit만 추가 (cascade 순서 유지) + 5331 regression test
- integration risk: shared worker 수정 중 다른 agent가 동시 편집 → mitigation = shared-first lock 잡기, ETA 명시
- artifact race risk: stage detection이 cleanup 중간 잡으면 잘못 판정 → mitigation = set -eo pipefail이 partial cleanup 방지 + verify before writing TSV
- smoke grompp가 또 실패할 위험: 그것은 ledger 정확도 테스트이므로 OK (실제로 mmpbsa_grompp 분류되면 contract 성공)
- backward compat: 새 error_reason이 downstream merge script에 영향? `merge_normtest143_stage4_ddg.py` 빠르게 inspect 필요 → 단순 string column이라 unknown으로 처리될 듯

## Rollback

- revert strategy: `git revert <commit>` on shared worker. Local re-sync. Smoke output dir 삭제. Worker is single-file change so trivial revert
- containment strategy: 새 file (smoke SLURM, regression test, report) 별도 path. shared worker만 변경
- failure mode: regression test가 5331 분류 깨면 contract suspend, root cause 분석 후 재시도

## Triggers Matched (WORKFLOW.md §2)

- ✅ SLURM submission (smoke 1-2 cell)
- ✅ Local vs shared concurrent edits (worker는 양쪽에 존재, sync 필수)
- ✅ Ranking-adjacent (ledger 정확도가 mmgbsa cohort selection에 영향)
- ❌ 4+ files modified (1 file + smoke + regression test = 3)
- ❌ FragMap scoring mode 변경
- ❌ shared storage destructive write (smoke output is read-only safe)

## Progress Log

- 2026-05-26: contract drafted via /brainstorm (status: pending)
  - Q1 scope = Minimal (stage detect + classify early-exit + new mmpbsa_grompp_failed branch)
  - Q2 validation = Smoke SLURM 1-2 compound on host-10-0-5-36
  - Q3 sync = Shared-first lock, then local mirror with 3-line diff preserved
- Bug evidence: 5627 OUT_BASE `/mnt/data/users/kim/mmgbsa_outputs/node_disambig_5331_20260526_104912/` — 10 compounds equi_prod.xtc 7-10MB, mmpbsa/mmpbsa_prod.tpr absent, failed_stage.tsv 전부 `stage=prepare, reason=parameterization_failed`
- 2026-05-26 revision via /brainstorm round 2 (Done When 구체화):
  - 5627 expected output 10-row table (모두 mmpbsa_grompp / mmpbsa_grompp_failed)
  - 5331 regression sample 7 compounds, 1 per reason (VAV1_309/370/352/353/193/211/508) with explicit current vs expected (5/7 stage flip, 2/7 stage unchanged when 진짜 prepare 실패)
  - 5331 ready boundary sample VAV1_122 (no regression on ready path)
  - Smoke acceptance 시나리오 A (mmpbsa 또 실패 = ledger 정확 확인) vs B (mmpbsa 성공 = boundary case 확인) 둘 다 contract pass
  - Verification 명령 각 Done When 항목별 1-line shell 명시
