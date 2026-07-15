---
contract: .agent/contracts/fragmap-dc50-overfit-scan-20260527.md
slice: fragmap
status: done
total_tasks: 5
estimated_total_min: 20
---

# Plan — DC50 overfit scan (Step 6, exploratory)

Decomposition of the approved Step 6 contract. Zero-compute (scipy/sklearn),
all artifacts in the SHARED analysis tree (non-git, like the rest of this
session's fragmap analysis). Rollback = `rm` (no git commit).

Repo note: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared`
is the (non-git) analysis location. Per-task "commit" → file left in place;
rollback → delete the file.

Key discipline (from contract): pre-fixed test family, Benjamini-Hochberg FDR,
NO Stage 2 gate verdict, NO metric promotion (that is Step 6b).

SHARED = /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared

---

## Task 1: Emit per-compound CSV from vav1_placement_decompose.py

- **Status**: done (2026-05-27, --out-csv added, canonical CSV 125 rows generated, /code-review APPROVE pure-addition)
- **Prereq tasks**: none
- **Files touched**: `analysis/fragmap_spectral_discriminator/src/vav1_placement_decompose.py` (SHARED)
- **Change shape**: The script currently only prints aggregate stats. Add a `--out-csv` option (default `analysis/fragmap_spectral_discriminator/reports/vav1_placement_decompose.csv`) that writes one row per compound: `compound, centroid_trans, rot_angle_deg, legacy_rb_offset, f1_true`. Pure addition of a CSV-writer at the end of `main()`; no change to existing computation or prints.
- **Verification**: `python analysis/fragmap_spectral_discriminator/src/vav1_placement_decompose.py --out-csv /tmp/dec.csv && wc -l /tmp/dec.csv` → ≥ 120 rows (+header), and header contains `compound,centroid_trans,rot_angle_deg`
- **Estimated time**: 4 min
- **Rollback**: revert the added block (cp .bak or remove the `--out-csv` writer)

## Task 2: Write dc50_overfit_scan.py (join + pre-fixed family + BH-FDR)

- **Status**: done (2026-05-27)
- **Prereq tasks**: 1
- **Files touched**: `analysis/fragmap_spectral_discriminator/src/dc50_overfit_scan.py` (SHARED, new)
- **Change shape**: New script. (a) Join `ab_139batch_eval.csv` + `vav1_placement_decompose.csv` (on compound) + DC50 from `outputs/_mmgbsa_staging/norm143_corrected_sources.tsv` (dc50_nM→log10). (b) Pre-fixed metric list (9): vav1_rigid_body_offset, centroid_trans, rot_angle_deg, f1_4A, f1_5A, tgt_min_dist, iptm, plddt, p_vav1_lig, each with a hard-coded expected-direction sign. (c) For each metric × {Spearman, Pearson} × {full, active≤30nM}: correlation vs log10 DC50. (d) Binary AUC (active≤30nM, ≤100nM) per metric. (e) Benjamini-Hochberg FDR across the full correlation family → q-values. Emit `dc50_overfit_scan.csv` (metric, test_type, subset, n, rho_or_r, raw_p, q_value, expected_dir_match) + print ranked table + n(active) + survivors(q<0.05) count. NO gate verdict logic.
- **Verification**: `bash -n` n/a (python); `python -c "import ast; ast.parse(open('analysis/fragmap_spectral_discriminator/src/dc50_overfit_scan.py').read())"` exit 0, AND `grep -c "multipletests\|benjamini\|fdr_bh" analysis/.../dc50_overfit_scan.py` ≥ 1 (FDR present), AND `grep -c "gate\|PASS\|Stage 2" analysis/.../dc50_overfit_scan.py` = 0 (no gate verdict)
- **Estimated time**: 5 min
- **Rollback**: `rm analysis/fragmap_spectral_discriminator/src/dc50_overfit_scan.py`

## Task 3: Run scan → produce CSV + verify family integrity

- **Status**: done (2026-05-27)
- **Prereq tasks**: 2
- **Files touched**: `analysis/fragmap_spectral_discriminator/reports/dc50_overfit_scan.csv` (SHARED, generated)
- **Change shape**: Execute the scan. Confirm the number of correlation tests equals the pre-specified family size (9 metrics × 2 corr-types × 2 subsets = 36 correlation rows + 9×2 AUC rows), q≥p for all, and DC50 join coverage (n with both). No post-hoc family expansion.
- **Verification**: `python analysis/.../dc50_overfit_scan.py` exit 0; `python -c "import pandas as pd; d=pd.read_csv('.../dc50_overfit_scan.csv'); print('corr_tests',((d.test_type.isin(['spearman','pearson'])).sum())); assert (d.q_value>=d.raw_p-1e-9).all(); print('q>=p OK'); print('survivors',(d.q_value<0.05).sum())"` → corr_tests = 36, "q>=p OK", survivors printed
- **Estimated time**: 2 min
- **Rollback**: `rm` the CSV

## Task 4: Write report (exploratory framing, overfit interpretation)

- **Status**: done (2026-05-27)
- **Prereq tasks**: 3
- **Files touched**: `analysis/fragmap_spectral_discriminator/reports/dc50_overfit_scan_20260527.md` (SHARED, new)
- **Change shape**: Markdown. Sections: setup (n, active n, DC50 source) → ranked correlation table (ρ/r, p, q, direction-match) → AUC table → **overfit interpretation** applying the contract's pre-fixed rule (0 survivors → strong overfit-negative signal, but caveat power at active n; ≥1 survivor → Step 6b pre-registration candidate, NOT a pass) → explicit "EXPLORATORY, not a Stage 2 gate" banner → power note (detectable effect size at this active n). ~70 lines.
- **Verification**: `grep -ci "exploratory\|not a.*gate" analysis/.../dc50_overfit_scan_20260527.md` ≥ 1 AND `grep -c "survivor\|q<0.05\|q-value" report` ≥ 1 AND `wc -l` ≥ 40
- **Estimated time**: 5 min
- **Rollback**: `rm` the report

## Task 5: Update status + CURRENT.md

- **Status**: done (2026-05-27)
- **Prereq tasks**: 4
- **Files touched**: `.agent/status/fragmap.md`, `.agent/handoffs/CURRENT.md`
- **Change shape**: fragmap status §Open Step 6 → result line (survivors count + overfit reading). CURRENT.md remaining_actions: Step 6 done, surface Step 6b (pre-registered gate) + the Stage-2 decision as the gated next action. Add contract to contract_pointers. Bump version.
- **Verification**: `grep -c "dc50.overfit\|Step 6" .agent/status/fragmap.md` ≥ 1 AND CURRENT.md version incremented AND `grep -c "dc50-overfit-scan" .agent/handoffs/CURRENT.md` ≥ 1
- **Estimated time**: 4 min
- **Rollback**: `git -C /home/ubuntu checkout .agent/status/fragmap.md .agent/handoffs/CURRENT.md` (these ARE git-tracked under /home/ubuntu)

---

## Notes

- Tasks 1-4 touch SHARED (non-git) — rollback = rm/revert, no git commit. Task 5 touches `.agent/` (git-tracked under /home/ubuntu).
- The scan is read-only on input data; only writes new analysis artifacts.
- Whole-plan rollback: `rm` the new scan script + CSV + report + decompose CSV; revert the decompose.py `--out-csv` addition; `git checkout` the `.agent/` docs.
- Honest prior: every within-class signal to date (confidence, F1 top-10, MMGBSA n=37) has been null — a null scan is the likely and informative outcome (strong overfit-negative), modulo the active-n power caveat.
