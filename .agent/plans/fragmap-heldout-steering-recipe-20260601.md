---
contract: .agent/contracts/fragmap-heldout-steering-recipe-20260601.md
slice: fragmap
status: done
outcome: "BOUNCE — 9D0W mechanism NOT-MAPPABLE (inter-chain crystal pairs ⇒ steering the scored interface ⇒ circular; non-circular single-chain design is not 9D0W-comparable). CRBN anchor re-derived 4/4 (durable). FKSFold 07cdf2a. Next: /brainstorm re-spec the parent held-out contract. Tasks 1-3 done, 4 skipped, 5 done."
total_tasks: 5
estimated_total_min: 23
parent_contract: .agent/contracts/fragmap-heldout-placement-validation-20260601.md
feeds: .agent/plans/fragmap-heldout-placement-stageB-20260601.md (satisfies its Tasks 1-2; on PROCEED, Stage B resumes at Task 3)
note: >
  Zero-compute throughout (no GPU, no SLURM). Task 1 carries a DECISION SUB-GATE:
  if the 9D0W mechanism is unrecoverable OR cannot map cleanly to held-out
  targets, the plan pivots to BOUNCE (Task 3 documents it + routes to /brainstorm
  on the parent contract; Task 4 config-build is skipped). The frozen 3 forks
  (9D0W-match / CRBN anchor re-derive only / bounce-on-failure) come from the
  contract.
---

# Plan — Held-out steering recipe (zero-compute)

Repo: `/home/ubuntu/FKSFold-Boltz_Advancement`; work dir:
`analysis/heldout_placement_20260601/`. Resolves the two design questions the
parent held-out contract froze incompletely: (1) target-side steering mechanism
(match 9D0W), (2) CRBN-side anchor re-derivation (production 351/355/357 invalid
in all 4 held-out constructs). Pattern to reuse:
`analysis/heldout_placement_20260601/fix_pocket_numbering.py` (residue-walk +
resname cross-check). Convention (AMENDMENT 1): Boltz contacts/anchors = 1-based
sequence position.

Phases: **1 Recover 9D0W mechanism** (decision sub-gate) → **2 Re-derive CRBN
anchor** → **3 Assemble + decide PROCEED/BOUNCE** → **4 Configs [PROCEED]** →
**5 Commit/handoff**.

---

## Task 1: Recover the 9D0W steering mechanism + mappability verdict

- **Status**: done (NOT-MAPPABLE; 9D0W AB = inter-chain CRBN↔target crystal CA-CA pairs, citations verified real)
- **Prereq tasks**: none
- **Files touched**: `analysis/heldout_placement_20260601/STAGEB_RECIPE.md` (new — write §1 Mechanism)
- **Change shape**: Read the 9D0W precedent and document HOW it encoded
  nativeAB / wrongAB / baseline: `.agent/contracts/fragmap-cdk2-9d0w-pilot-20260521.md`
  and the reports that name the mechanism (`analysis/fragmap_spectral_discriminator/reports/`
  — d1_final_paired_analysis.md, vav1_iface_anchor_sweep_results.md,
  ab_139batch_results.md, failure_mode_diagnostic.md) + `docs/platform_state_and_next_plan_20260529.md`.
  Determine the exact knob ("AB" = which: input-YAML pocket constraint, glueprint
  config block, the `--use_interface_steering`/`--w400_*` flags, or a combination)
  and how wrongAB was constructed there (transplant/transpose vs the parent's
  `((r-1+N//2) mod N)+1`). Write STAGEB_RECIPE.md §1 with **cited file:line**.
  End §1 with a **mappability verdict**: can this mechanism be applied to held-out
  targets (sequence-position knobs that generalize) — YES (proceed) or NO (bounce)?
- **Verification**: STAGEB_RECIPE.md §1 names the 9D0W AB mechanism with ≥2 cited
  `file:line` references and a one-line mappability verdict (`MAPPABLE` /
  `NOT-MAPPABLE`). If `NOT-MAPPABLE`, the plan proceeds to Task 3 in BOUNCE mode
  (Task 2 still runs — the CRBN finding stands either way).
- **Estimated time**: 5 min
- **Rollback**: rm STAGEB_RECIPE.md.

## Task 2: Re-derive the CRBN anchor per held-out construct + verify 4/4

- **Status**: done (CRBN anchor pass 4/4; W400→W at 356/321/331/345, reproduced independently)
- **Prereq tasks**: none
- **Files touched**: `analysis/heldout_placement_20260601/verify_heldout_anchor.py` (new)
- **Change shape**: Residue-walk each held-out CIF's CRBN chain (CIF chain **B** =
  CRBN per SOURCES.md; the YAML chain-A sequence is its gapless modeled form) to
  build author→YAML-chain-A-position. Convert the production VAV1-numbering anchor
  to Q96SW2 author numbering (VAV1_CRBN starts at author 46, so author = VAV1pos +
  45: `w400=355→author 400`; `anchor_patch [351,355,357]→author [396,400,402]`;
  CRBN `pocket [305..355]→author [350..400]`), then map each to the held-out
  construct's 1-based YAML-A position. Cross-check: W400 lands on `'W'`,
  anchor_patch positions in-range with expected residues. Print a per-target table
  (re-derived w400 / anchor_patch / CRBN-pocket positions) + `CRBN anchor pass N/4`.
- **Verification**: `python3 analysis/heldout_placement_20260601/verify_heldout_anchor.py`
  → prints per-target re-derived anchor positions and `CRBN anchor pass 4/4` (W400
  → 'W' for all four; if any target's CRBN construct genuinely lacks W400, that is
  flagged, not forced).
- **Estimated time**: 5 min
- **Rollback**: rm verify_heldout_anchor.py.

## Task 3: Assemble STAGEB_RECIPE.md + record PROCEED/BOUNCE decision gate

- **Status**: done (decision = BOUNCE; §3 documents the comparability-vs-non-circularity conflict)
- **Prereq tasks**: 1, 2
- **Files touched**: `analysis/heldout_placement_20260601/STAGEB_RECIPE.md` (complete §2-§4)
- **Change shape**: Complete the recipe: §2 = the per-target CRBN anchor table
  (from Task 2, re-derived positions) + 4/4 pass record; §3 = the condition
  field/flag table — for each of nativeAB/wrongAB/baseline, the exact field/flag
  that changes and its value for all 4 targets, per the Task-1 9D0W mechanism (the
  target-side pocket positions already corrected in AMENDMENT 1 plug in here); §4
  = the **9D0W comparability statement** (mechanism-equivalence to the 0.913/0.857/
  0.826 precedent, with the chemotype caveat) and a single explicit **decision
  line: PROCEED or BOUNCE**. PROCEED requires Task-1 `MAPPABLE` + Task-2 4/4 +
  a stated comparability basis; otherwise BOUNCE (document why + that the next
  action is /brainstorm on the parent held-out contract).
- **Verification**: `grep -qiE 'PROCEED|BOUNCE' STAGEB_RECIPE.md`; the §3 table
  covers 4 targets × 3 conditions; §2 records `4/4`; §4 states comparability or
  the bounce rationale. Exactly one of PROCEED/BOUNCE is selected.
- **Estimated time**: 5 min
- **Rollback**: revert STAGEB_RECIPE.md to the Task-1 state.

## Task 4: Build per-target generation configs  [PROCEED branch only]

- **Status**: skipped (BOUNCE — Task 3 verdict; no configs built, next action is /brainstorm on parent)
- **Prereq tasks**: 3
- **Files touched**: `analysis/heldout_placement_20260601/configs/oracle_generation_heldout_<ID>.yaml` (≤4)
- **Change shape**: **Only if Task 3 = PROCEED.** From `configs/vav1_pipeline/oracle_generation.yaml`,
  derive each held-out config: set the CRBN-side anchor block (anchor_patch / W400
  / CRBN pocket) to the Task-2 re-derived positions; set the target-side per the
  Task-1/§3 mechanism; preserve gd_weight/gd_floor/w_glueprint and all energy
  params unchanged (config values only — no formula edits, per contract forbidden).
  **If Task 3 = BOUNCE**, skip this task (mark `Status: skipped (BOUNCE)`); the
  next action is /brainstorm on the parent contract, not config-building.
- **Verification**: `for f in analysis/heldout_placement_20260601/configs/*.yaml; do python3 -c "import yaml,sys;d=yaml.safe_load(open(sys.argv[1]));assert 'glueprint' in d" "$f" && echo "$f OK"; done`; each config's CRBN anchor fields equal the Task-2 re-derived positions; `diff` vs the source shows only the intended anchor + target-side changes.
- **Estimated time**: 5 min
- **Rollback**: rm the configs/ dir.

## Task 5: Commit + update parent contract / Stage B plan / baton

- **Status**: done (FKSFold 07cdf2a; recipe contract done=BOUNCE; parent contract + Stage B plan + baton updated; handoff)
- **Prereq tasks**: 1, 2, 3, 4
- **Files touched**: FKSFold commit (STAGEB_RECIPE.md, verify_heldout_anchor.py, configs/ if PROCEED); workspace (this contract status→done + Notes, this plan status→done, parent contract Progress Log, Stage B plan note [Tasks 1-2 satisfied; resume at Task 3 on PROCEED / superseded on BOUNCE], baton + index)
- **Change shape**: Surgical commit of git-trackable artifacts (scratch never
  committed; respect *.csv/outputs* policy). Set this contract `status: done` with
  a Notes paragraph citing STAGEB_RECIPE.md + the PROCEED/BOUNCE verdict. Update
  the parent contract Progress Log + the Stage B plan note accordingly. Update
  `.agent/status/fragmap.md` baton; run `scripts/handoff.sh claude fragmap` +
  `scripts/status.sh index`.
- **Verification**: both repos `git status --porcelain <paths>` clean for tracked
  artifacts; this contract + plan show `done`; the PROCEED/BOUNCE verdict is
  recorded in the baton and the Stage B plan note reflects it.
- **Estimated time**: 3 min
- **Rollback**: git revert.

---

## Decision-gate summary

- **Task 1 sub-gate**: `MAPPABLE` → continue toward PROCEED; `NOT-MAPPABLE` → BOUNCE.
- **Task 3 decides**: PROCEED (MAPPABLE + CRBN 4/4 + comparability stated) →
  Task 4 builds configs → Stage B plan resumes at Task 3 (input YAMLs). BOUNCE →
  Task 4 skipped → next action is /brainstorm on the parent held-out contract
  (the frozen condition matrix may not survive held-out; do not improvise).
- No SLURM, no GPU anywhere in this plan. The Stage B SLURM gate is untouched.
