# aigen-fold-core — Boltz-compatible Semantic Object layer (target/E3-parametric input contract + attribute cache)

Status: done
Slice: aigen-fold-core
Topic: semantic-object-layer
Date: 2026-07-07
Approval: requested 2026-07-07; approved by: user (2026-07-07 "승인")

## Notes — DONE (2026-07-07)

Shipped via plan `.agent/plans/aigen-fold-core-semantic-object-layer-20260707.md`
(8 tasks, each /code-review-gated + independently re-verified). The VAV1-
hardcoded 2-stage ternary pipeline is now target/E3-parametric and emits a
persisted SemanticObject attribute record — extend, not rebuild, and provably
NOT an efficacy model. Commits on branch `platform-versioning-r20260417`:
eef73be (api/ternary_config.py — TernaryConfig + VAV1_CONFIG), 9850575
(api/pipeline.py — 4 builders parametrized on config=VAV1_CONFIG, byte-
identical VAV1 path), 1267f4f (api/semantic_object.py — schema +
stable_input_hash), 6e8beb2 (build_semantic_object + phase4-faithful
_pool_trunk_z). All success criteria met: (a) VAV1 golden byte-identical
regression PASS; (b) synthetic non-VAV1 config produces valid substituted
YAML (target-parametric proven); (c) SemanticObject persists with a stable
input_contract_hash; (d) pooled_trunk_z matches Zpool_388.csv to ~1e-14 across
388 and v1.1 reproduces cross-scaffold 0.5584 through the layer (shipped model
UNPERTURBED); (e) grep-checkable "NOT an efficacy" annotations present (=3).
Scratch verifiers: phase6/{regression_vav1.py, parametric_check.py,
downstream_regression.py}. OUT-OF-SCOPE-as-designed / OPEN: CDK2 (or any new
target) EXECUTION remains data-gated (needs real seq + pocket/template + glue
series; the config path can now express it, running one is a separate pilot);
a server.py route emitting SemanticObject was deferred (library-level only).
VAV1 efficacy ranking remains the unchanged v1.1 (L+poolMSD pairwise, cross
0.558).

## Purpose

Turn the VAV1-hardcoded 2-stage ternary pipeline that already ships as the
REST `/v1/ternary` endpoint into a reusable, target/E3-parametric **input
contract** plus a persisted **SemanticObject** record of everything Boltz
derives for one (target, E3, glue) input. The value is engineering
standardization and cheap QC/triage + caching, NOT a new efficacy predictor.
A new target (e.g. CDK2 later) should reuse the exact same YAML generation /
chain+ligand indexing / constraint / template / seed handling by supplying a
config, not by forking the pipeline. Downstream potency ranking stays a
separate, swappable layer (VAV1 = the validated v1.1 ligand+trunk-z pairwise
ranker, unchanged).

This contract is the corrected successor to
`aigen-fold-core-ssl-interface-encoder-pretrain-20260706.md` (done, ESCAPE):
that work established, and this contract takes as settled, that no continuous
structural "guide/efficacy" signal exists in the current pipeline outputs to
learn from — so this layer is explicitly scoped as infrastructure + QC, never
as an efficacy model.

## Current State

- `AIGENFold/api/pipeline.py` (shipped 2026-07-06, `aigen-fold-core-rest-api-20260630`):
  hardcodes VAV1 via module constants `CRBN_SEQ`, `VAV1_SEQ`, `CRBN_MSA`,
  `VAV1_MSA`, `_S1_POCKET_A`, `_S1_POCKET_B`, `_S1_CONTACTS`, `_S2_POCKET_A`,
  `_CULT_PAIRS`, `S1_SEEDS`, `S2_SEEDS`. The four builders
  (`build_stage1_yaml`, `build_stage2_yaml`, `cultsum`, `build_template_cif`)
  read these constants directly. `api/jobs.py` `run_ternary_prediction` chains
  stage1(2-seed) → CULTsum pick → template CIF → stage2(5-seed) → PDB copy.
  `api/schema.py` `TernaryRequest`, `api/server.py` `POST /v1/ternary`.
- SETTLED FACTS this layer must respect (verified this session, do NOT re-litigate):
  - CULTsum across VAV1 388: 91% of compounds in a 9.4-9.7Å band (near-zero
    variance), 4-9% outlier tail up to 82.6Å, seed-reproducible (rho +0.897),
    logDC50-INDEPENDENT (rho +0.069, p=0.176).
  - Boltz confidence/ipTM: same near-binary shape, logDC50 rho -0.117, and
    rho vs CULTsum = -0.603 (p=7.6e-40) → CULTsum and ipTM are the SAME
    placement-success/failure axis, not two independent signals.
  - Boltz affinity head: null for DC50 ranking (prior v2 work).
  - → the two attributes this layer caches (register_quality_score = CULTsum,
    boltz_affinity_head_score) are QC / binder-likeness, NOT efficacy. VAV1
    efficacy ranking stays v1.1 (cross-scaffold rho 0.558, shipped, unchanged).

## Scope

1. **Parametrize the pipeline** (`api/pipeline.py`): lift the VAV1-specific
   constants into an explicit `TernaryConfig`-style object (target seq + MSA,
   E3 seq + MSA, stage-1/stage-2 pocket residue sets, stage-1 contacts,
   CULT/register residue pairs, seed lists, chain ids). The four builders take
   a config argument. A `VAV1_CONFIG` preset reproduces today's exact behavior
   as the default so existing callers are byte-identical.
2. **Rename + relabel the attributes** so the names stop implying efficacy:
   `cultsum` → surfaced as `register_quality_score` (keep the function; the
   value is the same min-heavy-atom degron-register distance sum; docstring
   states "placement/register QC, NOT a degradation-efficacy score"). The
   affinity-head value is surfaced as `boltz_affinity_head_score` with the same
   "not a validated efficacy proxy" caveat.
3. **Define + persist a SemanticObject schema**: one record per (target, E3,
   glue) input carrying `input_contract_hash` (stable hash of the config +
   SMILES + constraints so identical inputs dedup/cache), pooled trunk-z
   features (reuse the phase4 LP-block pooling convention), `register_quality_score`,
   `boltz_affinity_head_score`, confidence metrics (ipTM/pLDDT/etc), and
   validity/QC flags (boltz_success, ligand_valid, pose_valid, clash_flag,
   affinity_available). Every efficacy-adjacent field carries an explicit
   "not efficacy" annotation in the schema definition.
4. **Separate builder from ranker**: SemanticObjectBuilder (produces the
   record) is independent of any DownstreamRanker. VAV1's v1.1 ranker consumes
   the SemanticObject's pooled-trunk-z + ligand features and must reproduce its
   current OOF numbers (regression gate).

## Out of scope

- Any efficacy / DC50 / Dmax predictor built on register_quality_score or
  boltz_affinity_head_score. This layer makes NO efficacy claim.
- A student/surrogate that predicts these attributes (deferred; only pays off
  as pre-Boltz triage and its ceiling is bounded by the QC/binder-likeness
  nature of the teachers — separate contract if ever pursued).
- CDK2 (or any new-target) EXECUTION: gated on actually having CDK2 sequence +
  pocket/template definition + a glue/degrader series. This contract only
  ensures the config path CAN express a new target; running one is a separate,
  data-gated pilot.
- A second, parallel input-contract implementation. This EXTENDS
  `api/pipeline.py`; it does not create a rival module that would drift.
- Changing the shipped v1.1 VAV1 DC50 model or its numbers.
- Engine/Boltz-repo edits (latent/affinity hooks stay in the kfs2 rootfs copy).

## Triggers matched

- Public API change (`api/pipeline.py` builder signatures, `api/schema.py`).
- 4+ files modified (pipeline.py, jobs.py, schema.py, + new semantic_object
  module; server.py possibly).
- NOT a SLURM/GPU trigger for the VAV1 scope: the layer is built and
  regression-tested against ALREADY-EXTRACTED VAV1 latents/poses (no new Boltz
  runs needed). Any GPU (a new target) is out of scope / separately gated.

## Success criteria

- **Byte-identical VAV1 regression**: with the `VAV1_CONFIG` preset,
  `build_stage1_yaml`/`build_stage2_yaml`/`cultsum`/`build_template_cif`
  produce output identical to the current hardcoded versions on a fixed set of
  VAV1 inputs. Verification: a diff test over N sample compounds' generated
  YAML + a numeric equality check on cultsum for the existing stage-1 PDBs
  (`out_stage1/*`), asserting zero difference vs the pre-change code.
- **Parametric proof**: instantiating a non-VAV1 `TernaryConfig` (a synthetic
  or scratch target/E3 seq + pocket set) produces structurally valid stage-1/2
  YAML with the substituted sequences/constraints and the correct chain/ligand
  layout — proving no VAV1 assumption is baked into the builders. (Validity =
  YAML parses + has the expected chains/constraint blocks; NOT a Boltz run.)
- **SemanticObject persists + round-trips**: building a SemanticObject for a
  VAV1 compound writes the schema record with `input_contract_hash`,
  pooled-trunk-z, register_quality_score, boltz_affinity_head_score, and QC
  flags; re-building the same input yields the same hash (cache key stable).
- **DownstreamRanker regression**: the v1.1 ranker fed from SemanticObject
  pooled-trunk-z reproduces its documented VAV1 OOF Spearman (cross-scaffold
  0.558 within tolerance) — proving the refactor didn't perturb the shipped
  model. Verification command: a script that builds SemanticObjects for the
  388, runs the v1.1 ranker, and prints OOF rho for comparison to 0.558.
- Every efficacy-adjacent attribute in the schema is annotated "not efficacy"
  (grep-checkable).

## Resource budget

- Zero-GPU for the VAV1 scope (reuses existing latents/poses at kfs2
  `vav1_2stage_alldock_20260702` + `vav1_encoder_20260704`). CPU refactor +
  regression tests only.
- Work lives in `AIGENFold/api/` (project repo) + a new `api/semantic_object.py`
  (or similar); scratch verification scripts under
  `.agent/scratch/vav1_degrad_head/phase6/`.

## Rollback plan

- Additive/parametric refactor: the `VAV1_CONFIG` preset preserves current
  behavior, so the change is a superset. Revert = drop the new
  `semantic_object` module + revert the builder signatures to the hardcoded
  constants (single `git revert` of the api/ commits). No data migration, no
  shared-storage writes, no GPU jobs to cancel. The shipped v1.1 model and its
  artifacts are untouched throughout.

## Approval

- requested: 2026-07-07
- approved by: user (2026-07-07 "승인")

## Assumptions and questions

- Assumes the current `/v1/ternary` VAV1 behavior is the correct reference to
  hold byte-identical (it is the shipped standard as of 2026-07-06).
- Open: exact persistence format for SemanticObject (JSON-per-input vs a single
  parquet/CSV table) — decide at /write-plan; JSON-per-input keyed by
  input_contract_hash is the leaning (matches the per-compound npz convention
  already used).
- Open: whether `api/server.py` needs a new route to emit a SemanticObject, or
  whether it stays a library-level builder for now (leaning library-only this
  round; a route is a later, separately-triggered public-API change).
