# FragMap Experiment Autopilot (FEA)

A thin lifecycle harness around the SLURM science loop. It does not rewrite the
science — it orchestrates existing analysis assets and encodes lab lessons as
gates. Advisory/gated throughout: validation, analysis, and *drafts* run
automatically; every actuator (`sbatch`, re-submit, Notion write, commit) stays
human-gated.

## CLI

```
python -m scripts.fea report <job_dir> --baseline-csv … --y-csv … --smiles-csv …
        # classify cells → metrics battery → scaffold-blocked gate → Results Card
python -m scripts.fea capture <card>
        # gated DRAFTS only: status baton (.fea-draft) + Notion payload JSON
python -m scripts.fea preflight <config.yaml> [--input-yaml X] [--strict]
        # fragmap config: forbidden mode / missing paths / empty channels (error)
        #                 + VAV1 pocket-vs-GT audit (warn)
python -m scripts.fea preflight-mmgbsa --md-length-ns L --window A B [--strict]
        # MD↔sampling coupling: window>traj + under-sampling (first-Nns) guard
python -m scripts.fea preflight-fksfold --cif X --chain B --w400-index N [--strict]
        # CRBN anchor: does --w400_residue_index map to a real W (tryptophan)?
```

## Shipped

- **Phase 1 — postflight + capture (fragmap).** `report` reproduces the
  documented induced-fit-inverted KILL end-to-end; the gate is scaffold-blocked
  with **no pooled-median path**. `capture` drafts the baton/Notion payload,
  never writing live state.
- **Phase 2a — fragmap preflight + warn-only sbatch-gate advisory.** Catches the
  wrong-FragMap-mode class before GPU. The hook advisory never changes the gate
  verdict.
- **Phase 2c — mmgbsa coupling preflight.** Reuses the committed
  `mmgbsa_coupling.py` (`derive_frame_range` / `coupling_check`) and adds the
  **coverage guard** that catches the first-Nns-of-Mns under-sampling bug
  (`coupling_undersampled`). FEA never edits the blocked `run_mmpbsa.py`; the
  Stage-2/Stage-3 single-source wiring (B4) remains the mmgbsa slice's task.
- **Phase 2d — fksfold CRBN-anchor preflight.** `preflight-fksfold` reuses
  `verify_heldout_anchor.modeled()` (Bio.PDB imported lazily) to check the
  submitted `--w400_residue_index` maps to a real tryptophan in the construct's
  CRBN chain — catches the production `355`→G/L/P/S bug + author-vs-seq off-by-one.
  This **completes the umbrella's "3 known-bad configs" criterion**
  (FragMap-mode = 2a, coupling = 2c, CRBN-anchor = 2d).

## Deferred / follow-ups

- **mmgbsa post-hoc run-dir audit.** Phase 2c ships the *pre-submit* coupling
  arithmetic check. A *post-hoc* audit — parse real `traj_frames` via `gmx check`
  + the patched `gb_run.in`, then `mmgbsa_coupling.coupling_check` — is deferred
  (needs gmx + completed run dirs).
- **Stage 2 watch** (live failure-signature monitor over SLURM logs).
- **GPU-UUID submit-script check** (flag `--gpus=device=0` in arrays vs the
  per-task UUID pattern) — the infra half of fksfold preflight, deferred from 2d.
- **Full 3-leg PROVE** in `run_gates` (currently leg-(i) permutation-significance
  only; full PROVE adds MW-partial + descriptors-only).

## Layout

- `__main__.py` — `report` / `capture` / `preflight` / `preflight-mmgbsa` CLI.
- `postflight.py` — cell classification, metrics ingestion, scaffold-blocked gate.
- `results_card.py` — Results Card schema + markdown/frontmatter serializer.
- `capture.py` — gated baton + Notion payload drafts.
- `preflight.py` — fragmap config validator (mode/paths/channels/pocket).
- `mmgbsa_preflight.py` — MD↔sampling coupling preflight.
- `fksfold_preflight.py` — CRBN-anchor (W400 tryptophan) seq-walk preflight.

## References

- Contract: [.agent/contracts/harness-experiment-autopilot-20260604.md](../../.agent/contracts/harness-experiment-autopilot-20260604.md)
- Plans: `.agent/plans/harness-experiment-autopilot-phase1-…`, `…-phase2a-…`, `…-phase2c-mmgbsa-…`
