# VAV1 Ranking Harness

Primary script:

- `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/vav1_ensemble_rank.py`

Related configs:

- `/home/ubuntu/FKSFold-Boltz_Advancement/configs/vav1_pipeline/*ranking*.yaml`
- `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/configs/vav1_pipeline/*ranking*.yaml`

## Purpose

This harness governs VAV1 ensemble ranking, production ranking defaults,
historical baselines, and ranking metric validation.

## Current Issue From Recent Cursor Activity

The current final rank philosophy is mostly right:

- de-emphasize iPTM as the top signal
- keep key-residue geometry central
- aggregate ensemble evidence across seeds

Cursor history flagged that the production default should not remain a strict
lexicographic `keyres_mean -> keyres_max` style sort. Actual shared files show
that the active shared script has already moved in this direction:

- `baseline_rank` uses `ranking_priority`.
- `production_score` uses `production_ranking.score_weights`.
- `production_rank` uses `production_ranking.priority`.
- `final_rank = production_rank`.

The remaining harness risk is local/shared divergence: the local git worktree
has `scripts/vav1_ensemble_rank.py` deleted, while the shared workspace contains
the active production-aware script.

The ranking concerns to preserve as validation checks are:

- `keyres_hit_rate` is computed but not used in rank.
- `keyres_max` appears too early and can reward one lucky seed.
- `ranking_priority` exists in config but is not connected to sorting.
- `ligand_aware_mean`, `n_lv_mean`, and iPTM are too late to matter.
- artifact, efficacy-risk, and MMGBSA proxy are not production flags.

## Required Ranking Split

Maintain two rank modes:

1. Historical baseline rank
   - preserves current behavior for comparison
   - must be named explicitly in outputs

2. Production rank
   - consistency-aware
   - config-driven
   - uses flags or weak penalties for artifacts

Do not silently replace historical output semantics.

Actual shared script already follows this split. A future local-repo task should
reconcile that shared script into the git worktree before more ranking edits.

## Production Rank Candidate

Minimum production sort:

1. `keyres_hit_rate`
2. `keyres_mean` or `keyres_v2_mean`
3. `keyres_median`
4. `ligand_aware_mean`
5. `n_lv_mean`
6. `iptm_mean`

Preferred production score:

```text
ensemble_score =
  w_mean * keyres_mean
  + w_median * keyres_median
  + w_hit * keyres_hit_rate
  + w_ligand * ligand_aware_mean
  + w_nlv * n_lv_mean
  + w_iptm * iptm_mean
  - w_std * keyres_std
  - weak_artifact_penalty
```

`keyres_max` should be retained as a rescue or explanation feature, not as the
second production sort key.

## Implementation Requirements

Any ranking implementation change must:

- keep current rank as a baseline output or explicit mode
- read `ranking_priority` or remove it from configs
- add median and std aggregates if using consistency-aware score
- expose per-compound flags for severe clash, chain break, efficacy-risk, and
  missing MMGBSA
- write enough columns to compare old and new ranks
- preserve `baseline_rank`, `production_rank`, and `final_rank` semantics
- document whether work targeted local git repo or shared execution workspace

## Validation Gate

Before claiming a ranking change is good:

- compare current baseline rank vs production candidate rank
- compute rank movement for top 20 and known active/inactive examples
- report known cases such as high ligand-aware but slightly lower keyres
- check whether high `keyres_max` single-seed cases are demoted
- verify missing values do not reorder compounds unpredictably

Suggested outputs:

- `*_ensemble_baseline.csv`
- `*_ensemble_production.csv`
- `*_rank_delta.csv`
- `*_ranking_summary.json`

## Verification Commands

```bash
python -m compileall scripts/vav1_ensemble_rank.py
python scripts/vav1_ensemble_rank.py --help
```

For data-backed validation, use a copied or explicitly named output prefix so
baseline outputs are not overwritten.

## Stop Conditions

Stop and ask before:

- changing production defaults without a baseline comparison
- deleting old rank columns
- overwriting existing rank CSVs
- treating MMGBSA proxy as a primary objective
- merging oracle-only assumptions into blind ranking
