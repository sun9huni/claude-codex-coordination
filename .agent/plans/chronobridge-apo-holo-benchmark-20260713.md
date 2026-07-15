---
contract: .agent/contracts/chronobridge-apo-holo-benchmark-20260713.md
slice: chronobridge
status: done
total_tasks: 16
estimated_total_min: 62
---

# Plan: chronobridge Phase A — generic apo/holo dynamics benchmark

## Task 1: scratch workspace + contract pointer

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/chronobridge/phaseA/README.md`
- **Change shape**: New directory `.agent/scratch/chronobridge/phaseA/`. README states the
  contract path, the one-line goal (recover shuffled state order + reject injected FP frames
  on a CRBN-agnostic public MD trajectory, beat random/baseline with CI-separated margin), and
  a `## Subdirs` stub list (`data/`, `scripts/`, `results.md` to come).
- **Verification**: `test -f .agent/scratch/chronobridge/phaseA/README.md && grep -q chronobridge-apo-holo-benchmark-20260713 .agent/scratch/chronobridge/phaseA/README.md`
- **Estimated time**: 2 min
- **Rollback (if this task only)**: `rm -rf .agent/scratch/chronobridge/phaseA/`

## Task 2: survey candidate public MD trajectories

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/chronobridge/phaseA/data_source_notes.md`
- **Change shape**: WebSearch/WebFetch for 2-4 candidate public apo/holo (or long-timescale)
  MD trajectory sources (e.g. DESRES public releases, MDRepo, GPCRmd, Dynameomics, ATLAS MD
  database). For each: system, length/frame-count, license/redistribution terms, access method
  (direct download vs registration-gated). Recommend one with a one-line reason.
- **Verification**: `grep -c '^##' .agent/scratch/chronobridge/phaseA/data_source_notes.md` → ≥2 (at least 2 candidates documented) and a `## Decision` section naming the chosen dataset.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseA/data_source_notes.md`

## Task 3: fetch chosen trajectory data

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `.agent/scratch/chronobridge/phaseA/data/` (raw trajectory files or a
  representative subset), `.agent/scratch/chronobridge/phaseA/data_source_notes.md` (append
  fetch log)
- **Change shape**: Download/fetch the dataset chosen in Task 2 (subset acceptable if the full
  set is large — document the subsampling choice). No SLURM; local/CPU fetch only.
- **Verification**: `ls -la .agent/scratch/chronobridge/phaseA/data/ | head` shows non-empty
  files; append a line to `data_source_notes.md` with file count + total size.
- **Estimated time**: 5 min (network-bound; may vary)
- **Rollback (if this task only)**: `rm -rf .agent/scratch/chronobridge/phaseA/data/`

## Task 4: trajectory loader with ground-truth order labels

- **Status**: done
- **Prereq tasks**: 3
- **Files touched**: `.agent/scratch/chronobridge/phaseA/scripts/load_trajectory.py`
- **Change shape**: Parses the fetched trajectory into a list of frames/structures, each tagged
  with its true time-order index (the ground truth the benchmark will later hide from the
  method and use only for scoring).
- **Verification**: `python .agent/scratch/chronobridge/phaseA/scripts/load_trajectory.py --check` prints frame count > 0 and confirms order labels are monotonic 0..N-1.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseA/scripts/load_trajectory.py`

## Task 5: define the FP-injection method (resolves contract open question)

- **Status**: done
- **Prereq tasks**: 4
- **Files touched**: `.agent/scratch/chronobridge/phaseA/data_source_notes.md` (append
  `## FP injection method` section)
- **Change shape**: Pick and document ONE concrete FP-injection definition (e.g. rigid-body
  perturbed decoy frames, frames spliced in from an unrelated trajectory, or locally
  energy-implausible synthetic frames) with a one-line rationale for why it's a fair FP proxy
  and how it's distinguishable from a real frame for scoring purposes only (never exposed to
  the method under test).
- **Verification**: `grep -q '## FP injection method' .agent/scratch/chronobridge/phaseA/data_source_notes.md`
- **Estimated time**: 3 min
- **Rollback (if this task only)**: revert the appended section (git diff / manual edit)

## Task 6: shuffle + FP-injection script

- **Status**: done
- **Prereq tasks**: 4, 5
- **Files touched**: `.agent/scratch/chronobridge/phaseA/scripts/shuffle_inject.py`
- **Change shape**: Takes the Task 4 loader output, randomly shuffles frame order, injects
  10-30% FP frames per the Task 5 definition, and emits a corrupted dataset plus a
  held-out-from-the-method ground-truth label file (true order + real/FP flag per frame).
- **Verification**: `python .agent/scripts/chronobridge/phaseA/scripts/shuffle_inject.py --check`
  (adjust path) prints FP fraction in [0.10, 0.30] and confirms label file row count matches
  frame count.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseA/scripts/shuffle_inject.py`

## Task 7: ChronoBridge order-recovery, first implementation

- **Status**: done
- **Prereq tasks**: 6
- **Files touched**: `.agent/scratch/chronobridge/phaseA/scripts/chronobridge.py`
- **Change shape**: First-pass implementation of the state-order/kinetics recovery method
  (new, standalone — does not import aigen-fold-core code per contract Non-Goals). Consumes
  the shuffled+FP-injected dataset from Task 6, outputs a predicted order (and confidence/
  kinetics scores) per frame, blind to the ground-truth labels.
- **Verification**: `python .agent/scripts/chronobridge/phaseA/scripts/chronobridge.py --smoke`
  (adjust path) runs to completion on the Task 6 output and writes a predictions file with one
  row per input frame.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseA/scripts/chronobridge.py`

## Task 8: FP detector, first implementation

- **Status**: done
- **Prereq tasks**: 6
- **Files touched**: `.agent/scratch/chronobridge/phaseA/scripts/fp_detector.py`
- **Change shape**: First-pass FP detector, standalone (no aigen-fold-core reuse). Consumes the
  Task 6 shuffled+injected dataset, outputs a per-frame FP-likelihood score, blind to the
  ground-truth real/FP flag.
- **Verification**: `python .agent/scripts/chronobridge/phaseA/scripts/fp_detector.py --smoke`
  (adjust path) runs to completion and writes one FP-score row per input frame.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseA/scripts/fp_detector.py`

## Task 9: unified inference pipeline

- **Status**: done
- **Prereq tasks**: 7, 8
- **Files touched**: `.agent/scratch/chronobridge/phaseA/scripts/run_pipeline.py`
- **Change shape**: Wires Task 7 (order recovery) + Task 8 (FP detector) into one entry point
  that takes the Task 6 dataset and emits a single combined predictions file (order + FP score
  per frame) ready for scoring.
- **Verification**: `python .agent/scripts/chronobridge/phaseA/scripts/run_pipeline.py` (adjust
  path) produces `predictions.csv` with columns for predicted order and FP score, row count
  matching the input frame count.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseA/scripts/run_pipeline.py`

## Task 10: random/baseline comparator

- **Status**: done
- **Prereq tasks**: 6
- **Files touched**: `.agent/scratch/chronobridge/phaseA/scripts/baseline.py`
- **Change shape**: Produces a random-order + random-FP-score prediction (same output shape as
  Task 9) as the comparison baseline required by the contract's PASS criterion.
- **Verification**: `python .agent/scripts/chronobridge/phaseA/scripts/baseline.py` (adjust
  path) produces a `baseline_predictions.csv` with the same schema as Task 9's output.
- **Estimated time**: 2 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseA/scripts/baseline.py`

## Task 11: evaluation metrics + bootstrap CI

- **Status**: done
- **Prereq tasks**: 9, 10
- **Files touched**: `.agent/scratch/chronobridge/phaseA/scripts/evaluate.py`
- **Change shape**: Computes FP removal rate, Kendall τ, transition edge recall,
  false-shortcut rate, committor calibration, and MFPT rank for both Task 9 (method) and
  Task 10 (baseline) predictions against the Task 6 ground-truth labels, with paired
  bootstrap CIs on the method-vs-baseline delta for each metric.
- **Verification**: `python .agent/scripts/chronobridge/phaseA/scripts/evaluate.py` (adjust
  path) prints a comparison table with a CI column for every metric, no bare point estimates.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseA/scripts/evaluate.py`

## Task 12: run end-to-end and record verdict

- **Status**: done (verdict: PASS — see eval_output.json, committed in task 11's commit c201ee57;
  all 7 metrics show bootstrap CI on method-vs-baseline delta excluding zero, comfortably
  clearing the contract's 1-of-2-core-metric bar. Independently re-verified by the coordinator
  during task 11's code review, not just the delegated agent's own claim.)
- **Prereq tasks**: 11
- **Files touched**: `.agent/scratch/chronobridge/phaseA/eval_output.json` (or `.csv`)
- **Change shape**: Executes Task 11 end-to-end on the full Task 6 dataset, saves the raw
  metric+CI output. Determine PASS/FAIL per the contract's Done-When bar: at least one core
  metric (FP removal rate or Kendall τ) has a bootstrap CI on the method-vs-baseline delta that
  excludes zero.
  Verification: `python -c "import json; d=json.load(open('.agent/scratch/chronobridge/phaseA/eval_output.json')); assert 'fp_removal_rate' in d and 'kendall_tau' in d"` (adjust
  filename/keys to actual script output) confirms the required metrics are present with CI
  bounds.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseA/eval_output.json`

## Task 13: adversarial verification (only if Task 12 shows a positive result)

- **Status**: done (VERDICT: CONFIRMED — re-seed reproduction + null-calibration checks both
  survived; see adversarial_check.md)
- **Prereq tasks**: 12
- **Files touched**: `.agent/scratch/chronobridge/phaseA/adversarial_check.md`
- **Change shape**: Conditional task. If Task 12's verdict is PASS, run at least 2 independent
  checks (re-seed reproduction, permutation null, and/or a second trajectory/subset if
  available) before calling the result "real," per this repo's convention (see
  `aigen-fold-core-3body-mgoff-features-20260707` contract precedent). If Task 12's verdict is
  FAIL, skip this task and note so in the doc.
- **Verification**: `test -f .agent/scratch/chronobridge/phaseA/adversarial_check.md` and the
  file states a clear survive/fail-to-survive verdict for each independent check run.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseA/adversarial_check.md`

## Task 14: results document

- **Status**: done
- **Prereq tasks**: 12
- **Files touched**: `.agent/scratch/chronobridge/phaseA/results.md`
- **Change shape**: Final write-up: dataset used, FP-injection method, metrics table with CIs,
  PASS/FAIL verdict against the contract's Done-When bar, adversarial-verification outcome (if
  Task 13 ran), and an explicit recommendation on whether to proceed to Phase B (GSPT1) or stop
  and revise the method.
- **Verification**: `grep -qE '^(PASS|FAIL)' .agent/scratch/chronobridge/phaseA/results.md`
  (verdict stated unambiguously near the top of the doc)
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseA/results.md`

## Task 15: create the chronobridge slice status file

- **Status**: done
- **Prereq tasks**: 14
- **Files touched**: `.agent/status/chronobridge.md`
- **Change shape**: First-ever status baton for this new slice, following the schema in
  `.agent/status/README.md` (frontmatter: owner_session/owner_agent/version/last_updated/
  heartbeat/state/remaining_actions/contract_pointers). `remaining_actions` states the Phase A
  verdict and, per Task 14's recommendation, either `AGENT: scope Phase B (GSPT1) contract` or
  `DECISION: Phase A did not clear the bar, user input needed on next step`.
- **Verification**: `test -f .agent/status/chronobridge.md && grep -q 'contract_pointers' .agent/status/chronobridge.md`
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `rm .agent/status/chronobridge.md`

## Task 16: handoff + regenerate index + close contract

- **Status**: done
- **Prereq tasks**: 15
- **Files touched**: `.agent/status/chronobridge.md` (frontmatter bump via script),
  `.agent/handoffs/state/` (snapshot via script), `.agent/handoffs/CURRENT.md` (regenerated,
  not hand-edited), `.agent/contracts/chronobridge-apo-holo-benchmark-20260713.md`
  (`status: done`, Progress Log entry)
- **Change shape**: Run `./scripts/handoff.sh claude chronobridge`, then
  `./scripts/status.sh index`. Flip the contract's frontmatter `status` to `done` (or
  `abandoned` if Task 12/14 verdict was FAIL and no further action is planned) and append a
  final Progress Log line summarizing the outcome.
- **Verification**: `./scripts/handoff.sh claude chronobridge && ./scripts/status.sh index` exit
  0; `grep -q 'status: done' .agent/contracts/chronobridge-apo-holo-benchmark-20260713.md` (or
  `abandoned`).
- **Estimated time**: 2 min
- **Rollback (if this task only)**: `./scripts/handoff.sh --release chronobridge` is NOT
  appropriate here since this is closing, not abandoning ownership — if this task alone needs
  reverting, manually revert the contract frontmatter edit and re-run
  `./scripts/status.sh index`.
