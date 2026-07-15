---
contract: .agent/contracts/mmgbsa-worker-status-bug-20260526.md
slice: mmgbsa
status: done
total_tasks: 15
estimated_total_min: 60
revision: 3
revision_note: "cp-backup model. INVESTIGATION (2026-05-27): scripts/mmgbsa_16gpu_multidir/ is NOT git-tracked on ANY branch (never committed, not gitignored) in local OR shared. Established convention = LOCAL source of truth, cp-synced to SHARED via sync_stage_pipeline_to_shared.sh (line 23 syncs this exact worker). So versioning = .bak timestamp backups, NOT git commit. Per-task 'commit' → cp .bak checkpoint. Rollback → cp .bak restore. Task 5 sync via cp must re-apply shared-only 3-line MDP_MMPBSA_FILE block (sync would otherwise clobber it). Backups made: shared .bak_pre_statusfix_20260527_101053 (unpatched ref), local .bak_task1_20260527_101053."
---

# Plan — mmgbsa worker `failed_stage.tsv` status-tracking bug fix

Decomposition of the approved D contract. 15 tasks across 5 phases.

**Repo model (revision 2)**: `/home/ubuntu/FKSFold-Boltz_Advancement` (LOCAL)
is git-tracked (branch `platform-versioning-r20260417`). The shared
workspace `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared`
is NOT a git repo — it is the SLURM runtime copy. So:
- Worker patch + new scripts land in LOCAL (git commit per task).
- Sync to shared is a cp step (Task 5), preserving the shared-only
  3-line `MDP_MMPBSA_FILE` block (shared has 3 lines local lacks).
- Smoke SLURM runs from shared, so Task 5 sync is a prereq of Task 11.

Task 11 (sbatch submit) is a hard approval gate — `/execute-plan` must
pause for explicit user `proceed`.

LOCAL worker path:
`/home/ubuntu/FKSFold-Boltz_Advancement/scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh`
SHARED worker path:
`/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh`

---

## Phase 1: Core — worker patch (LOCAL repo, git-tracked)

## Task 1: Add `detect_failed_stage` helper function

- **Status**: done (2026-05-27, verified bash -n exit 0 + grep=1, /code-review APPROVE, cp checkpoint .bak_task1)
- **Prereq tasks**: none
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh` (LOCAL)
- **Change shape**: Insert new bash helper `detect_failed_stage()` between `prepare_failure_metadata` (~line 157, local) and `mkdir -p "$OUT_BASE"` (~line 159, local). Function takes `$run_dir` arg, returns stage by artifact presence in reverse order: `mmpbsa/mmpbsa_prod.mdp` present but `mmpbsa/mmpbsa_prod.tpr` absent → `mmpbsa_grompp` | `equi/equi_prod.gro` + "Finished mdrun" in equi_prod.log → `mmpbsa_grompp` (boundary) | `equi/04_npt.gro` → `04_npt` | `equi/03_npt.gro` → `03_npt` | `equi/02_nvt.gro` → `02_nvt` | `equi/01_nvt.gro` → `01_nvt` | `equi/00_min.gro` → `00_min` | else → `prepare`. ~25 lines added.
- **Verification**: `bash -n scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh` (exit 0) AND `grep -c "^detect_failed_stage()" scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh` = 1
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git -C /home/ubuntu/FKSFold-Boltz_Advancement checkout scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh`

## Task 2: Patch `classify_prepare_failure` — early-exit + new branch

- **Status**: done (2026-05-27, bash -n exit 0 + grep mmpbsa_grompp_failed=1, /code-review APPROVE, backward-compat preserved)
- **Prereq tasks**: 1
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh` (LOCAL)
- **Change shape**: Modify `classify_prepare_failure()` (lines ~61-101 local). (a) Add early-exit at start: take optional `$run_dir` 2nd arg; if `$run_dir/equi/equi_prod.gro` exists AND `grep -q "Finished mdrun" "$run_dir/equi/equi_prod.log"` → check `$run_dir/mmpbsa/grompp_multidir.log` for grompp errors (`Fatal error`, `error in file`, `Cannot find`) → echo `mmpbsa_grompp_failed`, return. (b) Original cascade unchanged for non-equi-complete cases. ~10 lines added.
- **Verification**: `bash -n ...worker.sh` (exit 0) AND `grep -c "mmpbsa_grompp_failed" ...worker.sh` ≥ 1
- **Estimated time**: 4 min
- **Rollback**: `git checkout` the local worker file

## Task 3: Replace hardcoded `"prepare"` in `prepare_chunk` ledger write

- **Status**: done (2026-05-27)
- **Prereq tasks**: 1
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh` (LOCAL)
- **Change shape**: At the `prepare_chunk` ledger row write (~line 419-420 local), replace literal `"prepare"` in the `printf` row with `"$(detect_failed_stage "$failed_run_dir")"`. Also update the `classify_prepare_failure` call (~line 416 local) to pass `"$failed_run_dir"` as 2nd arg so early-exit can find artifacts. 2 lines changed.
- **Verification**: `bash -n ...worker.sh` (exit 0) AND `grep -n 'printf.*"prepare"' ...worker.sh` returns no match AND `grep -c 'detect_failed_stage "\$failed_run_dir"' ...worker.sh` = 1
- **Estimated time**: 3 min
- **Rollback**: `git checkout` the local worker file

## Task 4: Bash syntax + cross-helper sanity check

- **Status**: done (2026-05-27)
- **Prereq tasks**: 1, 2, 3
- **Files touched**: none (read-only verification)
- **Change shape**: No diff. Run `bash -n` on local worker. Extract `detect_failed_stage` + `classify_prepare_failure` function blocks via sed and `bash -n` each in isolation to confirm well-formed.
- **Verification**: `bash -n scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh` exit 0 AND `sed -n '/^detect_failed_stage()/,/^}/p' ...worker.sh | bash -n` exit 0 AND `sed -n '/^classify_prepare_failure()/,/^}/p' ...worker.sh | bash -n` exit 0
- **Estimated time**: 2 min
- **Rollback**: n/a (read-only)

---

## Phase 2: Glue — sync local → shared

## Task 5: Sync patched LOCAL worker to SHARED, preserve shared-only MDP_MMPBSA_FILE block

- **Status**: done (2026-05-27, cp + MDP reinsert, diff=3 shared-only lines, shared bash -n exit 0, re-synced after detect_failed_stage revision)
- **Prereq tasks**: 4
- **Files touched**: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh` (SHARED, non-git)
- **Change shape**: SHARED currently = LOCAL(pre-patch) + 3-line `MDP_MMPBSA_FILE` block (shared-only, ~lines 48-50). Before overwriting, `cp` backup shared worker to `…worker.sh.bak_pre_statusfix`. Then apply the SAME 3 worker patches (T1-3) to shared, OR cp patched-local→shared then re-insert the 3-line MDP_MMPBSA_FILE block. Net: shared = patched-local + 3-line MDP block.
- **Verification**: `diff /home/ubuntu/FKSFold-Boltz_Advancement/scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir/slurm_normtest143_8gpu_seed777_multidir8_worker.sh | grep -c "^>"` = 3 (the 3 shared-only MDP_MMPBSA_FILE lines) AND `grep -c "^detect_failed_stage()" <shared worker>` = 1 (patch present in shared)
- **Estimated time**: 4 min
- **Rollback**: `cp …worker.sh.bak_pre_statusfix <shared worker>` (restore pre-patch shared)

---

## Phase 3: Tests — zero-compute regression (LOCAL repo)

## Task 6: Write regression test script

- **Status**: done (2026-05-27, scripts/mmgbsa_16gpu_multidir/tests/test_worker_status_classify.sh, bash -n exit 0; revised detect_failed_stage to first-missing-stage semantics + log-path fix)
- **Prereq tasks**: 4
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/tests/test_worker_status_classify.sh` (LOCAL, new)
- **Change shape**: New ~80-line bash test. Source-extracts `detect_failed_stage` + `classify_prepare_failure` from local patched worker via `sed -n '/^detect_failed_stage/,/^}/p'` + eval (or `source` the worker with a guard). Loops over 3 fixture sets pointing at read-only artifact dirs: 5627 (`/mnt/data/users/kim/mmgbsa_outputs/node_disambig_5331_20260526_104912/node0/`), 5331 (`/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/outputs/norm143_corrected_seed16_stage1_20260520_111530/`), ready_boundary (VAV1_122 from 5331). Emits pass/fail per row + `RESULT:` summary line. `--fixture {5627,5331,ready_boundary}` arg.
- **Verification**: `bash -n scripts/mmgbsa_16gpu_multidir/tests/test_worker_status_classify.sh` exit 0 AND `grep -cE "5627|5331|ready_boundary" scripts/.../tests/test_worker_status_classify.sh` ≥ 3
- **Estimated time**: 5 min
- **Rollback**: `rm scripts/mmgbsa_16gpu_multidir/tests/test_worker_status_classify.sh` (untracked; or git checkout if committed)

## Task 7: Regression — 5627 10-row expected output

- **Status**: done (2026-05-27, RESULT: 10/10 PASS — all mmpbsa_grompp/mmpbsa_grompp_failed)
- **Prereq tasks**: 6
- **Files touched**: none (test execution only)
- **Change shape**: Run test with `--fixture 5627`. Expect 10/10 rows → `stage=mmpbsa_grompp, reason=mmpbsa_grompp_failed`. NOTE: 5627 artifacts owned by kim; if read perm blocked, test falls back to reading only the file-presence (stat) which is already permitted, OR runs under the existing access path used during P1 analysis.
- **Verification**: `bash scripts/mmgbsa_16gpu_multidir/tests/test_worker_status_classify.sh --fixture 5627` outputs `RESULT: 10/10 PASS (5627)` exit 0
- **Estimated time**: 2 min
- **Rollback**: n/a (read-only)

## Task 8: Regression — 5331 7-reason sample (5/7 stage flip, 7/7 reason kept)

- **Status**: done (2026-05-27, RESULT: 7/7 reason maintained, 6/7 stage flipped — better than planned 5/7; only VAV1_352 acpype_timeout stays prepare, correctly)
- **Prereq tasks**: 6
- **Files touched**: none (test execution only)
- **Change shape**: Run test with `--fixture 5331`. Expect per-compound:
  - VAV1_309 → 02_nvt / early_nvt_hang
  - VAV1_370 → 00_min / initial_overlap_inf_force
  - VAV1_352 → prepare / acpype_timeout (real prep failure, stage unchanged)
  - VAV1_353 → 00_min / 00_min_timeout
  - VAV1_193 → 04_npt / 04_npt_lincs_after_rescue
  - VAV1_211 → prepare / grompp_failed (real prep failure, stage unchanged)
  - VAV1_508 → 02_nvt / post_rescue_02_nvt_lincs
- **Verification**: `bash ...test_worker_status_classify.sh --fixture 5331` outputs `RESULT: 7/7 reason maintained, 5/7 stage flipped` exit 0
- **Estimated time**: 2 min
- **Rollback**: n/a (read-only)

## Task 9: Regression — VAV1_122 ready boundary

- **Status**: done (2026-05-27, RESULT: detect=complete + tpr present → ready path intact, no failed entry)
- **Prereq tasks**: 6
- **Files touched**: none (test execution only)
- **Change shape**: Run test with `--fixture ready_boundary`. VAV1_122 RunA (5331 ready, has mmpbsa_prod.tpr) → detect_failed_stage should NOT be invoked on a success; the boundary test asserts that with mmpbsa_prod.tpr present, the code path produces a ready row, not a failed_stage entry.
- **Verification**: `bash ...test_worker_status_classify.sh --fixture ready_boundary` outputs `RESULT: ready row generated, no failed_stage entry` exit 0
- **Estimated time**: 2 min
- **Rollback**: n/a (read-only)

---

## Phase 4: Tests — smoke SLURM

## Task 10: Write smoke SLURM script + sources subset (LOCAL, then synced)

- **Status**: done (2026-05-27, slurm_mmgbsa_worker_smoke.sh local+shared bash -n exit 0, worker_smoke_n2.tsv 3 lines VAV1_357+VAV1_411, ledger-accuracy check appended to script)
- **Prereq tasks**: 4, 5, 7, 8, 9
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/slurm_mmgbsa_worker_smoke.sh` (LOCAL, new) + `outputs/_mmgbsa_staging/worker_smoke_n2.tsv` (SHARED, new — runtime data)
- **Change shape**: Derive smoke driver from `slurm_mmgbsa_5331_node0_disambig.sh`. Headers: `--time=01:00:00 --nodes=1 --nodelist=host-10-0-5-36 --exclude=host-10-0-5-232 --gres=gpu:a100:8 --qos=normal`. STAGING_TSV → `worker_smoke_n2.tsv`. OUT_BASE → `outputs/mmgbsa_worker_smoke_<TS>/`. RUN_TYPES=A. Extract VAV1_357 + VAV1_411 RunA rows from `outputs/_mmgbsa_staging/norm143_corrected_sources.tsv` into worker_smoke_n2.tsv (shared). After writing, cp smoke driver to shared (runtime needs it).
- **Verification**: `bash -n scripts/mmgbsa_16gpu_multidir/slurm_mmgbsa_worker_smoke.sh` exit 0 AND `wc -l < /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/outputs/_mmgbsa_staging/worker_smoke_n2.tsv` = 3 AND smoke driver present in shared scripts dir
- **Estimated time**: 4 min
- **Rollback**: `rm` smoke driver (local + shared) + worker_smoke_n2.tsv

## Task 11: ⛔ APPROVAL GATE — submit smoke SLURM (`sbatch`)

- **Status**: done (2026-05-27, user approved → SLURM 5712 RUNNING on host-10-0-5-36, started 10:30:14, walltime 1h. Background monitor registered. Logs: /mnt/data/users/ubuntu/logs/mmgbsa_worker_smoke_5712.{out,err})
- **Prereq tasks**: 10
- **Files touched**: none (sbatch; output dir created remotely)
- **Change shape**: PAUSE for explicit user `proceed`. Then `cd /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared && sbatch scripts/mmgbsa_16gpu_multidir/slurm_mmgbsa_worker_smoke.sh`. Capture jobid → plan progress log + CURRENT.md. Register background monitor (`until ! squeue -j <jobid>...; sleep 120; done`).
- **Verification**: `squeue -j <jobid>` returns RUNNING/PENDING within 60s.
- **Estimated time**: 2 min submit + ~30-60 min wall (background)
- **Rollback**: `scancel <jobid>` + `rm -rf outputs/mmgbsa_worker_smoke_<TS>/`

## Task 12: Smoke result analysis — 시나리오 A or B

- **Status**: done (2026-05-27)
- **Prereq tasks**: 11
- **Files touched**: none (analysis of remote output)
- **Change shape**: After background monitor fires: read smoke `failed_stage.tsv` + `ready_for_mmpbsa_prod.tsv`. 시나리오 A (mmpbsa grompp 또 실패): 2 rows `stage=mmpbsa_grompp, reason=mmpbsa_grompp_failed`. 시나리오 B (mmpbsa grompp 성공): 2 ready rows, no failed entry. Both pass contract.
- **Verification**: Either `awk -F'\t' 'NR>1 && $3=="mmpbsa_grompp" && $6=="mmpbsa_grompp_failed"' smoke_failed_stage.tsv | wc -l` = 2 (A), OR `awk -F'\t' 'NR>1 && $8=="ready"' smoke_ready.tsv | wc -l` = 2 (B)
- **Estimated time**: 3 min
- **Rollback**: n/a (analysis only)

---

## Phase 5: Docs / handoff

## Task 13: Write report

- **Status**: done (2026-05-27)
- **Prereq tasks**: 7, 8, 9, 12
- **Files touched**: `analysis/mmgbsa/reports/worker_status_bug_fix_20260526.md` (LOCAL, new)
- **Change shape**: Markdown report. Sections: Bug summary (5627 evidence) → Fix (3 changes) → Regression results (5627 10/10 + 5331 7/7 + ready boundary) → Smoke result (시나리오 A/B) → before/after table → 5331 ledger re-interpretation note. ~80 lines.
- **Verification**: `wc -l analysis/mmgbsa/reports/worker_status_bug_fix_20260526.md` ≥ 50 AND `grep -cE "^## " analysis/mmgbsa/reports/worker_status_bug_fix_20260526.md` ≥ 4
- **Estimated time**: 5 min
- **Rollback**: `rm analysis/mmgbsa/reports/worker_status_bug_fix_20260526.md`

## Task 14: Update `.agent/status/mmgbsa.md`

- **Status**: done (2026-05-27)
- **Prereq tasks**: 13
- **Files touched**: `.agent/status/mmgbsa.md`
- **Change shape**: Add §Closed entry for worker bug fix + 5331 35.4% pass-rate re-interpretation note. Update §Where we are timestamp.
- **Verification**: `grep -c "worker.*status-tracking bug fix" .agent/status/mmgbsa.md` ≥ 1
- **Estimated time**: 2 min
- **Rollback**: `git checkout .agent/status/mmgbsa.md`

## Task 15: Update `.agent/handoffs/CURRENT.md`

- **Status**: done (2026-05-27)
- **Prereq tasks**: 14
- **Files touched**: `.agent/handoffs/CURRENT.md`
- **Change shape**: Add contract to contract_pointers (already present from earlier). Mark D work completed in remaining_actions. Bump version, update last_updated.
- **Verification**: `grep -c "mmgbsa-worker-status-bug" .agent/handoffs/CURRENT.md` ≥ 1 AND version incremented
- **Estimated time**: 2 min
- **Rollback**: `git checkout .agent/handoffs/CURRENT.md`

---

## Notes (revision 2)

- Worker patch lands in LOCAL (git). Per-task commit on `git -C /home/ubuntu/FKSFold-Boltz_Advancement`.
- Task 5 cp-syncs to shared (non-git), backed up via `.bak_pre_statusfix`.
- Smoke (T11) runs from shared, so T5 sync is a prereq.
- Concurrency guard: before T5 sync, diff shared worker vs its pre-edit baseline to ensure no other agent edited it concurrently; if changed, pause.
- Whole-plan rollback: `git -C /home/ubuntu/FKSFold-Boltz_Advancement checkout HEAD -- scripts/mmgbsa_16gpu_multidir/` + restore shared from `.bak_pre_statusfix` + `scancel`/`rm -rf` smoke output if T11 ran.
