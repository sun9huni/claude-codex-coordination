---
contract: .agent/contracts/harness-experiment-autopilot-20260604.md
slice: harness
status: done
total_tasks: 12
estimated_total_min: 50
---

# Plan: FEA Phase 1 — Stage 3+4 (postflight + capture) on fragmap

Decomposes **Phase 1 only** of the approved contract. Stages 1 (preflight) and 2
(watch), and the mmgbsa/fksfold generalization, are deferred to later plans.

**Key fact from interface mapping (revised — see Amendment 1):** fragmap has no
`baseline<0.23` regime (that was fksfold-core). The fragmap "don't pool" analog is
**Murcko-scaffold-blocked grouping**, implemented in
`analysis/foundation/activity_eval_gates.py` (`grouped_oof_predict` +
1000× `permutation_null`). The reproduction oracle for the success criterion is the
**documented induced-fit-inverted KILL**: pooled Spearman(offset, logDC50) = −0.305
(looks promising) but scaffold-blocked OOF ρ = −0.117, permutation p = 0.694 → KILL.
That pooled-vs-blocked contrast *is* the executable "pooled-median forbidden" lesson.
(`dc50_overfit_scan` is a *pooled* 36-test correlation scan — itself the anti-pattern
— so it is at most a secondary sanity check, not the regime-stratified oracle.)

## Amendment 1 (2026-06-04, during /execute-plan recon)

Pre-code recon revealed the original oracle was methodologically wrong:
`dc50_overfit_scan.py` is a pooled Spearman/Pearson family with BH-FDR, using no
scaffolds and not `regression_gate` — it cannot be reproduced by a scaffold-blocked
gate, and it is the pooled anti-pattern the contract forbids. Tasks 5, 6, 8 and the
header are revised to reproduce the **induced-fit-inverted scaffold-blocked KILL**
(`fragmap-induced-fit-inverted-signal-20260601`, report
`analysis/induced_fit_inverted_signal_20260601/RESULTS.md`) via
`grouped_oof_predict` + `permutation_null` with Murcko scaffolds derived from SMILES
(`…/reports/ligand_position_features.csv`). Tasks 1–4, 7, 9–12 unchanged.

**Confirmed real inputs:** `ab_139batch_eval.csv` (offset),
`norm143_corrected_sources.tsv` (`dc50_nM`), `ligand_position_features.csv` (SMILES),
all under `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/`.

## Amendment 2 (2026-06-04, during /execute-plan, before Task 9)

The live `.agent/status/fragmap.md` frontmatter does NOT `yaml.safe_load` (multi-line
`remaining_actions` items break strict YAML); `scripts/notion_sync.py` reads it via
`_parse_frontmatter` with a `_regex_extract_frontmatter` fallback. So `draft_baton`
must read/validate via the house parser, NOT naive `yaml.safe_load`, and Task 9/10
verification is corrected to use it. Task *intent* (draft a valid baton, bump
version, leave the live file untouched) is unchanged — this is a verification-method
fix only. The draft is produced by **targeted line edits** (bump `version`/
`last_updated`/`heartbeat`, prepend one well-formed `remaining_actions` item),
preserving the rest of the frontmatter verbatim so it stays exactly as house-parseable
as the original.

**Reusable assets (verified, do not rewrite):**
- `FKSFold-Boltz_Advancement/analysis/foundation/activity_eval_gates.py` —
  `regression_gate(X, y, groups, desc, effort_floor)` → `{..., verdict:{PROVE}}`;
  `permutation_null`, `grouped_oof_predict`, `within_between_scaffold`.
- `FKSFold-Boltz_Advancement/analysis/fragmap_spectral_discriminator/src/eval_ab_139batch.py`
  — CLI `--ab-dir --baseline-csv --out-csv --paired-csv`; per-cell metric CSV.
- `FKSFold-Boltz_Advancement/analysis/fragmap_spectral_discriminator/src/dc50_overfit_scan.py`
  — the documented 36-test BH-FDR KILL (reproduction oracle).
- `scripts/notion_sync.py` — `read_slice(name)`, frontmatter parser (payload only,
  no MCP write).
- `.agent/status/fragmap.md` — baton schema (frontmatter + body).
- Real completed job for validation: a `vav1_ab_139batch_*` outputs dir under
  `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/outputs/`
  (confirm exact path with `ls` at execute time; layout
  `VAV1_*/boltz_results_*/predictions/*/*_model_0.pdb` + `confidence_*.json`).

---

## Task 1: Create scripts/fea/ package skeleton

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `scripts/fea/__init__.py`, `scripts/fea/__main__.py`, `scripts/fea/README.md`
- **Change shape**: New package. `__init__.py` exports module names. `__main__.py`
  has an argparse with subcommands `report` and `capture` that currently just
  `print` a not-implemented notice and exit 0. README states scope = Phase 1
  (Stage 3+4, fragmap) and links the contract.
- **Verification**: `python -m scripts.fea report --help` exits 0 and lists the
  `report`/`capture` subcommands.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `rm -rf scripts/fea`

## Task 2: Red test — per-cell failure classification on a fixture tree

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**: `scripts/fea/tests/test_failure_classify.py`, `scripts/fea/tests/fixtures/` (tiny synthetic job tree)
- **Change shape**: Build a minimal fixture job dir with 4 cells: one valid
  (non-empty `*_model_0.pdb`), one silent-fail (predictions/ exists, PDB missing),
  one OOM (log contains "ran out of memory"), one node-fault (log contains
  `early_nvt_hang`). Test imports `scripts.fea.postflight.classify_cells` and
  asserts the 4-way manifest counts. Test FAILS now (function absent).
- **Verification**: `pytest scripts/fea/tests/test_failure_classify.py` → fails
  with ImportError/AttributeError on `classify_cells`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm -rf scripts/fea/tests`

## Task 3: Green — cell enumeration + failure classification

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `scripts/fea/postflight.py`
- **Change shape**: Implement `classify_cells(job_dir) -> dict` — glob `VAV1_*`
  cells, for each detect: success (`*_model_0.pdb` exists, size>0), silent_fail
  (no/empty PDB), oom / node_fault (log signature match), else unknown. Return a
  failure manifest (per-cell status + counts).
- **Verification**: `pytest scripts/fea/tests/test_failure_classify.py` passes;
  AND `python -m scripts.fea.postflight --classify-only <real_ab_job_dir>` prints
  a manifest whose silent_fail count matches the documented job-5638 figure
  (~20 of ~139) — confirm against the real dir at execute time.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/fea/postflight.py`

## Task 4: Ingest per-cell metrics via eval_ab_139batch

- **Status**: done
- **Prereq tasks**: 3
- **Files touched**: `scripts/fea/postflight.py`
- **Change shape**: Add `load_metrics(job_dir, baseline_csv) -> DataFrame` that
  invokes the existing `eval_ab_139batch.py` CLI (subprocess) on the job's
  `--ab-dir` + `--baseline-csv`, then reads the produced `--out-csv` into pandas.
  Skip cells flagged silent_fail in Task 3's manifest. No metric math
  re-implemented here.
- **Verification**: `python -m scripts.fea.postflight --metrics-only <real_ab_job_dir> --baseline-csv <norm143_baseline.csv>`
  prints a DataFrame head with columns `vav1_rigid_body_offset, f1_4A, iptm`
  and row count == #valid cells from the manifest.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/fea/postflight.py`

## Task 5: Red test — scaffold-blocked gate reproduces induced-fit-inverted KILL

- **Status**: done
- **Prereq tasks**: 4
- **Files touched**: `scripts/fea/tests/test_gate_reproduction.py`
- **Change shape**: Test imports `scripts.fea.postflight.run_gates` and asserts, on
  the frozen induced-fit inputs (offset from `ab_139batch_eval.csv`, `dc50_nM` from
  `norm143_corrected_sources.tsv`, Murcko scaffolds from SMILES in
  `ligand_position_features.csv`; full cohort n≈84), that: (a) the raw pooled
  Spearman(offset, logDC50) ≈ −0.305 (±0.03) — i.e. pooled *looks* promising;
  (b) the scaffold-blocked OOF ρ ≈ −0.117 (±0.05) with permutation p > 0.5;
  (c) the returned verdict is **KILL**; and (d) `run_gates` requires a non-None
  `groups` arg (calling without scaffolds raises — no pooled-only path). Test FAILS
  now (function absent).
- **Verification**: `pytest scripts/fea/tests/test_gate_reproduction.py` → fails
  on missing `run_gates`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/fea/tests/test_gate_reproduction.py`

## Task 6: Green — scaffold-blocked gate (grouped OOF + permutation null, no pooled path)

- **Status**: done
- **Review note**: `run_gates` PROVE enforces only leg-(i) permutation significance,
  not the source contract's full 3-leg PROVE (perm + MW-partial + descriptors-only).
  Correct for the KILL reproduction; tighten when generalizing the gate.
- **Prereq tasks**: 5
- **Files touched**: `scripts/fea/postflight.py`
- **Change shape**: Implement `run_gates(metric, y, groups, ...)` that derives the
  raw pooled Spearman (reported only as the "would-mislead" contrast), then the
  scaffold-blocked verdict via `activity_eval_gates.grouped_oof_predict` +
  `permutation_null` (frozen library, `DEFAULT_SEED`), returning
  `{raw_rho, oof_rho, perm_p, verdict}`. `groups` is a **required** positional arg;
  there is no pooled-only code path (passing `groups=None` raises). KILL when the
  scaffold-blocked OOF fails to beat the permutation band (p≥0.05). Murcko-scaffold
  derivation from SMILES via rdkit, mirroring the induced-fit analysis.
- **Verification**: `pytest scripts/fea/tests/test_gate_reproduction.py` passes
  (reproduces oof_rho≈−0.117, perm_p>0.5, verdict KILL).  **← primary contract
  success criterion.**
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/fea/postflight.py`

## Task 7: Results Card schema + serializer

- **Status**: done
- **Prereq tasks**: 6
- **Files touched**: `scripts/fea/results_card.py`
- **Change shape**: Define `ResultsCard` (verdict, per-regime gate rows, failure
  manifest, job_dir, generated-from provenance) and `write_card(card, out_path)`
  that serializes to a markdown+frontmatter file under `.agent/scratch/fea/`.
  No network, no in-place baton edit.
- **Verification**: `python -c "from scripts.fea.results_card import ResultsCard, write_card; ..."`
  writes a card file that contains the verdict, survivor count, and manifest counts.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout scripts/fea/results_card.py; rm -rf .agent/scratch/fea`

## Task 8: Wire `fea report` end-to-end

- **Status**: done
- **Prereq tasks**: 7
- **Files touched**: `scripts/fea/__main__.py`
- **Change shape**: `report <job_dir> --baseline-csv ... --y-csv dc50.tsv
  --smiles-csv ligand_position_features.csv` → classify_cells → load_metrics →
  run_gates (scaffold-blocked, joining dc50 + SMILES-derived scaffolds by compound)
  → write_card; print the card path and a 5-line summary. Read-only except for the
  scratch card file.
- **Verification**: running `report` over the induced-fit inputs emits a card whose
  verdict is **KILL** with oof_rho≈−0.117 / perm_p>0.5, matching
  `analysis/induced_fit_inverted_signal_20260601/RESULTS.md` by hand-check.
  **← contract "fea report reproduces past verdict" criterion.**
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout scripts/fea/__main__.py`

## Task 9: capture.py — draft fragmap status baton (gated, not in-place)

- **Status**: done
- **Prereq tasks**: 8
- **Files touched**: `scripts/fea/capture.py`
- **Change shape**: `draft_baton(card, baton_path=None) -> str` (default
  `.agent/status/<card.slice_name>.md`) reads the current `version` via the house
  parser `scripts.notion_sync._parse_frontmatter` (regex-fallback safe), then by
  **targeted line edits** bumps `version`, sets `last_updated`/`heartbeat`, and
  prepends a `remaining_actions` entry summarizing the verdict with the correct
  `DECISION:`/`AGENT:`/`BLOCKED:` prefix — preserving the rest verbatim. Returns the
  full proposed file and writes `<baton_path>.fea-draft` — never overwrites the live
  baton.
- **Verification**: produces `fragmap.md.fea-draft`; `_parse_frontmatter` on the
  draft succeeds and its `version` == live+1; the live baton is byte-identical.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/fea/capture.py; rm -f .agent/status/fragmap.md.fea-draft`

## Task 10: Assert test — drafted baton valid + verdict-bearing

- **Status**: done
- **Prereq tasks**: 9
- **Files touched**: `scripts/fea/tests/test_capture_baton.py`
- **Change shape**: Test feeds a synthetic ResultsCard + a small **fixture baton**
  (valid-YAML, under tests/fixtures/) to `draft_baton`, asserts: the draft parses via
  `scripts.notion_sync._parse_frontmatter`, `version` incremented, the new top
  `remaining_actions` entry carries a DECISION:/AGENT:/BLOCKED: prefix and the verdict
  word, and the fixture baton file is byte-for-byte unchanged.
- **Verification**: `pytest scripts/fea/tests/test_capture_baton.py` passes.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm -f scripts/fea/tests/test_capture_baton.py`

## Task 11: capture.py — draft notion payload via read_slice

- **Status**: done
- **Prereq tasks**: 9
- **Files touched**: `scripts/fea/capture.py`
- **Change shape**: `draft_notion_payload(card)` runs the drafted baton through
  `notion_sync.read_slice("fragmap")` (or its parser on the draft) to emit the
  Slices/Experiments JSON payload, printed/saved to `.agent/scratch/fea/`. Zero
  Notion API calls — payload only.
- **Verification**: emits JSON containing the verdict and slice="fragmap"; grep
  confirms no `notion-` MCP invocation in the module.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout scripts/fea/capture.py`

## Task 12: Wire `fea capture` (gated drafts only) + status update

- **Status**: done
- **Prereq tasks**: 10, 11
- **Files touched**: `scripts/fea/__main__.py`, `.agent/status/harness.md`
- **Change shape**: `capture <card>` → draft_baton + draft_notion_payload; print
  both draft paths and an explicit "review & approve to apply" notice; apply
  nothing. Update `.agent/status/harness.md` body to record Phase-1 done (the
  harness slice's own baton, hand-written per house rule).
- **Verification**: `python -m scripts.fea capture <card_path>` writes the baton
  draft + notion payload draft, modifies no live baton, and exits 0.  Full
  end-to-end `report`→`capture` runs with no manual analysis step. **← contract
  "capture produces an accepted baton draft" criterion.**
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout scripts/fea/__main__.py .agent/status/harness.md`
