---
contract: .agent/contracts/aigen-fold-core-semantic-object-layer-20260707.md
slice: aigen-fold-core
status: done
total_tasks: 8
estimated_total_min: 42
---

# Plan — Boltz-compatible Semantic Object layer

Project repo: `/home/ubuntu/AIGENFold` (the `api/` package). Verification
scripts (zero-GPU) live in `.agent/scratch/vav1_degrad_head/phase6/` per the
contract (the API repo has no pytest harness; scratch python scripts are the
test surface). Current state read this session: `api/pipeline.py` hardcodes
VAV1 via module constants (`CRBN_SEQ`, `VAV1_SEQ`, `CRBN_MSA`, `VAV1_MSA`,
`_S1_POCKET_A/B`, `_S1_CONTACTS`, `_S2_POCKET_A`, `_CULT_PAIRS`, `S1_SEEDS`,
`S2_SEEDS`, `_AA3`); the 4 builders (`build_stage1_yaml`, `build_stage2_yaml`,
`cultsum`, `build_template_cif`) read them directly; `api/jobs.py` imports
`S1_SEEDS`/`S2_SEEDS` + the builders. `yaml.dump(..., sort_keys=False)` means
byte-identical output depends only on preserving insertion order. Existing VAV1
latents/poses for the downstream regression: `phase3/pairs/*.npz` (ternary
trunk-z), `phase4/Zpool_388.csv` (the pooled features the v1.1 champion used),
`phase4/sweep.py::oof_pairwise` (reconstructs the 0.558 champion). NO GPU / NO
Boltz runs anywhere in this plan.

## Task 1: TernaryConfig dataclass + VAV1_CONFIG preset
- **Status**: done (2026-07-07, commit eef73be) — verification "config matches pipeline constants" PASS.
- **Prereq tasks**: none
- **Files touched**: AIGENFold/api/ternary_config.py
- **Change shape**: new module. A frozen `@dataclass TernaryConfig` holding
  every currently-hardcoded VAV1-specific value as fields (target_seq,
  e3_seq, target_msa, e3_msa, chain ids for e3/target/ligand, s1_pocket_e3,
  s1_pocket_target, s1_contacts, s2_pocket_e3, cult_pairs, s1_seeds, s2_seeds).
  Plus a `VAV1_CONFIG` instance whose field values are copied verbatim from the
  current `api/pipeline.py` constants. No behavior change, nothing imports it
  yet. Include a module docstring stating this is the input-contract config,
  not an efficacy spec.
- **Verification**: `python3 -c "import sys; sys.path.insert(0,'/home/ubuntu/AIGENFold'); from api import ternary_config as T, pipeline as P; c=T.VAV1_CONFIG; assert c.target_seq==P.VAV1_SEQ and c.e3_seq==P.CRBN_SEQ and c.s1_pocket_e3==P._S1_POCKET_A and c.s1_pocket_target==P._S1_POCKET_B and c.s1_contacts==P._S1_CONTACTS and c.s2_pocket_e3==P._S2_POCKET_A and c.cult_pairs==P._CULT_PAIRS and c.s1_seeds==P.S1_SEEDS and c.s2_seeds==P.S2_SEEDS; print('config matches pipeline constants')"` → prints the confirmation line, no AssertionError.
- **Estimated time**: 5 min
- **Rollback**: rm AIGENFold/api/ternary_config.py

## Task 2: VAV1 golden-output characterization test (pre-refactor lock)
- **Status**: done (2026-07-07, scratch) — golden frozen against unchanged pipeline.py (3 stage1+3 stage2 YAML, 5 cultsum incl. the 60.8/85.5Å outlier tail + 9.6Å band); assert re-run "VAV1 regression PASS (3 yaml + 5 cultsum identical)".
- **Prereq tasks**: none
- **Files touched**: .agent/scratch/vav1_degrad_head/phase6/regression_vav1.py,
  .agent/scratch/vav1_degrad_head/phase6/vav1_golden.json
- **Change shape**: script that, on FIRST run (`--freeze`), captures the
  CURRENT `build_stage1_yaml(smiles)` + `build_stage2_yaml(smiles, cif_path)`
  string outputs for 3 fixed sample SMILES (e.g. MRT6160 + 2 others) and the
  `cultsum` value for ~5 existing stage-1 PDBs (from
  `/mnt/kfs2/data/users/ubuntu/vav1_2stage_alldock_20260702/out_stage1/*`), and
  writes them to `vav1_golden.json`. On normal run (no flag) it re-computes and
  asserts byte-identical YAML + exact cultsum equality vs the frozen golden.
  Run `--freeze` NOW against the unchanged pipeline.py so the golden reflects
  today's shipped behavior.
- **Verification**: `python3 regression_vav1.py --freeze && python3 regression_vav1.py` → second call prints `VAV1 regression PASS (3 yaml + 5 cultsum identical)`, exit 0.
- **Estimated time**: 6 min
- **Rollback**: rm phase6/regression_vav1.py phase6/vav1_golden.json

## Task 3: Parametrize the 4 builders on TernaryConfig (VAV1_CONFIG default)
- **Status**: done (2026-07-07, commit 9850575) — golden test byte-identical PASS (independently re-run), jobs.py call sites unaffected (leading positionals only), aliases + register_quality_score preserved.
- **Prereq tasks**: 1, 2
- **Files touched**: AIGENFold/api/pipeline.py
- **Change shape**: `build_stage1_yaml`, `build_stage2_yaml`,
  `build_template_cif`, `cultsum` gain a `config: TernaryConfig = VAV1_CONFIG`
  parameter and read seqs/pockets/contacts/cult-pairs/chain-ids/msa from it
  instead of module globals. Insertion order into the YAML dicts UNCHANGED
  (so `sort_keys=False` output stays byte-identical for VAV1). Keep the
  existing module constants as thin aliases sourced FROM `VAV1_CONFIG` (so
  `from api.pipeline import S1_SEEDS` etc. in jobs.py keep working). Add a
  `register_quality_score = cultsum` module alias with a docstring: "placement/
  degron-register QC; NOT a degradation-efficacy score". `run_stage` /
  `find_model0_pdb` untouched.
- **Verification**: `cd .agent/scratch/vav1_degrad_head/phase6 && python3 regression_vav1.py` (Task-2 golden) → still `VAV1 regression PASS`, byte-identical; AND `python3 -c "import sys; sys.path.insert(0,'/home/ubuntu/AIGENFold'); from api.jobs import *; from api.pipeline import S1_SEEDS,S2_SEEDS,register_quality_score; print('jobs import + aliases OK', S1_SEEDS, S2_SEEDS)"` → prints seeds, no ImportError.
- **Estimated time**: 6 min
- **Rollback**: `git -C /home/ubuntu/AIGENFold checkout api/pipeline.py`

## Task 4: Parametric proof on a synthetic non-VAV1 config
- **Status**: done (2026-07-07, scratch) — synthetic config (fake target seq + distinct pocket/contact indices) flows through both builders; asserts target == fake AND != VAV1, yaml valid, substituted indices present. "parametric PASS".
- **Prereq tasks**: 3
- **Files touched**: .agent/scratch/vav1_degrad_head/phase6/parametric_check.py
- **Change shape**: script builds a synthetic `TernaryConfig` with a fake
  target seq + different pocket/contact residue sets (still CRBN as E3), calls
  `build_stage1_yaml`/`build_stage2_yaml` with it, and asserts: (a) output
  parses via `yaml.safe_load`, (b) `sequences[1].protein.sequence` equals the
  substituted fake target seq (proving no VAV1 seq baked in), (c) chains A/B
  + ligand C present, (d) the pocket/contact blocks reflect the substituted
  residue indices. Confirms zero VAV1 assumption survives in the builders.
- **Verification**: `python3 parametric_check.py` → prints `parametric PASS (synthetic target substituted, yaml valid, chains A/B/C present)`, exit 0.
- **Estimated time**: 5 min
- **Rollback**: rm phase6/parametric_check.py

## Task 5: SemanticObject schema + stable input hash
- **Status**: done (2026-07-07, commit 1267f4f) — dataclass (9 fields, defaulted), deterministic sha256 hash (independently verified stable + smiles-sensitive), 2 "NOT an efficacy" class-source annotations.
- **Prereq tasks**: 1
- **Files touched**: AIGENFold/api/semantic_object.py
- **Change shape**: new module. A `@dataclass SemanticObject` with fields:
  `input_contract_hash`, `target_id`, `e3_id`, `ligand_smiles`,
  `pooled_trunk_z` (list/ndarray ref), `register_quality_score`,
  `boltz_affinity_head_score`, `confidence` (dict: iptm/plddt/etc),
  `validity` (dict: boltz_success/ligand_valid/pose_valid/clash_flag/
  affinity_available). The two efficacy-adjacent fields carry a class-level
  docstring/comment literally containing "NOT an efficacy" for each. Plus
  `stable_input_hash(config: TernaryConfig, smiles: str, constraints=None)`
  = deterministic hash (sha256 of a canonical json of config fields + smiles).
  No builder logic yet (Task 6).
- **Verification**: `python3 -c "import sys; sys.path.insert(0,'/home/ubuntu/AIGENFold'); from api.ternary_config import VAV1_CONFIG; from api.semantic_object import stable_input_hash, SemanticObject; import inspect,re; h1=stable_input_hash(VAV1_CONFIG,'CCO'); h2=stable_input_hash(VAV1_CONFIG,'CCO'); assert h1==h2 and stable_input_hash(VAV1_CONFIG,'CCC')!=h1; src=inspect.getsource(SemanticObject); assert src.lower().count('not an efficacy')>=2; print('hash stable + non-efficacy annotations present')"` → prints confirmation, no AssertionError.
- **Estimated time**: 5 min
- **Rollback**: rm AIGENFold/api/semantic_object.py

## Task 6: build_semantic_object() from existing latent/pose
- **Status**: done (2026-07-07, commit 6e8beb2) — builder + _pool_trunk_z (phase4-faithful, lazy heavy imports); independently verified pooled_trunk_z matches Zpool_388.csv to ~1e-14 across 3 compounds; cid101 pooled_dim=1155, rqs=60.84 finite.
- **Prereq tasks**: 5
- **Files touched**: AIGENFold/api/semantic_object.py
- **Change shape**: add `build_semantic_object(config, smiles, latent_npz,
  stage1_pdb, confidence_json=None, affinity=None)` that assembles a
  SemanticObject: `input_contract_hash` via `stable_input_hash`, `pooled_trunk_z`
  via the phase4 LP-block pooling convention (reuse the mean/std/median-over-
  interface-block logic; import or vendor the small pooling fn — no
  re-derivation of the numbers), `register_quality_score` via
  `pipeline.cultsum(stage1_pdb, config)`, `confidence` parsed from the json if
  given, `validity` flags from presence/sanity checks. Pure assembly, zero-GPU.
- **Verification**: `python3 -c "..."` building one SemanticObject for a real VAV1 compound from an existing `phase3/pairs/VAV1_<cid>.npz` + its stage-1 pdb → asserts all fields populated, `pooled_trunk_z` non-empty with expected width, `register_quality_score` finite; prints the record's field summary. (Exact one-liner written in the task; expected: `SemanticObject built: hash=<...> pooled_dim=<N> rqs=<float>`.)
- **Estimated time**: 6 min
- **Rollback**: `git -C /home/ubuntu/AIGENFold checkout api/semantic_object.py` (or revert the added fn)

## Task 7: DownstreamRanker regression (v1.1 reproduces 0.558 from SemanticObject features)
- **Status**: done (2026-07-07, scratch) — independently re-run: 388/388 carrier fidelity (max|diff|=2.8e-14), v1.1 cross-scaffold rho=0.5584 unchanged. "pooled-z match=True (388 rows); v1.1 cross-scaffold rho=0.558 (PASS)".
- **Prereq tasks**: 6
- **Files touched**: .agent/scratch/vav1_degrad_head/phase6/downstream_regression.py
- **Change shape**: script builds SemanticObjects for the VAV1 388 (from
  existing latents, zero-GPU), extracts their `pooled_trunk_z`, asserts it
  numerically matches `phase4/Zpool_388.csv` (the features the champion used)
  within float tolerance (proves the SemanticObject builder is a faithful
  carrier), then runs the v1.1 champion reconstruction
  (`phase4/sweep.py::oof_pairwise` on L+poolMSD, large_scaffold) and asserts
  cross-scaffold OOF Spearman == 0.558 ± 0.01. Proves the refactor did not
  perturb the shipped model's numbers.
- **Verification**: `python3 downstream_regression.py` → prints `pooled-z match=True (388 rows); v1.1 cross-scaffold rho=0.558 (PASS)`, exit 0.
- **Estimated time**: 5 min
- **Rollback**: rm phase6/downstream_regression.py

## Task 8: Docs + status update
- **Status**: done (2026-07-07) — module docstring already stated the role (grep "not efficacy"=3, no code edit needed); slice status entry appended (STATUS_OK), CDK2 recorded as data-gated.
- **Prereq tasks**: 7
- **Files touched**: AIGENFold/api/semantic_object.py (module docstring only),
  .agent/status/aigen-fold-core.md
- **Change shape**: finalize the `semantic_object.py` module docstring stating
  the layer's role (standardization + QC + caching, explicitly NOT an efficacy
  predictor; VAV1 efficacy stays v1.1). Add a `remaining_actions` entry to the
  slice status recording the layer shipped + the byte-identical VAV1 regression
  + parametric proof + downstream 0.558 regression, and that CDK2 execution
  remains data-gated. (CURRENT.md is regenerated by handoff, not hand-edited.)
- **Verification**: `grep -c "not.*efficacy\|NOT an efficacy" AIGENFold/api/semantic_object.py` ≥ 3; `grep -q semantic-object-layer .agent/status/aigen-fold-core.md && echo STATUS_OK` → prints STATUS_OK.
- **Estimated time**: 4 min
- **Rollback**: revert the docstring + status edit
