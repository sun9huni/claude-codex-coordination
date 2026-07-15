---
contract: .agent/contracts/harness-experiment-autopilot-20260604.md
slice: harness
status: done
total_tasks: 5
estimated_total_min: 28
---

# Plan: FEA Phase 2d (fksfold-core) — CRBN-anchor seq-walk preflight

Generalizes FEA Stage-1 preflight to **fksfold-core CRBN anchors**: does the
submitted `--w400_residue_index` (a 1-based position into the construct's CRBN
chain) actually map to a tryptophan (**W**)? This catches the production-anchor
bug (`w400_residue_index=355` → G/L/P/S, not W, on all 4 held-out targets) and
the author-vs-sequence off-by-one — the **third** of the umbrella's "3 known-bad
configs" (FragMap-mode = 2a, coupling = 2c, **CRBN-anchor = this**).

**Recon facts (verified):**
- Reusable: `analysis/heldout_placement_20260601/verify_heldout_anchor.py` has
  `modeled(cif, ch) -> [(author_resi, one_letter), …]` (Bio.PDB MMCIFParser,
  standard+MSE). Author offset: Q96SW2 author = VAV1_pos + 45. Importing the
  module pulls Bio.PDB + `_parse_heldout` → import it **lazily** inside the CIF
  adapter so FEA's other modules don't require Bio.PDB.
- `--w400_residue_index` (src/boltz/main.py, default 355) is a **1-based position
  into the construct CRBN chain**. The SLURM Stage-B script overrides per target
  (9NYR 356, 9NGT 321, 9NFQ 331, 9OS2 345 — each maps to a real W).
- Fixtures exist: `examples/heldout/{9NYR,9NGT,9NFQ,9OS2}.cif` (CRBN = chain B).
  Bad: index 355 → not W (9NGT len 355 → out of range). Good: per-target index → W.
  Recipe table: `analysis/heldout_placement_20260601/STAGEB_RECIPE.md` (4/4 PASS).
- **Out of scope this phase** (deferred): the GPU-UUID submit-script check
  (`--gpus=device=0` collision) — a later small text-pattern addition.

---

## Task 1: Red test — verify_anchor_residues (pure logic, synthetic)

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `scripts/fea/tests/test_fksfold_preflight.py`
- **Change shape**: Test imports `scripts.fea.fksfold_preflight.verify_anchor_residues`
  (PURE logic, no Bio.PDB). Signature:
  `verify_anchor_residues(residues, w400_idx, expected="W") -> list[Issue]` where
  `residues` is a list of `(author_resi, one_letter)` (1-based by position). Cases:
  - residue at 1-based `w400_idx` is "W" → no error.
  - residue at `w400_idx` is "G" → error code `anchor_not_tryptophan` naming the
    found letter + position.
  - `w400_idx` out of range (> len) → error code `anchor_out_of_range`.
  Build small synthetic residue lists in the test. FAILS now (module absent).
- **Verification**: `pytest scripts/fea/tests/test_fksfold_preflight.py` → fails on import.
- **Estimated time**: 5 min
- **Rollback**: `rm -f scripts/fea/tests/test_fksfold_preflight.py`

## Task 2: Green — fksfold_preflight.py (pure check + CIF adapter)

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**: `scripts/fea/fksfold_preflight.py`
- **Change shape**: Reuse `Issue`/`PreflightReport` from `scripts.fea.preflight`.
  Implement:
  - `verify_anchor_residues(residues, w400_idx, expected="W") -> list[Issue]`:
    range-check then residue-letter check (1-based). Codes `anchor_out_of_range`,
    `anchor_not_tryptophan` (error severity).
  - `run_anchor_preflight(cif_path, chain, w400_idx, expected="W") -> PreflightReport`:
    **lazily** import `modeled` from the held-out tooling (add
    `analysis/heldout_placement_20260601` to sys.path inside the function, like
    postflight's activity_eval_gates idiom), call `modeled(cif_path, chain)`, pass
    the residue list to `verify_anchor_residues`, return a PreflightReport. If
    Bio.PDB / the tooling is unavailable, return a single `warn`
    `anchor_check_unavailable` (never hard-crash).
- **Verification**: `pytest scripts/fea/tests/test_fksfold_preflight.py` passes
  (pure-logic tests green).
- **Estimated time**: 6 min
- **Rollback**: `git checkout scripts/fea/fksfold_preflight.py`

## Task 3: Integration test on real held-out CIFs

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `scripts/fea/tests/test_fksfold_preflight.py` (add)
- **Change shape**: Add an integration test using `pytest.importorskip("Bio")`
  and skipping if the CIFs are absent. Assert
  `run_anchor_preflight(examples/heldout/9NGT.cif, "B", 355)` is NOT ok
  (`anchor_not_tryptophan` or `anchor_out_of_range`), and
  `run_anchor_preflight(.../9NGT.cif, "B", 321)` is `.ok` (maps to W) — matching
  STAGEB_RECIPE. Resolve CIF paths from the FKSFold repo; skip cleanly if missing.
- **Verification**: `pytest scripts/fea/tests/test_fksfold_preflight.py -q` passes
  (integration test runs or skips, never fails spuriously).
- **Estimated time**: 5 min
- **Rollback**: `git checkout scripts/fea/tests/test_fksfold_preflight.py`

## Task 4: Wire `fea preflight-fksfold` CLI subcommand

- **Status**: done
- **Prereq tasks**: 3
- **Files touched**: `scripts/fea/__main__.py`
- **Change shape**: Add `preflight-fksfold` subcommand: args `--cif` (required),
  `--chain` (default "B"), `--w400-index` (required, int), `--expected` (default
  "W"), `--strict`. Handler calls `run_anchor_preflight`, prints the same ✗/⚠/✓
  report format, exit 1 on error (or any issue under `--strict`). Import
  `fksfold_preflight` alongside existing imports.
- **Verification**:
  `python -m scripts.fea preflight-fksfold --cif <repo>/examples/heldout/9NGT.cif --w400-index 355`
  → ✗ error, exit 1; `--w400-index 321` → ✓ clean, exit 0. `--help` works.
- **Estimated time**: 5 min
- **Rollback**: `git checkout scripts/fea/__main__.py`

## Task 5: Finalize — baton + plan/contract + README

- **Status**: done
- **Prereq tasks**: 4
- **Files touched**: `.agent/status/harness.md`, `scripts/fea/README.md`, this plan,
  the contract Progress Log
- **Change shape**: Record Phase 2d shipped (harness baton + contract Progress Log
  + README — note this **completes the umbrella's "3 known-bad" criterion**); set
  this plan `status: done`. Note remaining: Stage 2 watch; GPU-UUID submit-script
  check; mmgbsa post-hoc run-dir audit.
- **Verification**: `python -m pytest scripts/fea/tests/ -q` all pass;
  `python -m scripts.fea preflight-fksfold --help` works; `./scripts/status.sh index` clean.
- **Estimated time**: 4 min
- **Rollback**: `git checkout .agent/status/harness.md scripts/fea/README.md`
