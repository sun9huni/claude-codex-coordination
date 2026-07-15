---
contract: .agent/contracts/harness-experiment-autopilot-20260604.md
slice: harness
status: done
total_tasks: 8
estimated_total_min: 38
---

# Plan: FEA Phase 2a — fragmap preflight validator + warn-only gate advisory

Decomposes the **Stage 1 (preflight)** portion of the umbrella contract, scoped
to **fragmap only**. CRBN-anchor preflight (fksfold-core) and MD↔sampling coupling
preflight (mmgbsa) are deferred to the per-slice generalization plans, since their
known-bad configs live in those slices. This plan ships the *before-GPU*
waste-prevention for the slice that bled the most (wrong FragMap mode, commit
`37787a2`).

**Design facts from recon (real, verified):**
- Production mode is `cluster_then_grid`; valid modes also include `grid`,
  `target_occupancy`. **Forbidden: `feature`, `atom`, `feature_probability`**
  (source of truth: `src/boltz_extension/steering/fragmap_steering.py` ~L345-430).
  Preflight encodes these as local constants (citing that file) — it does NOT
  import the heavy boltz extension.
- Real configs (copy minimal versions into fixtures):
  - good: `configs/vav1_pipeline/fragmap_conditioning_example.yaml` (`mode: cluster_then_grid`)
  - bad:  `configs/vav1_pipeline/fragmap_conditioning_feature_c5.yaml` (`mode: feature`)
  - bad:  `configs/vav1_pipeline/fragmap_conditioning_feature_c6_mrt6160.yaml`
- Config schema (under top-level `fragmap_conditioning`): `mode`, `fragmap_npz`,
  `reference_pdb`, `channels` (non-empty list), plus chain/offset keys.
- NPZ maps exist at `/mnt/data/users/kim/code/.../silcs_oracle_real/ternary_{r1,r2}_maps.npz`.
- Canonical VAV1 pocket GT (1-based seq): **{16,17,18,19,20}** (hardcoded as
  `--w400_vav1_residues 16,17,18,19,20` across submit scripts; input-YAML
  `constraints[].pocket.contacts` chain B). CRBN W400 → seq index 355 (noted;
  strict CRBN-anchor check deferred to the fksfold generalization).
- The active gate hook is `.claude/hooks/pre-bash-slurm-gate.sh` (currently only a
  contract-existence check). fragmap configs reach the run via `--fragmap_config`
  *inside* docker, so the hook can only **best-effort** grep the sbatch command
  line — documented as a known limitation (no silent cap).

---

## Task 1: Red test — preflight validator on real fixture configs

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `scripts/fea/tests/test_preflight.py`, `scripts/fea/tests/fixtures/preflight/` (good + bad config copies)
- **Change shape**: Copy minimal versions of the three real configs into
  `fixtures/preflight/` (good_cluster_then_grid.yaml; bad_feature_mode.yaml;
  bad_missing_npz.yaml = good config but with `fragmap_npz` pointing at a
  nonexistent path). Test imports `scripts.fea.preflight.run_preflight` and asserts:
  good → no error-severity issues; bad_feature_mode → an error citing the forbidden
  `mode: feature`; bad_missing_npz → an error citing the missing NPZ. FAILS now
  (module absent).
- **Verification**: `pytest scripts/fea/tests/test_preflight.py` → fails on missing
  `scripts.fea.preflight`.
- **Estimated time**: 5 min
- **Rollback**: `rm -rf scripts/fea/tests/fixtures/preflight scripts/fea/tests/test_preflight.py`

## Task 2: Green — preflight.py core checks (mode, paths, channels)

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**: `scripts/fea/preflight.py`
- **Change shape**: Implement `run_preflight(config_path, input_yaml=None) -> PreflightReport`.
  `PreflightReport` = dataclass holding a list of `Issue(severity, code, message)`
  (severity ∈ {"error","warn"}) + an `ok` property (no error-severity). Checks:
  (a) `fragmap_conditioning.mode` not in `FORBIDDEN_MODES={"feature","atom","feature_probability"}`
  → error; not in `VALID_MODES` → warn; (b) `fragmap_npz` & `reference_pdb` exist
  → error if missing; (c) `channels` non-empty → error if empty. Constants carry a
  comment citing `fragmap_steering.py` as source of truth.
- **Verification**: `pytest scripts/fea/tests/test_preflight.py` passes (good ok;
  both bad flagged with the right codes).
- **Estimated time**: 5 min
- **Rollback**: `git checkout scripts/fea/preflight.py`

## Task 3: Red test — pocket-residue audit vs ground truth

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `scripts/fea/tests/test_preflight.py` (add), `scripts/fea/tests/fixtures/preflight/` (input-yaml fixtures)
- **Change shape**: Add fixtures: input_pocket_ok.yaml (`constraints[].pocket.contacts`
  chain B = {16..20}) and input_pocket_bad.yaml (e.g. {14..19}, the historical
  off-by-one). Add a test asserting `run_preflight(good_config, input_yaml=ok)` has
  no pocket issue, and `input_yaml=bad` raises a `warn`/`error` issue with code
  `pocket_residue_mismatch` naming the off residues. FAILS now (audit absent).
- **Verification**: `pytest scripts/fea/tests/test_preflight.py -k pocket` → fails.
- **Estimated time**: 4 min
- **Rollback**: `git checkout scripts/fea/tests/test_preflight.py`

## Task 4: Green — pocket-residue audit check

- **Status**: done
- **Prereq tasks**: 3
- **Files touched**: `scripts/fea/preflight.py`
- **Change shape**: Add `_audit_pocket(input_yaml) -> list[Issue]`: parse
  `constraints[].pocket.contacts`, collect chain-B (VAV1) residue indices, compare
  to canonical `VAV1_POCKET_GT={16,17,18,19,20}`. If the set differs beyond a
  ±1-neighbor tolerance, emit `pocket_residue_mismatch` (severity warn — advisory,
  per warn-first). Wire into `run_preflight` when `input_yaml` is provided.
- **Verification**: `pytest scripts/fea/tests/test_preflight.py -k pocket` passes.
- **Estimated time**: 5 min
- **Rollback**: `git checkout scripts/fea/preflight.py`

## Task 5: Wire `fea preflight` CLI subcommand

- **Status**: done
- **Prereq tasks**: 4
- **Files touched**: `scripts/fea/__main__.py`
- **Change shape**: Add `preflight <config> [--input-yaml X] [--strict]` →
  `run_preflight` → print a human report (one line per issue, ✗ error / ⚠ warn).
  Exit 1 if any error-severity issue (so it is usable as a hard check); `--strict`
  makes warns also count as failures. Default (no flag) = errors fail, warns print.
- **Verification**: `python -m scripts.fea preflight <fixtures>/preflight/bad_feature_mode.yaml`
  prints the forbidden-mode error and exits 1; `…/good_cluster_then_grid.yaml` exits 0.
- **Estimated time**: 4 min
- **Rollback**: `git checkout scripts/fea/__main__.py`

## Task 6: Warn-only advisory in the sbatch gate hook

- **Status**: done
- **Prereq tasks**: 5
- **Files touched**: `.claude/hooks/pre-bash-slurm-gate.sh`
- **Change shape**: After the existing contract check decides the exit code, add a
  **best-effort, never-blocking** block: if the detected command contains a
  `--fragmap_config <path>` token OR a `*fragmap*.yaml` path that exists, run
  `python -m scripts.fea preflight <path>` and echo its report to stderr prefixed
  `[fea-preflight]`. The hook's exit code is unchanged (still 0/2 from the contract
  rule only). If no config token is found (the docker-wrapped common case), stay
  silent. Add a comment documenting this best-effort limitation explicitly.
- **Verification**: feeding the hook an sbatch command that names a known-bad config
  prints a `[fea-preflight]` warning AND the contract-based exit code is unchanged
  (verified in Task 7).
- **Estimated time**: 6 min
- **Rollback**: `git checkout .claude/hooks/pre-bash-slurm-gate.sh`

## Task 7: Hook regression test (advisory never changes the gate verdict)

- **Status**: done
- **Prereq tasks**: 6
- **Files touched**: `scripts/fea/tests/test_slurm_gate_advisory.sh`
- **Change shape**: Bash test that pipes a synthetic hook input (JSON with an
  `sbatch run.sh --fragmap_config <bad_fixture>`) into the hook and asserts:
  (a) with a recent contract present → exit 0 AND stderr contains `[fea-preflight]`
  with the forbidden-mode warning; (b) the pre-existing contract-gate behavior
  (block when no recent contract) is unchanged — confirm the advisory never flips a
  pass to a block or vice-versa.
- **Verification**: `bash scripts/fea/tests/test_slurm_gate_advisory.sh` → all
  assertions PASS.
- **Estimated time**: 5 min
- **Rollback**: `rm -f scripts/fea/tests/test_slurm_gate_advisory.sh`

## Task 8: Finalize — baton + plan/contract status

- **Status**: done
- **Prereq tasks**: 7
- **Files touched**: `.agent/status/harness.md`, this plan, the contract Progress Log
- **Change shape**: Record Phase 2a shipped in the harness baton (hand-written) and
  the contract Progress Log; set this plan `status: done`. Note remaining Phase-2
  work (Stage 2 watch; mmgbsa/fksfold generalization incl. CRBN-anchor + coupling
  preflight).
- **Verification**: `python -m pytest scripts/fea/tests/ -q` all pass;
  `python -m scripts.fea preflight --help` works; `./scripts/status.sh index` clean.
- **Estimated time**: 4 min
- **Rollback**: `git checkout .agent/status/harness.md`
