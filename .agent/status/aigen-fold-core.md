---
owner_session: 2df9f044-00ad-4def-b91a-7fd04107456b
owner_label: 
owner_agent: claude
version: 73
last_updated: 2026-07-15
heartbeat: 2026-07-15T17:24:34Z
remaining_actions:
  - 'DECISION: BOLTZ-2 LATENT TEARDOWN + 3 CONTROL/CANDIDATE EXPERIMENTS DONE
    (2026-07-15, VAV1 degrad-head lineage, contracts
    aigen-fold-core-raw-s-control-20260715.md +
    aigen-fold-core-token-trans-bias-20260715.md, both done; the free-features
    check needed no formal contract, read-only/zero-GPU). User asked to
    visually decompose Boltz-2''s full forward pass to find every extractable
    tensor beyond the 4 already used in v1.1 (Zt/Zt_z trunk s+z, Zpc/Zpc_z
    confidence s_conf/z_conf, Aff/Zaffg affinity scalar+embedding). 6-agent
    parallel code-reading of upstream Boltz-2 source (/tmp/boltz_upstream)
    cataloged 66 individual tensors across 6 pipeline stages (AtomAttention
    encoder, Template+MSA, PairFormer trunk x64, distogram/bfactor heads,
    diffusion denoising, confidence/affinity residuals), tagged by extraction
    cost (15 free-already-serialized / 22 hook-only / 22 need-source-patch /
    3 diffusion-frontier / 1 dead-code). Built an interactive HTML teardown
    (tensor cards + pipeline flow diagrams + cost/size bar charts + full
    wiring diagram with tapped-feature star markers,
    https://claude.ai/code/artifact/e6ff578b-dfb0-42fc-b8dc-ce04a69e6c1a) and
    a Notion report (https://app.notion.com/p/39e1e76c3b6081de975eef983ab1525a).
    Then executed 3 follow-up experiments in priority order, each verified
    against DC50 signal via the SAME rank_harness CV used for the standing
    v1/v1.1 baselines (L 0.545/0.222, Zt_z 0.290-0.363/0.363-0.383, L+Zt_z
    pairwise v1.1 cross 0.558). (1) ''free'' confidence/affinity fields
    (pair_chains_iptm, ligand_iptm, protein_iptm, complex_ipde/iplddt/pde,
    affinity ensemble individual value1/2+prob1/2) re-parsed from
    ALREADY-EXISTING 388-compound job outputs (zero new compute) -- mostly
    null (|rho|<0.16), one exception aff_prob1 (whole-pop +0.22 p<0.0001,
    scaffold-CV +0.13 CI-separated) too small to escalate. IMPORTANT
    METHODOLOGY CATCH: large_scaffold GroupKFold (only 12 scaffold groups)
    produces spurious strongly-negative pooled-rho (-0.51 to -0.57) for raw
    un-PCA''d single columns that a direct between/within-scaffold
    decomposition shows is pure CV artifact (whole-pop/between/within all
    near-zero) -- do NOT trust large_scaffold pooled-rho for any future
    raw/few-column feature without this same direct check first; corrected
    pdistogram/pbfactor from ''free'' to ''patch'' tier in the teardown docs
    (verified: computed but never serialized in any existing job output,
    unlike the other ''free'' items which ARE already in
    confidence_*.json/plddt_*.npz/affinity_*.json). (2) raw pre-recycling
    s_inputs (AtomAttention/InputEmbedder output, zero structural context) --
    contract aigen-fold-core-raw-s-control-20260715.md, additive engine hook
    in boltz_native_20260621 rootfs boltz2.py (BOLTZ_DUMP_S_INPUTS, mirrors
    existing BOLTZ_DUMP_LATENT/DUMP_AFFG pattern, backup kept), 388/388
    extracted via kim SLURM (4 batches, 0 failures). Result: real but modest
    signal (within-scaffold ~0.20-0.22, weaker than L/Zt_z), and critically
    does NOT reproduce Zt_z''s distinctive weak-within/strong-cross signature
    once the large_scaffold GroupKFold artifact is stripped out via the same
    direct check (between-scaffold +0.18 p=0.57, within-residual +0.08
    p=0.34, both non-significant) -- CONTROL GROUP VERDICT: v1.1''s
    "structure adds value cross-scaffold" interpretation SURVIVES this
    control; the recycling loop (Template+MSA+PairFormer) appears to be
    doing real work, not just re-exposing sequence/composition information
    already present pre-recycling. (3) token_trans_bias (diffusion-
    conditioning token-pair bias, computed once post-recycling pre-diffusion
    from trunk z + relative-position encoding via PairwiseConditioning) --
    contract aigen-fold-core-token-trans-bias-20260715.md, same
    additive-hook pattern (BOLTZ_DUMP_TOKEN_TRANS_BIAS), 388/388 extracted
    (4 batches, 0 failures, 132GB kfs2 -- large, flagged for cleanup if not
    pursued further). Result: the ONE of these three that behaves like a
    genuine structural feature -- within-scaffold pooled rho +0.31 to +0.32,
    CI-separated, comparable in magnitude to Zt_z itself; combining with L
    (raw concat, directional only) does not hurt (L+ttb within 0.529 vs
    L-alone 0.545, cross 0.264 vs 0.222, CIs overlap). large_scaffold
    GroupKFold gave +0.39/+0.24 -- this time the direct decomposition check
    points the SAME direction (not opposite, unlike items 1/2) but
    weaker/non-significant (+0.31 between p=0.33, +0.09 within-residual
    p=0.29), so likely a real but smaller cross-scaffold-relevant signal,
    not the full +0.39. OPEN DECISIONS (none executed, all deferred): (a)
    whether to run the formal redundancy test (L+Zt_z+token_trans_bias
    through v1.1''s ACTUAL PCA-then-pairwise-ranking pipeline, not the quick
    raw-concat check done here) to see if token_trans_bias is additive over
    Zt_z or just correlated-and-redundant (both derive from trunk z) -- the
    single most promising unfinished thread from this session; (b) whether
    to pursue any of the remaining ~40 hook/patch-tier tensors cataloged in
    the teardown (e.g. block-wise PairFormer intermediates, AffinityModule''s
    own internal pre-pool z/g) -- teardown artifact has the full
    priority-ordered list; (c) cleanup of the 132GB token_trans_bias raw npz
    dir (vav1_ttb_control_20260715/ttb/) if the redundancy test in (a) isn''t
    pursued soon; (d) whether to fold any of this into the v1.1 model card,
    or keep as documented-null/documented-candidate side findings only.
    Nothing shipped/changed in the v1.1 model itself this session -- all 3
    experiments were validation/exploration, not production changes.'
  - 'DECISION: CDK2/23SR PILOT -- DDB1-AUGMENTED TEMPLATE + IKZF1 ROOT-CAUSE
    DONE (2026-07-14 continued, contract
    aigen-fold-core-cdk2-23sr-pilot-20260713.md, same contract, extends the
    generalization-sweep entry below). Two more targets + one deep root-cause
    dig, all same-day continuation. (1) Added IKZF3/9UUM (Aiolos ZF2-ZF3,
    55aa, glue=mezigdomide/QFC, CRBN gap-free 380/397) to the 7-target sweep:
    WORST of all 8 despite gap-free CRBN (target RMSD 22.92A) -- further
    confirms target-size (not CRBN completeness) drives outcome; tandem-ZnF
    domains may be even more "floppy" than a single ZnF (IKZF1 32aa=18.78A)
    despite being nominally larger, hinting domain RIGIDITY may matter
    alongside raw size. (2) DDB1-augmented template test (user proposal):
    stage-2 currently has ZERO explicit target-position constraint (only a
    ligand-E3 pocket constraint, established earlier) -- hand-built a 3-chain
    (DDB1+CRBN+target) YAML (pipeline.build_stage2_yaml only supports 2
    protein chains, so this bypasses it) using DDB1''s real position from
    each target''s own ground-truth CIF (DDB1_SEQ = full UniProt Q16531,
    offset=0 verified 0/1119 mismatches vs 9NFR). Result on the 3 worst
    performers: VAV1 16.77->8.97A (IMPROVED), IKZF3 22.92->2.26A (DRAMATIC,
    worst-of-8 to best-of-8), IKZF1 18.78->18.99A (NO CHANGE). Verified
    NOT seed-luck: all 3 confirmed across the full 5-seed panel (std
    0.05-0.18A on every number). (3) IKZF1 deep-dive (user: "파고들어"):
    ruled out wrong-ligand (6H0F''s real glue is Y70=S-Pomalidomide, not
    lenalidomide -- fixed, zero effect on result) and altloc duplicate atoms
    (6H0F chain B has 2 disordered residues incl. HIS378 full A/B altloc --
    fixed, output BYTE-IDENTICAL before/after, meaning gemmi/boltz already
    dedupes internally). Per-residue error breakdown found the true
    signature: CRBN''s N-domain (Lon-N+HBD, local 24-263) fits at 1.52A
    (excellent) while its C-domain (CULT, local 264-397, WHERE THE LIGAND
    POCKET IS) fits at only 4.82A, with an 83.4-degree RELATIVE HINGE
    ROTATION between them -- not a folding failure, an inter-domain
    misassignment. DDB1 does not touch this (hinge 83.4->83.8 deg,
    unchanged). Ruled out crystal multiplicity (6H0F''s 4 asymmetric-unit
    copies agree to 1.8-2.6 deg, no inherent flexibility). THE ANSWER:
    computed the same N-vs-C-domain hinge angle, relative to a common
    CDK2/23SR reference frame, across all 8 ground-truth structures --
    7/8 (CDK2, VAV1, IKZF3, NEK7x2, CK1a, PRDM1) agree to within 1.5-11.8
    deg of each other (one shared "common" CRBN conformation); ONLY 6H0F
    diverges, at 93.4 deg -- a genuine, reproducible (confirmed across its
    4 copies) but RARE conformational outlier. The model''s actual
    prediction sits only 3.0 deg from the COMMON conformation -- i.e. the
    model ignored 6H0F''s unusual true template and reverted to its learned
    "typical CRBN fold" prior. This is the SAME phenomenon already documented
    in this slice''s own prior DDB1-series work ("Boltz''s prior for the
    novel VAV1-CRBN geometry overrides the correction every step") --
    independently reconfirmed here for a different target/mechanism.
    CONCLUSION on the 8-target sweep as a whole: 7/8 failures are a
    CONSTRAINT-COMPLETENESS problem (no explicit target-position constraint
    in stage-2; fixable at INFERENCE time by adding DDB1, no retraining
    needed -- confirmed by the DDB1 rescue working on an already-trained,
    unchanged model); IKZF1/6H0F is a DIFFERENT, deeper PRIOR-DOMINANCE
    problem (soft template guidance loses to a strong, data-driven prior
    when the true structure is a rare outlier -- not fixable by adding more
    context, only by data-representation changes or harder template
    enforcement, a design/training-objective question, not a "just add more
    data" one). Artifacts: `/home/ubuntu/cdk2_23sr_diffusion_trajectory/`
    (all analysis scripts) + kfs2 mirror `true_template_ddb1_*.cif`,
    `work_traj/*_DDB1*/`. OPEN DECISIONS: (a) adopt true-template (+ DDB1
    variant) into canonical api/ternary_config.py/pipeline.py -- now with a
    much stronger empirical case (8-target sweep + mechanistic
    understanding of both failure modes); (b) whether the IKZF1-specific
    prior-override finding is worth a deeper follow-up (e.g. harder
    template enforcement as a pipeline feature) or stays a documented
    known-limitation; (c) write-up/paper angle for the whole arc (structure
    pilot -> mechanism -> generalization -> DDB1 rescue -> prior-override
    root cause) -- nothing decided yet, session paused here on user request.'
  - 'CDK2/23SR PILOT -- GENERALIZATION SWEEP + MUTANT-PANEL
    VALIDATION DONE (2026-07-14, contract
    aigen-fold-core-cdk2-23sr-pilot-20260713.md, same contract as the
    2026-07-13 32-compound batch, extends it). Two follow-ups after the
    32-compound batch: (1) diffusion-trajectory mechanism check -- monkeypatched
    (this-process-only) the ACTUAL vanilla sampling loop our runs use to dump
    per-step coordinates; confirmed the true-template''s influence is present
    from step 0 (not gradually emerging) and CDK2 placement locks to 2.64A
    once sigma<~1. (2) Generalization sweep across 7 targets (CDK2 + VAV1 +
    IKZF1 + NEK7 x2-structures + CK1a + PRDM1, all built from ground-truth
    CIFs already in `/home/ubuntu/AIGENFold/examples/heldout/`): REFUTED the
    "CRBN template must be gap-free" hypothesis (IKZF1/6H0F is gap-free yet
    WORST of all 7, 18.78A); found the real driver is TARGET DOMAIN SIZE,
    near-perfectly monotonic (CDK2 298aa=2.64A ... IKZF1 32aa=18.78A). NEK7
    tested on 2 different crystals (9NFQ/9H59, different CRBN gap patterns)
    gave nearly identical results (4.60/4.28A) -- clean evidence gap location
    barely matters once target size is fixed. Practical rule: check target
    size (>~200 resolved residues = good candidate) before CRBN completeness.
    (3) Independent validation via B11''s alanine-scan mutant panel (19
    positions, real EC50 data, not just geometric RMSD): predicted and
    ground-truth interface distances agree closely after fixing a
    numbering-frame bug (unified reference file keeps raw auth numbers for
    CRBN, predictions use local/offset-45 numbers); EC50 fold-change
    anti-correlates with interface distance as expected (Spearman -0.39 GT,
    -0.21 predicted); E57 (top hotspot) sits at consistent CRBN distance
    (2.59-3.09A, std=0.11A) across ALL 32 predicted compounds, not just B11 --
    the shared-binding-mode assumption holds against independent experimental
    data. Artifacts: `/home/ubuntu/cdk2_23sr_diffusion_trajectory/` (plots,
    driver scripts, validation results). OPEN DECISIONS unchanged from
    2026-07-13 entry below: (a) adopt CDK2_CONFIG + true-template pattern into
    canonical api/ternary_config.py/pipeline.py as a documented capability
    (now better-justified given the size-based triage rule), or keep
    scratch-only; (b) what to do next with the 32 predicted poses + this
    generalization finding (write up formally? apply to a new real target?).'
  - 'CDK2/23SR STRUCTURE PILOT -- ROOT CAUSE FOUND + 32-COMPOUND
    BATCH DONE (2026-07-13, contract
    aigen-fold-core-cdk2-23sr-pilot-20260713.md). First real non-VAV1 target
    run through the 2-stage ternary pipeline. Smoke (B11) passed
    mechanically but FAILED structurally (CDK2 CA RMSD 24-25A vs 23SR
    ground truth, all 5 seeds agreeing -- a confident wrong placement, not
    noise). 9 stage-1-template config variants (v1-v5 contact/pocket
    redesigns + P1-P4 fast factorial screen) ALL failed to fix it
    (12-42A miss band; one P1 seed hit 4.46A but was a one-off anomaly with
    its own ligand-tail defect). Comprehensive stage1-vs-stage2 analysis
    (47 structures) showed the error is already present at stage-1;
    stage-2 templating neither fixes nor worsens it. DECISIVE TEST: built
    a stage-2 template directly from 23SR ground-truth coordinates
    (true_template.cif, protein-only) instead of a Boltz stage-1 output,
    skipping stage-1 entirely -- CDK2 RMSD dropped to 2.38-3.06A across
    all 5 seeds (matches the VAV1/9NFR benchmark ~2.9A). CONCLUSION:
    stage-2 re-docking is fundamentally sound; the root cause of every
    prior failure was stage-1/CULTsum never producing an accurate enough
    template, not stage-2 instability. User then proposed reusing this
    SAME fixed template for all 32 SI-CSV compounds (ligand-swap only,
    stage-1 skipped for all): executed as SLURM array (job 16897 + retry
    16929 for 3 transient CUDA-OOM failures, confirmed via GPU-UUID check
    to be cluster contention on other nodes, not a pipeline bug) -- 32/32
    compounds, 5/5 seeds each, zero mechanical failures. Batch structural
    analysis (batch_analysis.py, SMARTS-verified glutarimide match across
    all 32 distinct SMILES): per-compound mean CDK2 RMSD 2.54-2.79A
    (median 2.67, 0/32 exceed 5A), glutarimide-head anchoring 0.61-0.84A
    series-wide -- both essentially identical to B11 alone. Resolves
    contract Done-When #2 for the full compound set via a different route
    than originally scoped (fixed true-template + ligand-swap under a
    shared-binding-mode assumption, not per-compound CULTsum-selected
    templates) -- explicit caveat: validates SAR-series structural
    self-consistency, not independent per-analog ab initio prediction, and
    makes no efficacy/potency claim. OPEN DECISION (not yet made): (a)
    whether to adopt CDK2_CONFIG + the true-template-from-ground-truth
    pattern into the canonical api/ternary_config.py/pipeline.py (Done-When
    #3, currently scratch-only at
    /mnt/kfs2/data/users/ubuntu/cdk2_23sr_pilot_20260713/); (b) what to do
    with the 32 predicted ternary poses next (downstream ranking feature
    extraction? paper writeup? nothing yet decided). Full per-compound
    table: full_batch_results.txt (scratchpad); poses:
    output_ttbatch/<compound>/ on the kfs2 mirror. Progress Log in the
    contract file has the complete v1-v5/P1-P4/true-template/batch
    narrative.'
  - 'DATA-LEVER LEARNING-CURVE DIAGNOSTIC DONE (2026-07-12, contract
    aigen-fold-core-datalever-learning-curve-20260712.md, done, plan same slug
    done; zero-GPU, reused the already-extracted 505 features + 117 poses). Ran
    the diagnostic the v1.2/phase8 flat point could not settle: the SLOPE of a
    fixed-test-set learning curve (test-rho vs n_train), plus 3
    verification-driven cleanups. RESULT = REVERSAL of the standing "same-assay
    data is the lever" hypothesis. Q1 (CORE, phase9/learning_curve_results.csv):
    learning curve FLAT in both regimes across a 4.4x data range -- cross (fixed
    62-cmpd test) rho 0.578/0.578/0.547/0.557/0.523 at n_train
    100/200/300/388/443 (last-seg Δrho=-0.034 vs CI half-width 0.153 = PLATEAU;
    whole-range -0.054, drifts slightly DOWN not up); within (fixed 101-cmpd
    test) 0.472/0.523/0.462/0.468/0.502, also PLATEAU. Flatness from n=100 (not
    just the last segment) = "no rise even in point estimates," materially
    stronger than the single phase8 delta. Q2 (phase9/heldout_117_results.csv):
    train-388 predict-117 held-out rho=0.497 [0.325,0.641] n=117 /
    scaffold-disjoint 0.480 [0.320,0.617] n=113 -- the new series IS predictable
    (comparable to v1.1 cross 0.558), so "tapped" = the structure-as-FEATURE
    ceiling (~0.55 cross), NOT a broken model. Q3
    (phase9/eval_reconciled_results.csv): (a) single-cap reconcile barely moves
    the phase8 deltas (cross -0.034->-0.024, within +0.027->+0.025, both
    CI-straddle-0) -- cap mismatch was NOT driving the verdict; (b) CORRECT
    within champion = ligand-gbdt on L (0.545, sanity reproduces 0.5449), NOT the
    poolMSD-pairwise phase8 wrongly used -- with it Δ(505 vs 388)=+0.0047
    [-0.051,+0.056] P=0.578, essentially null; (c) honest matched-set
    A-on-135=0.5235(per-src)/0.5334(1-cap) vs B-on-135=0.5584 -- A(505) trails
    B(388) by ~0.03 on the shared set, NOT the near-tie the phase8 prose implied.
    Q4 (phase9/bridge_505.csv + eval): bridge_span_mean''s +0.028 [+0.002,+0.057]
    CI-separated headroom at n=388 EVAPORATES at n=505 -> +0.021 [-0.015,+0.058]
    P=0.88 (same sign/magnitude, CI now spans 0); 388 spot-check reproduces
    phase7 to 1e-9. CONVERGENT VERDICT: at n~505 with the current
    docking->trunk-latent->poolMSD/ligand pipeline, adding more same-assay data
    at THIS scale is not expected to move the ranker; structure-as-ranking-feature
    is at/near exhausted (ceiling ~0.55 cross). Honesty guardrails: the model
    generalizes (Q2) so the ceiling is the FEATURE not the model; cross tests
    underpowered per-point so the strict claim is "no DETECTABLE rise," but the
    flat 4.4x-range SHAPE is stronger than the single phase8 point. Ship model
    UNCHANGED (v1.1: L+poolMSD pairwise cross 0.5584 / ligand-gbdt within 0.545).
    Do-next OBSERVATIONS (not decisions): (i) pivot the modeling
    target/representation rather than grow same-assay data; (ii) if data is
    pursued, only a much larger 2-5x+ OR different-signal/assay campaign is likely
    to move it, not incremental same-assay batches; (iii) v1.1 stays shipped, no
    refit follows. Full writeup phase9/results_v9.md, which SUPERSEDES two
    phase8/results_v8.md numbers: the cross headline (A-on-160=0.5524 -> honest
    matched-set A-on-135=0.5235/0.5334) and the within champion (v8 used
    poolMSD-pairwise; correct is ligand-gbdt on L, with +117 delta +0.005
    P=0.578). Artifacts phase9/{data_505.py, learning_curve.py+_results.csv,
    heldout_117.py+_results.csv, eval_reconciled.py+_results.csv, bridge_on_505.py,
    bridge_505.csv, results_v9.md}.'
  - 'V1.2 SAR DATA INTEGRATION DONE (2026-07-12, contract
    aigen-fold-core-v12-sar-data-integration-20260712.md, done, plan same slug
    done). Incorporated the 117 newly-curated SAR compounds (388->505, +30.2%,
    curated 2026-07-11 per the entry below) into the full pipeline:
    scaffold-CV fold reassignment across all 505 (phase8/refold_505.py),
    117/117 docked via the unchanged 2-stage Boltz ternary pipeline (SLURM,
    kim account; 108 clean first pass + 9 recovered via a node-exclusion
    resubmit, host-10-0-5-36 GPU contention, not a pipeline bug), 117/117
    trunk-latent-dumped (mid-plan discovery: v1.1''s poolMSD feature needs
    Boltz TRUNK s/z tensors, not derivable from the PDB poses alone -- required
    a second, cheap, user-approved GPU pass), Zpool_117.csv +
    ligand_features_117.csv built with column schema independently verified
    identical to the existing 388 tables. Evaluated the UNCHANGED v1.1 model
    spec (L+poolMSD, censoring-aware pairwise ranking) on 505 vs 388-only via a
    3-condition design (A=505 new-fold, B=388-only new-fold [PRIMARY, isolates
    data-volume alone], C=388-only original fold [sanity check, reproduces
    documented 0.5584/0.4290 exactly]). RESULT: flat/inconclusive --
    cross-scaffold delta (A vs B) -0.034 [-0.133,+0.049] P(A>B)=0.240 (CI
    straddles zero); within-scaffold delta +0.027 [-0.022,+0.077] P(A>B)=0.867
    (leans positive, CI still includes zero). Neither direction CI-separated.
    4 caveats travel with these numbers, all restated inline in
    phase8/results_v8.md next to the relevant figures (not buried): (1)
    censoring-cap mismatch -- 388 rows censored at dc50_nm>=10000, 117 rows at
    their own pre-existing dc50_nm>=1000 convention, fed into the pairwise loss
    as-is per source, not reconciled; (2) AIG22071A*/B* same-structure
    discordant DC50 (68.19 vs 149.52nM, same batch different sub-batch/date),
    flagged via duplicate_structure_group, not auto-merged (predates this
    contract, 2026-07-11 curation); (3) 3 compounds (AIG22013 aza-glutarimide,
    AIG22018 boron-containing, AIG22138 ring-contracted) fail the canonical
    CRBN-warhead SMARTS by design, confirmed real SAR variants not errors,
    flagged not dropped (predates this contract); (4) NEW this contract -- the
    "cross" CV scheme''s (cv_large_scaffold) fold parameter is accepted but
    never referenced internally (GroupKFold splits are rebuilt purely from
    scaffold-membership counts each call), so Task 1''s fold reassignment has
    ZERO effect on any cross-scaffold number (B and C are bit-identical for
    cross); only within-scaffold (cv_scaffold) actually keys off fold -- a
    methodology note for future reuse of cv_large_scaffold. This contract''s
    success criterion (data-incorporation-confirmed + honest performance
    report, NOT a performance gate) is MET. Ship model UNCHANGED: v1.1
    (L+poolMSD pairwise, cross 0.5584). The v1.2 ship/no-ship decision is
    explicitly OUT OF SCOPE per the contract''s Non-Goals -- a separate open
    decision for the user; flat/inconclusive results argue against replacing
    v1.1 on performance grounds alone but that call is not this contract''s to
    make. Full writeup phase8/results_v8.md. Artifacts
    phase8/{refold_505.py, vav1_dataset_505_folds.csv, build_dock_manifest.py,
    dock_manifest_117.csv, dock_driver.py, run_dock_117*.sh, latent_driver.py,
    latent_dump_117.sh, verify_latent_117.py, build_pool_117.py, Zpool_117.csv,
    build_ligand_features_117.py, ligand_features_117.csv, eval_v12.py,
    eval_v12_results.csv, results_v8.md}.'
  - 'SAR DATA CURATION DONE (2026-07-11). Two-part session: (1) fixed a real
    SMARTS bug found while auditing user-supplied SAR files: phase6/pull_chembl_crbn.py
    CRBN_WARHEAD_SMARTS "glutarimide" pattern O=C1CCC(=O)N1 is actually a
    5-membered succinimide ring, not the true 6-membered glutarimide
    (O=C1CCCC(=O)N1); fixed + corpus re-filtered from the same unfiltered pull
    (no re-fetch needed) -- corrected count 3,672 (was mislabeled 2,127).
    ESCAPE verdict of aigen-fold-core-ssl-interface-encoder-pretrain-20260706.md
    UNAFFECTED (conclusion turned on corpus magnitude vs pretraining-scale
    millions, true at either count); that contract''s Notes + this file''s
    2026-07-07 entry + the published Notion report
    (3981e76c-3b60-818d-bdb0-ded77360635d) all corrected in place. GPU latents
    (job 16178, 2,089) were extracted from the OLD smaller corpus -- a new GPU
    job would be needed to use the corrected delta, not done (out of scope,
    ESCAPE already stands). Old buggy corpus kept for audit:
    phase6/crbn_corpus_raw_PRE_SMARTS_FIX_buggy_2127.csv. (2) Curated 7
    user-supplied VAV1 files for usable data: 20260701_VAV1_SAR.xlsx (internal
    HiBiT assay, SAR tatble sheet) yielded 117 NEW same-assay DC50-labeled
    compounds (not previously in phase0 388; canonical-SMILES cross-ref, not
    code-based -- caught MRT-6160 duplicated under 2 codes). 388->505 (+30.2%).
    Independently adversarially verified (3-lens Workflow: data-integrity,
    chemistry, stats/logic, all PASS, zero pipeline bugs found, one minor
    notes-arithmetic fix applied: 27 pinned-at-cap + 1 outlier=13797.78, not
    "28 pinned"). Artifacts: phase0/{curate_sar20260701.py,
    vav1_dataset_sar20260701_new.csv (117 new, compound_id 511-627),
    vav1_dataset_extended.csv (505, audit merge -- NOT training-ready yet),
    curation_notes_sar20260701.md}. OPEN decisions flagged, not silently
    resolved: (a) new sheet censors at >1,000nM vs phase0 legacy >=10000nM --
    kept as DISTINCT censor_cap_nm per row, not equated; (b) AIG22071A*/B* are
    literally the same structure with discordant DC50 (149.52 vs 68.19nM,
    same synth batch VAV1-20251222-6 sub-batches) -- flagged via
    duplicate_structure_group, not auto-resolved; (c) 3 compounds
    (AIG22013/22018/22138) fail the warhead SMARTS by design (aza-glutarimide,
    BN-isostere, spiro-ring-contraction bioisosteres, confirmed real not
    errors) -- flagged not dropped; (d) fold/CV NOT assigned for the 117 new
    rows (scaffold-GroupKFold must be recomputed over all 505 once/if this
    is used for actual v1.2 retraining -- separate contract-worthy step, not
    done here). The other 6 supplied files: 260317_VAV1_patents_SAR*.xlsx (3
    files, 640 rows) = external patent mining, exactly reproduces phase0
    388 (=its origin, WO2024151547) + 243 new from 5 OTHER patents in BINNED
    (non-continuous) DC50 -- different assay/precision regime, NOT merged
    into the training set, usable only as an external check if ever needed;
    20260610_VAV1_SAR_B.xlsx + 260427_VAV1_AIGEN_Compound_DC50.xlsx = older
    snapshots of the same internal assay, no incremental new compounds;
    20260617_VAV1_docking_요청.xlsx = docking-request log, no DC50 at all.'
  - 'SEMANTIC-OBJECT-LAYER DONE (2026-07-07, contract+plan aigen-fold-core-semantic-object-layer-20260707.md, done, 8 tasks, each /code-review-gated + independently re-verified). Turned the VAV1-hardcoded 2-stage ternary pipeline (api/pipeline.py, the shipped POST /v1/ternary) into a target/E3-PARAMETRIC input contract + a persisted SemanticObject attribute record, EXTEND-not-rebuild. NOT an efficacy model (explicit: this session already proved no continuous structural guide/efficacy signal exists — CULTsum/ipTM = same near-binary placement detector, affinity-head null for DC50; SSL pretrain = ESCAPE). Layer role = standardization + QC + caching + cheap triage; VAV1 efficacy ranking STAYS v1.1 (L+poolMSD pairwise, cross 0.558, UNCHANGED). Commits (branch platform-versioning-r20260417): eef73be api/ternary_config.py (TernaryConfig frozen dataclass + VAV1_CONFIG preset, E3/target-neutral fields); 9850575 api/pipeline.py 4 builders parametrized on config=VAV1_CONFIG default (byte-identical VAV1 path — golden characterization test locked pre-refactor then re-passed identical; jobs.py call sites unaffected; back-compat aliases CRBN_SEQ/VAV1_SEQ/S1_SEEDS/etc kept sourced from VAV1_CONFIG; cultsum aliased register_quality_score with NOT-efficacy comment); 1267f4f api/semantic_object.py schema+stable_input_hash (sha256 of asdict(config)+smiles, deterministic; 2 NOT-an-efficacy class annotations); 6e8beb2 build_semantic_object + _pool_trunk_z (reproduces phase4/poolfeats.py exactly, lazy numpy/gemmi/rdkit imports). VERIFIED: (a) golden byte-identical VAV1 YAML+cultsum PASS; (b) synthetic non-VAV1 config flows through builders (target substituted, != VAV1, valid YAML) = target-parametric proven; (c) pooled_trunk_z matches Zpool_388.csv to ~1e-14 across 388; (d) v1.1 reproduces cross-scaffold 0.5584 through the new layer = shipped model numbers UNPERTURBED. Scratch verifiers phase6/{regression_vav1.py+vav1_golden.json, parametric_check.py, downstream_regression.py}. OPEN (data-gated, out of this contract): CDK2 (or any new target) execution needs real seq+pocket/template+glue series; the config path CAN now express it, running one is a separate pilot. server.py SemanticObject route deferred (library-level only this round).'
  - '3BODY+MGOFF FEATURES DONE (2026-07-07, contract aigen-fold-core-3body-mgoff-features-20260707.md, done, adversarially verified via wf_fa84c28d-5dd 4 lenses + own reseed test). Two GENUINELY-untried structural axes on the existing 388 docked ternary poses (chain A=CRBN/B=VAV1/C=glue), zero-GPU: (1) explicit 3-body CRBN-glue-VAV1 HYPERGRAPH geometry (glue atoms bridging a CRBN residue AND a VAV1 residue simultaneously -- the many-body signal pooled/pairwise reps cannot encode), (2) MG-on/off static counterfactual (glue-mediated vs glue-deleted direct CRBN-VAV1 contact). RESULTS: MG-off = robust NULL (inert added to champion delta +0.002 CI-spans-0; negative standalone -0.238; inert BY CONSTRUCTION since all 388 are glue-templated poses = CULTsum mechanism). 3-body BLOCK = unusable (adding all 28 cols hurts cross on original split delta -0.128, but FRAGILE: CI-separated in only 2/17 CV instantiations per Lens4; "at best inert, directionally negative"). ***KEY (reversed my first-pass "clean null" writeup):*** Lens2 hidden-positive scan found ONE column -- bridge_span_mean (mean width of the CRBN-VAV1 gap the glue spans, over bridging glue atoms) -- is a SMALL but DIRECTIONALLY-ROBUST positive add over the v1.1 champion: cross 0.558->0.587, delta +0.028 [+0.002,+0.057] P=0.984, reproduced by me independently to 4 decimals; my pre-registered reseed test = positive in 10/10 fresh cross-scaffold GroupKFold instantiations (+0.013..+0.042), CI-separated in 4/10 -> NOT a multiple-testing/peeking artifact (a chance crossing would flip sign across reseeds). This is the FIRST structural signal this arc that is ADDITIVE over the champion (not redundant like trunk-z, harmful like encoder/set-kernel/block, or data-starved like SSL). Physically: larger productive CRBN-VAV1 span -> more potent; a single interpretable geometric scalar (opposite of the overfit-prone high-dim encoders). VERDICT: ship model UNCHANGED = v1.1 (L+poolMSD pairwise, cross 0.558); bridge_span_mean = candidate v1.2 add (~0.587) pending ONE clean pre-registered nested-CV or held-out-scaffold confirm (gain small +0.02-0.03, not urgent). Lens3 confirmed the standalone hyper3 0.340 is glue-SIZE-driven (already in L) so the block cannot add. Strategic conclusion INTACT: +0.03 marginal does not displace the standing lever (same-assay VAV1 wet-lab data expansion); structure-as-ranking-feature ~tapped at n=388. Full writeup phase7/results_v7.md. Artifacts phase7/{extract_features,gate,eval_features,nested_cv_confirm}.py + {hyper3_388,mgoff_388,gate_results,eval_results}.csv.

NESTED-CV CONFIRM DONE (2026-07-08, phase7/nested_cv_confirm.py): 5 outer cross-scaffold folds, inner-fold-only 28-column blind rescan (never sees outer-test) -> select -> score on untouched outer-test. Pooled: champion 0.5584 -> nested-selected 0.5968, delta +0.0384 [+0.0029,+0.0797] P=0.983 = CI-separated positive, confirms real recoverable structure (not a peeking artifact of the original scan). Per-fold catches the risk in real time: n_glue_heavy (the size confound Lens3 flagged) was blind-selected twice on inner-CV alone, and one instance COMPLETELY FAILED TO TRANSFER (outer delta=0.000 despite inner delta=+0.15) -- textbook overfitting caught red-handed. bridge_span_mean was blind-reselected in 1/5 folds and delivered the 2nd-best outer gain (+0.073) -- now the ONLY column that has survived every independent check (Lens2 discovery, my 4-decimal reproduction, 10/10-direction reseed test, this nested nomination). pw_n_vav1_res_by_glue (contact-breadth proxy, previously unflagged) also won its fold (+0.084) -- secondary candidate, only 1 supporting instance so far. VERDICT: do NOT deploy "auto-pick best-scanning column" as a procedure (grabs confounds); DO trust bridge_span_mean specifically for a v1.2 add. Ship model still UNCHANGED (v1.1, cross 0.558) pending an actual decision to cut v1.2 -- the confirmation bar is now cleared, remaining step is a go/no-go call + refit-on-all-388 + model_card bump, not more validation.'
  - 'SSL-INTERFACE-ENCODER-PRETRAIN DONE, VERDICT=ESCAPE (2026-07-07, contract aigen-fold-core-ssl-interface-encoder-pretrain-20260706.md, done, independently re-verified). Full arc: pretrained the LP-block sub-encoder self-supervised (masked-token reconstruction, no DC50 labels) on 2,089 warhead-confirmed ChEMBL CRBN-glue compounds (from 4,223 scraped across 299 CRBN-tagged targets; DeepTernary ~38k corpus REJECTED as CRBN-irrelevant), then transplanted the pretrained TokenProj (main+ln only, narrowly scoped) into BlockPMA-X and fine-tuned on VAV1 388. RESULT (re-derived + independently spot-checked against raw OOF CSVs and phase4/sweep.py directly, not just trusted): cross-scaffold (n=135) no-pretrain-control rho=-0.098 -> pretrain+finetune rho=+0.191, paired-bootstrap delta +0.289 CI[+0.072,+0.365] P=0.994 = REAL, CI-separated positive effect (pretraining genuinely works, in direction and in kind). But vs historical no-pretrain BlockPMA-X (0.178): delta CI spans zero (not a decisive win over the old baseline either). vs v1.1 champion (0.558, reconstructed to 0.5584, verified match): delta -0.361 CI[-0.544,-0.189] = clearly, decisively trails. VERDICT=ESCAPE per contract criteria. Interpretation: the mechanism ("buy representational capacity with unlabeled data") is validated as real, but 2,089 compounds (~5.4x VAV1, not the ESM/AlphaFold millions-scale regime) is 2-3 orders of magnitude too small to close a 0.37-rho gap. v1.1 (pooling+pairwise, cross 0.558) remains the unchanged shipped VAV1 DC50 model. This ALSO resolved a mid-execution detour: user briefly proposed pivoting to a "semantic object model" (guide_score + Boltz affinity distillation, CDK2 floated as downstream target then dropped) — before building new infra for that, checked whether a usable continuous guide_score exists at all (CULTsum: 91% near-zero variance + 4-9% outlier tail, logDC50-independent rho=+0.069 p=0.176; Boltz confidence/ipTM: same shape, rho vs CULTsum=-0.603 p=7.6e-40 = same placement-success detector viewed twice, not an independent axis) -> concluded no such signal exists, pivot dropped, original pretrain question resumed and completed instead. Standing lever reaffirmed: same-assay VAV1 wet-lab data expansion — 4 independent structural-signal directions this session (learned encoder 0.178, set-kernel -0.27~-0.45, CULTsum, Boltz confidence) plus this pretrain result all point the same way: representation-side levers are exhausted at this n; data is the remaining lever. Full writeup phase6/pretrain_results.md. Reusable artifacts: phase6/{crbn_corpus_raw.csv, pretrain_pairs/, pretrain_ckpt.pt, Zpretrain_LP.csv, cultsum_388.csv, confidence_388.csv, eval_pretrain.py}. OPEN (low-pri, optional): fix the YAML backslash-escaping bug in build_pretrain_inputs.py (SMILES with cis/trans backslash broke YAML parsing for a few compounds) if this corpus/pipeline pattern is reused for any future target.'
  - 'REST API TERNARY STANDARD DONE (2026-07-06, contract aigen-fold-core-rest-api-20260630.md). 2-stage CRBN-VAV1 ternary pipeline formalised as POST /v1/ternary endpoint. 4 files: api/pipeline.py (new — YAML builders, CULTsum, template CIF builder, run_stage, find_model0_pdb), api/jobs.py (run_ternary_prediction — GPU selector + stage1 2-seed + CULTsum pick + template CIF + stage2 5-seed + PDB copy), api/schema.py (TernaryRequest), api/server.py (POST /v1/ternary route). Smoke PASS: all imports, stage-1 YAML (20+16 pocket, 4 contacts), stage-2 YAML (14 pocket, 0 contacts, 1 template), seeds S1=[300,16] S2=[16,123,300,42,777], TernaryRequest schema, all routes registered. Stage-2 returns all 5 PDBs (stage2_seed{N}_model_0.pdb); client picks best. OPEN: commit the 4 files + update contract status to done.'
  - 'ICML2026 PAPER FOLLOW-UP (2026-07-06, contract aigen-fold-core-mosir-coarsebind-pilot-20260706, DONE, both tracks closed). CoarseBind/TerraBind: ICML page title stale, real paper = TerraBind (arXiv 2602.07735, Terray Therapeutics/EMMI Predict) — confirmed PROPRIETARY (no code/checkpoint anywhere), so the planned affinity-null re-check does not proceed (gate=NO, zero GPU spent). MoSIR pilot (phase5/mosir_pilot.py, phase5/results_v5.md): prototype-constrained + scaffold-fold-environment-adversarial layer on top of the SAME PCA(32) the v1.1 pairwise ranker already uses. v1 attempt (no DC50 signal in encoder loss) collapsed to near-zero rho everywhere — diagnosed as a real design gap, not a fair test; v2 added a pairwise-ranking task loss into the same objective. v2 verdict = NULL: L+Zt within 0.334 vs baseline 0.442 (P=0.006 worse), L+Zt cross 0.415 vs 0.535 (P=0.058, CI spans 0), L+poolMSD within 0.365 vs 0.429 (P=0.082, CI spans 0), L+poolMSD cross 0.309 vs 0.558 (P=0.000 decisively worse). No cell beats v1.1. Scope-limited null (our approximation at n=388 on top of an already-strong baseline, not a refutation of MoSIR on its own larger benchmarks) — do not re-attempt this exact approximation.'
  - 'STRUCTURE GROUND-TRUTH validated (2026-07-06). (a) 9NFR = experimental DDB1-CRBN-glue-VAV1(SH3c) ternary; its glue = A1BYX = MRT-23227 (SMILES Cn1ccc(COc2ccc(-c3cccc([C@H]4CCC(=O)NC4=O)c3Cl)cc2)n1). So VAV1 HAS one reference ternary (corrects earlier "no experimental structure"). (b) stage-1 free-pred places VAV1 at ONE consistent pose: cross-compound median 0.4A, 96% within 5A of 9NFR, ~4% fail (validates the 2-stage templating rationale). (c) IKZF1/IKZF3/GSPT1 crystals across 10+ distinct glues: target orientation is GLUE-INDEPENDENT (0.6-2.7A) = one productive pose per target. (d) job 15504: 2-stage on A1BYX (9NFR own glue) reproduces crystal target 2.9A / glue 2.3A; MRT6160 (=VAV1_185) 2.8A; seed-consistent -> pipeline reproduces experiment + glue-independence confirmed in-house. IMPLICATION: the ~3A is a systematic Boltz-vs-crystal offset (not glue signal); ~4% outliers are real failures not alternative modes; 9NFR fixed-template would mainly fix that ~4%. CORRECTIONS (measurement artifacts fixed this session): earlier 14A/85A flung-glue (wrong-dir: 5-step trunk pass 85A is pose-independent+irrelevant; pose-cond pass 50-step docked 2-3A), 16.8A target scatter (bad-reference artifact), 18% fail (first-40 sampling; true ~4%).'
  - 'LATENT-USAGE exploration (2026-07-06, 3 parallel tracks + pose-cond 5seed). Track1 contact-gated pooling = null/harmful (cross -0.126 P=0.02; node-s mild in-dist only). Track3 static ubiquitination-geometry proxy = null (no add over latent, CI spans 0). Track2 cross-target transfer scope: clean public glue-DC50 ~68 mols (GSPT1 28 + IKZF3 36 = cleanest labels; IKZF1 standalone only 7, PROTAC-dominated -> IKZF1 = structure anchor NOT label source); value = shared ternary geometry, aux-regularizer not n-booster; real gate = GPU ternary-latent extraction for new target. Job 15376 pose-cond 5-seed-avg (388, kfs2 latent_pc388_ms5): seed-averaging does NOT significantly improve pose-cond (paired vs single Delta +0.03-0.06 within/cross, ALL CI span 0, P 0.85-0.92; in-dist flat) - poses already seed-stable 0.28A so nothing to denoise. trunk-z (pose-independent) remains cross champion 0.530; pose-cond stays within/in-dist complement even averaged. Structure-only (ligand-excluded) in-dist rho 0.39-0.46, best trunk+pose-cond 0.461; pooling moments is the lever. Scripts phase4/{structonly_n388,posecond_probe,posecond_only,poolfeats_conf,poolfeats_conf_ms5,eval_conf_ms5}.py.'
  - 'DELIVERABLES + open (2026-07-06). Downloads in /home/ubuntu/: chemprop_vav1_input.zip (388 + matched fold columns fold_scaffold/fold_random/fold_cross for fair chemprop compare, metric=OOF Spearman), vav1_docked_pdb.zip (10x stage1+stage2+9NFR, 9NFR-frame pre-aligned), vav1_9nfr_validation.zip (A1BYX+MRT6160 5seed vs 9NFR). CEO Notion report (Boltz structure-only, catalog skeleton, English ML terms): https://app.notion.com/p/3951e76c3b6081af813cca97c63f4fc0 + email body phase4/ceo_email_structonly.md + follow-up phase4/ceo_discussion_followup.md (ligand analog-leakage caveat: ligand in-dist 0.605 collapses to 0.222 at cross = leakage; structure holds). OPEN: (1) user running chemprop external compare; (2) DECISION - Notion v1.1 addendum + report leakage caveat (in-dist headline vs scaffold-OOD); (3) optional LOW-pri GPU - 9NFR/DDB1 fixed-template trunk-z re-extraction to fix ~4% outliers (expected small per findings).'
  - 'v1.1 UPGRADE (2026-07-05, phase4/results_v3.md): CROSS-scaffold ranking IMPROVED 0.383->0.558 by swapping absolute regression for a PAIRWISE ranking loss (logistic-on-PCA32-diffs, PRIMO-style). Paired-bootstrap Δ+0.173 [+0.056,+0.297] P(beats old B)=0.998; B_simple pairwise on L+Zt = 0.535 (same features, estimator swap only, P=1.000). Reproduction gate PASSED (A within 0.545 = card, old B cross 0.383 = card). WITHIN unchanged (ligand-gbdt 0.545; pairwise ties, does NOT beat). Distributional pooling (per-block mean+std+median of trunk z) adds a smaller real increment on top. Reopened the "modeling closed" call correctly: the LOSS was the one untested lever (session deep-research Q2). Artifacts phase3/v1/v1_1_B_pairwise_{poolmsd,lzt}.joblib + phase4/{poolfeats,sweep,pairwise_ranker,v1_1_model}.py + v1_model_card.md updated to v1.1. NULLS (do not retry): censoring-aware≈naive, Dmax co-train, seedbag ensemble, A/B rank-stack (HURTS cross P=0.013), PCA-dim (within only, <0.545). Block ablation: VP droppable, LP load-bearing.'
  - 'CRBN-MGD data-scout (2026-07-05 deep-research wf_73f691e9-2e0, 16 agents, adversarially verified): best data-rich transfer/benchmark target = IKZF1 (11 CRBN-glue TERNARY PDBs incl canonical 6H0F; GSPT1 runner-up 3 ternary 5HXB/6XK9/9HNE). KEY CAVEAT: adversarial verify cut raw counts 3-9x — clean PUBLIC quant labels are ALL <= VAV1 388 (IKZF1 ChEMBL ~50 quant / glue ~28; +IKZF3 pool ~70-110). Value is NOT label count; it is (i) ternary STRUCTURE ground truth VAV1 lacks (validate Boltz pose the latent is read from), (ii) label breadth (degradation DC50/Dmax curated), (iii) defensible transfer (shared CRBN + glutarimide warhead). Sources: ChEMBL v34, MGDB, MolGlueDB, CELMoD SAR SI. Full report /tmp task w1k2nqjc1 output.'
  - 'v1 (superseded by v1.1). Old B = L+mean-pool trunk-z ridge/PCA32 (cross 0.383) kept for reference at phase3/v1/v1_B_l_plus_trunkz.joblib. A (ligand-gbdt, within 0.545) UNCHANGED = still the within-scaffold ship model.'
  - 'Notion 리포트 (Reports DB, Draft): https://app.notion.com/p/3941e76c3b608108b714dc3f6fa0ca38 — describes v1 (says "modeling closed, ceiling=data"). NOW PARTLY STALE: v1.1 shows cross-scaffold had headroom (pairwise loss 0.383->0.558). NEXT(사람 or agent): add a v1.1 addendum section to the Notion report before promoting Status to Published.'
  - 'Next lever after v1.1 = DATA (cheap on-asset modeling is now exhausted: phase4 swept estimator/loss/ensemble/pooling/censoring/PCA/stacking). within-scaffold + absolute DC50 still capped by n=388 single assay. Raise via wet-lab VAV1 expansion (same assay, drops in) or external DB transfer (IKZF1/GSPT1 per scout, separate contract, assay-heterogeneity + external-access approval).'
  - 'Ops/infra: ALL GPU jobs via SLURM as kim (user hard rule; even smokes) — gpu:1 job arrays to backfill scattered free GPUs, NOT whole-node --exclusive. rootfs boltz2.py/affinity.py additive env hooks (BOLTZ_DUMP_LATENT/RETURN_LATENT_FEATS/DUMP_AFFG; backups kept; kfs2 copy only). phase4 sweep was CPU sklearn (no GPU, ran inline like phase2/3 eval). Bundles: kfs2 vav1_encoder_20260704, vav1_2stage_alldock_20260702, vav1_oracle_latent_20260703.'
contract_pointers:
  - .agent/contracts/aigen-fold-core-token-trans-bias-20260715.md
  - .agent/contracts/aigen-fold-core-raw-s-control-20260715.md
  - .agent/contracts/aigen-fold-core-cdk2-23sr-pilot-20260713.md
  - .agent/contracts/aigen-fold-core-datalever-learning-curve-20260712.md
  - .agent/plans/aigen-fold-core-datalever-learning-curve-20260712.md
  - .agent/contracts/aigen-fold-core-v12-sar-data-integration-20260712.md
  - .agent/plans/aigen-fold-core-v12-sar-data-integration-20260712.md
  - .agent/contracts/aigen-fold-core-semantic-object-layer-20260707.md
  - .agent/plans/aigen-fold-core-semantic-object-layer-20260707.md
  - .agent/contracts/aigen-fold-core-3body-mgoff-features-20260707.md
  - .agent/contracts/aigen-fold-core-ssl-interface-encoder-pretrain-20260706.md
  - .agent/contracts/aigen-fold-core-mosir-coarsebind-pilot-20260706.md
  - .agent/contracts/aigen-fold-core-9nfr-mrt-validate-20260706.md
  - .agent/contracts/aigen-fold-core-posecond-multiseed-reextract-20260706.md
  - .agent/contracts/aigen-fold-core-latent-interface-encoder-20260704.md
  - .agent/plans/aigen-fold-core-latent-interface-encoder-20260704.md
  - .agent/contracts/aigen-fold-core-vav1-degrad-head-v2-20260702.md
  - .agent/contracts/aigen-fold-core-ver2-twosite-generation-20260630.md
  - .agent/contracts/aigen-fold-core-rest-api-20260630.md
  - .agent/contracts/aigen-fold-core-ternary-benchmark-3systems-20260629.md
  - .agent/contracts/fksfold-core-template-ddb1-combo-9nfr-20260626.md
  - .agent/contracts/fksfold-core-ddb1-full-msa-9nfr-20260626.md
  - .agent/contracts/fksfold-core-ddb1-contact-early-9nfr-20260626.md
  - .agent/contracts/fksfold-core-ddb1-fullstk-9nfr-20260626.md
  - .agent/contracts/fksfold-core-ddb1-4chain-9nfr-20260626.md
  - .agent/contracts/fksfold-core-contact-fix-9nfr-20260626.md
  - .agent/contracts/fksfold-core-ddb1-forcetrue-9nfr-20260626.md
  - .agent/contracts/fksfold-core-assembly-closure-generation-20260623.md
state: active
---
# AIGEN-Fold Core Status

2026-07-15 session (Boltz-2 latent teardown + 3 control/candidate
experiments DONE, VAV1 degrad-head lineage): see remaining_actions[0].
6-agent parallel read of upstream Boltz-2 source cataloged 66 tensors beyond
the 4 already used in v1.1 (Zt/Zt_z, Zpc/Zpc_z, Aff/Zaffg), tagged by
extraction cost; published as an interactive HTML teardown + Notion report.
Ran 3 follow-up DC50-signal checks through the standing rank_harness CV:
(1) free-tier confidence/affinity fields re-parsed from existing 388-compound
outputs -- mostly null, but caught a real methodology bug (large_scaffold
GroupKFold hallucinates strong spurious correlations for raw un-PCA'd
features; verify with a direct between/within-scaffold decomposition before
trusting any such number going forward); (2) raw pre-recycling s_inputs
(contract aigen-fold-core-raw-s-control-20260715.md) -- modest signal, does
NOT reproduce Zt_z's cross-scaffold signature, so v1.1's "structure adds
value" interpretation survives this control; (3) token_trans_bias
(contract aigen-fold-core-token-trans-bias-20260715.md) -- real signal
comparable to Zt_z (within-scaffold rho +0.31-0.32, CI-separated), the one
candidate worth a formal follow-up (redundancy-vs-Zt_z test through v1.1's
actual PCA+pairwise pipeline, not yet run). Nothing shipped to v1.1 itself.
Open: redundancy test, cleanup of the 132GB token_trans_bias npz dir if not
pursued, whether to fold any of this into the v1.1 model card.

2026-07-14 session, continued (CDK2/23SR pilot, DDB1-augmented template +
IKZF1 root-cause DONE): see remaining_actions[0]. Added IKZF3/9UUM to the
sweep (8th target, worst despite gap-free CRBN -- confirms size/rigidity
over completeness). Tested giving stage-2 a 3-chain DDB1+CRBN+target
template (custom-built YAML, bypasses build_stage2_yaml's 2-chain limit):
rescued VAV1 (16.77->8.97A) and IKZF3 (22.92->2.26A, worst-of-8 to
best-of-8) but NOT IKZF1 (18.78->18.99A) -- confirmed real via full 5-seed
panels, not seed luck. Root-caused WHY IKZF1 resists: per-residue error
breakdown found CRBN's own N-domain and C-domain(CULT, the ligand-pocket
domain) fit well individually (1.52A/4.82A) but are hinge-rotated 83.4 deg
relative to each other -- ruled out wrong-ligand, altloc duplicate atoms,
and crystal-copy heterogeneity as causes. Decisive test: 6H0F's true
hinge angle is 93.4 deg from the COMMON conformation shared by all other
7 structures (which agree to within 1.5-11.8 deg of each other); the
model's own prediction sits only 3.0 deg from that common conformation --
i.e. it ignored 6H0F's rare true template and reverted to its learned
prior. Same phenomenon this slice already documented once before for
VAV1-CRBN geometry (DDB1-series work) -- independently reconfirmed here.
Net conclusion: 7/8 sweep failures are a fixable constraint-completeness
gap (DDB1 fixes them at inference time, no retraining); IKZF1 is a
deeper prior-dominance limitation (soft template guidance loses to a
strong data-driven prior on rare true conformations) -- a
design/training-objective question, not a data-volume one. Session
paused here on user request; write-up/canonical-adoption decisions open.

2026-07-14 session (CDK2/23SR pilot, generalization sweep + mutant-panel
validation DONE): see remaining_actions[1] (was [0]). Three follow-ups on the
2026-07-13 32-compound batch: (1) traced the ACTUAL diffusion sampling loop
(this-process-only monkeypatch, zero rootfs edits) to show the template's
influence is present from step 0, not gradually emerging. (2) Swept 6 more
targets (VAV1, IKZF1, NEK7 on 2 different crystals, CK1a, PRDM1) to test
generalizability: REFUTED "CRBN must be gap-free" (IKZF1 is gap-free yet
worst of all 7); found target domain SIZE is the real, near-monotonic driver
(298aa=2.64A ... 32aa=18.78A) -- NEK7 on 2 crystals with different CRBN gaps
gave nearly identical results (4.60/4.28A), isolating size from gap
location. (3) Validated the 32-compound batch against B11's real alanine-scan
mutant panel (not just RMSD): predicted and ground-truth interface distances
agree after fixing a numbering-frame bug, EC50 fold-change anti-correlates
with interface distance as expected, and the top hotspot (E57) sits at a
consistent CRBN distance across all 32 predicted compounds. Artifacts:
/home/ubuntu/cdk2_23sr_diffusion_trajectory/.

2026-07-13 session (CDK2/23SR structure pilot, root cause found + 32-compound
batch DONE): see remaining_actions[0] for full detail. First non-VAV1 target
through the 2-stage pipeline. 9 stage-1-template config variants all failed
(12-42A CDK2-RMSD miss vs 23SR ground truth); decisive diagnostic showed
stage-2 is sound and the true fault was stage-1 never producing an accurate
template. Fix: skip stage-1, template stage-2 directly from 23SR ground truth,
swap only the ligand per compound. Ran all 32 SI-CSV compounds this way:
2.54-2.79A CDK2-RMSD series-wide (matches VAV1/9NFR benchmark), glutarimide
anchoring 0.61-0.84A, 0/32 outliers. OPEN DECISION: adopt into canonical
config, and what to do next with the 32 predicted poses.

2026-07-12 session (data-lever learning-curve diagnostic, DONE): see
remaining_actions[0] for full detail. Ran the diagnostic the phase8 flat
point could not settle -- the SLOPE of a fixed-test-set learning curve
(test-rho vs n_train), zero-GPU on the already-extracted 505 features +
117 poses, plus three verification-driven cleanups. RESULT reverses the
standing "same-assay data is the lever" call: the learning curve is FLAT
in both CV regimes across a 4.4x data range (cross fixed-test rho
0.578/0.578/0.547/0.557/0.523 at n_train 100/200/300/388/443; within
0.472/0.523/0.462/0.468/0.502), the correct within champion (ligand-gbdt
on L, not the poolMSD-pairwise phase8 used) moves +0.005 P=0.578 with the
+117 data, and bridge_span_mean's +0.028 n=388 headroom evaporates to
+0.021 [-0.015,+0.058] at n=505. The held-out-117 OOF (rho 0.497/0.480)
shows the model still generalizes, so what is tapped is the
structure-as-ranking-feature ceiling (~0.55 cross), not the model. At
n~505 with the current pipeline, incremental same-assay data at this scale
is not expected to move the ranker. Ship model UNCHANGED (v1.1). Full
writeup phase9/results_v9.md, which supersedes two v8 cross/within numbers
(see remaining_actions[0]). No approval gate open.

2026-07-12 session (v1.2 SAR data integration, DONE): see remaining_actions[0]
for full detail. Took the 2026-07-11 curated 117-compound SAR expansion
(388->505) all the way through the modeling pipeline end to end: joint
scaffold-CV fold reassignment over all 505, 117/117 docked via SLURM (kim
account) through the unchanged 2-stage Boltz ternary pipeline, a second
cheap GPU pass to dump Boltz trunk latents (discovered mid-plan that the
v1.1 poolMSD feature needs these, not derivable from the poses alone),
feature-build with column schema independently verified identical to the
existing 388 tables. Evaluated the UNCHANGED v1.1 model spec on 505 vs
388-only with a 3-condition paired-bootstrap design. RESULT:
flat/inconclusive -- cross-scaffold delta -0.034 [-0.133,+0.049]
P(A>B)=0.240, within-scaffold delta +0.027 [-0.022,+0.077] P(A>B)=0.867,
neither CI-separated. 4 caveats (censoring-cap mismatch 388-vs-117,
AIG22071 A/B duplicate-structure discordant DC50, 3 non-canonical-warhead
compounds flagged not dropped, and this contract's own finding that
`rank_harness.cv_large_scaffold`'s `fold` parameter is accepted but never
used -- so fold reassignment only affects within-scaffold numbers, not
cross) are stated inline next to the reported numbers in
`phase8/results_v8.md`, not buried. This contract's success criterion
(data incorporation confirmed + honest report, not a performance gate) is
MET. Ship model UNCHANGED: v1.1 (L+poolMSD pairwise, cross 0.5584). The
v1.2 ship/no-ship decision is explicitly out of scope here (contract
Non-Goals) -- a separate open decision for the user; the flat result
argues against replacing v1.1 on performance grounds alone but that call
is not this contract's to make. Full writeup `phase8/results_v8.md`.

2026-07-11 session (SAR data curation + SMARTS bug fix, DONE): see
remaining_actions[0] for full detail. Two independent findings acted on this
session: fixed a SMARTS bug in the SSL-pretrain corpus filter (mislabeled
"glutarimide" was actually succinimide; corpus corrected 2,127->3,672,
ESCAPE verdict unaffected, all published docs corrected in place), and
curated 117 new same-assay DC50-labeled VAV1 compounds from user-supplied
20260701_VAV1_SAR.xlsx (phase0 388->505, +30.2%). Independently
adversarially verified (3-lens Workflow, zero pipeline bugs). Standing lever
("same-assay data expansion") now has real, curated, verified data behind
it -- next step (not yet done, would need its own contract) is deciding
whether/how to fold vav1_dataset_extended.csv into an actual v1.2 retrain
(needs the 4 open decisions in remaining_actions[0] resolved + full
scaffold-CV fold reassignment over all 505 first).

2026-07-08 session (semantic-object-layer, DONE): shipped the corrected successor
to the SSL/semantic-object detour — turned the VAV1-hardcoded 2-stage ternary
pipeline (api/pipeline.py) into a target/E3-parametric input contract +
SemanticObject attribute record (api/ternary_config.py, api/semantic_object.py),
extend-not-rebuild, explicitly NOT an efficacy model. 4 commits (eef73be/9850575/
1267f4f/6e8beb2 on branch platform-versioning-r20260417). Proven: VAV1 path
byte-identical (golden lock), non-VAV1 config flows through (parametric), pooled
features match Zpool_388.csv ~1e-14, v1.1 cross 0.5584 unperturbed. Live-truth
verify: phase6/downstream_regression.py. Next (both optional/gated): nested-CV
confirm bridge_span_mean → maybe ship v1.2 (from the 3body workstream); CDK2
pilot when real seq+pocket+glue-series data exists. Standing lever unchanged:
same-assay VAV1 data expansion. Detail in remaining_actions[0]. No approval gate open.

2026-07-07 session (SSL-interface-encoder-pretrain, closed/superseded): started
building a self-supervised pretraining corpus (ChEMBL CRBN-glue, warhead-
filtered to 2,127 [CORRECTED 2026-07-11: SMARTS bug in pull_chembl_crbn.py's
"glutarimide" pattern (was matching succinimide, 5-ring, not glutarimide,
6-ring) meant the true filtered count is 3,672; fixed + corpus re-filtered,
see contract aigen-fold-core-ssl-interface-encoder-pretrain-20260706.md
Notes. ESCAPE verdict unaffected (both far below pretraining-scale corpora);
GPU latents (job 16178, below) were extracted from the old 2,127, not the
corrected 3,672]) to let a full-input encoder consume the raw interface
latent without n=388 overfitting (the third untested route after learned-
encoder and set-kernel both failed). Latent extraction landed (job 16178,
2,089/2,090, from the pre-fix corpus). Mid-execution the user proposed pivoting to a "semantic object
model" (guide_score + Boltz affinity distillation); before building new infra,
checked whether a usable continuous guide_score exists at all — it does not
(CULTsum and Boltz's own confidence output both collapse to the same near-
binary placement-success detector, rho=-0.603 with each other, null vs
logDC50). Pivot not pursued. v1.1 stays the shipped model; next lever is data,
not more structural feature engineering. Full detail in remaining_actions[0].

2026-07-06 session (REST API ternary standard): 2-stage CRBN-VAV1 ternary prediction
pipeline formalised as POST /v1/ternary API endpoint. Stage-1 free prediction (pocket
20+16 residues, 4 soft contacts at 5Å, seeds 300+16) → CULTsum best-seed selection →
protein-only mmCIF template (chain C stripped) → Stage-2 templated docking (CRBN pocket
14 residues + template, seeds 16/123/300/42/777). All 5 stage-2 PDBs returned as
stage2_seed{N}_model_0.pdb. Smoke PASS (imports, YAML structure, schema, routes).

2026-07-06 session (structural ground-truth + latent-usage): validated the 2-stage
pipeline against the 9NFR experimental ternary (glue A1BYX/MRT-23227) — 2-stage on
9NFR own glue reproduces the crystal target to 2.9A, MRT6160 2.8A, both seed-consistent
(job 15504). stage-1 places VAV1 at one consistent pose (96% within 5A of 9NFR, cross-
compound median 0.4A). IKZF/GSPT1 crystals across 10+ glues show target orientation is
glue-independent (0.6-2.7A) -> VAV1 pose is one glue-independent site, ~4% pipeline
failures are real not alternative modes. Latent-usage: contact-gated pooling + static
geometry proxy = null; pose-cond 5-seed averaging (job 15376) = NOT significant (poses
already seed-stable); trunk-z stays cross champion 0.530. Deliverables + CEO Notion
report shipped (see remaining_actions). Fixed 3 measurement artifacts this session
(details in remaining_actions[0]).

As of 2026-07-05. THREE experiments complete: v2 does-structure-add (phase2/results_v2.md)
+ learned interface-encoder (phase3/encoder_results.md) + estimator/loss/pooling sweep
(phase4/results_v3.md). v1.1 shipped (phase3/v1/ + v1_model_card.md updated).
**phase4 found a real cross-scaffold WIN**: pairwise ranking loss lifts cross 0.383->0.558
(P=0.998), within unchanged (ligand-gbdt 0.545). This corrected the earlier "modeling
closed / ceiling=data" call — it held for within + absolute prediction, but cross-scaffold
ranking had headroom the LOSS function was leaving on the table (the one lever v2/encoder
never tested). Also ran a CRBN-MGD data-scout (wf_73f691e9): IKZF1 = best structure-anchored
transfer target (11 ternary PDBs), but verified clean public labels are all <= 388.
No open GPU jobs (phase4 was CPU sklearn, inline). Notion report describes v1 = now partly
stale, needs a v1.1 addendum before Publishing.

## Prior lane — structure-accuracy fix (assembly-closure → DDB1 series), superseded not closed (reconciled 2026-07-06)

Before the latent-interface work (v2/encoder/v1.1), this slice ran a *structure-accuracy* lane
trying to fix VAV1 ternary placement itself, rather than predict potency around a possibly-wrong
pose. That lane never got an explicit close-out doc — it just stopped getting touched once the
latent approach showed trunk-z works **without** needing accurate pose. Timeline, now reconciled
in contract/plan bookkeeping (several were stuck at `approved`/`pending` despite the work having
actually finished):

- **assembly-closure-generation (06-23→06-25, contract now `done`)**: CRLClosurePotential
  (gradient) + CRLClosureIK (proposal) tried to force VAV1 lysine → E2~Ub cone closure at
  generation time. PASSED on 9OTY (DockQ 0.738) but FAILED on 9Q33/9NFR/MRT6160 — Boltz's prior
  for the novel VAV1-CRBN geometry overrides the correction every step. Verdict: **DDB1 co-input
  required** (`analysis/crl_integrative/assembly_closure_results_20260623.md`).
- **DDB1 series (06-26, direct follow-up on that verdict)** — 8 contracts testing DDB1 co-input
  variants on 9NFR. Progressively better CRBN global-orientation fixes:
  contact_early/4chain/fullstk/contact-fix all `done`. **template-ddb1-combo (contract fixed
  `approved`→`done` today; plan already showed all tasks done)** = best result of the whole
  program: template-conditioning + DDB1 single-seq + force:true contacts together drove
  CRBN_RMSD from 20-25Å → **9-11Å** (6/6 seeds <15Å gate) and got ARM-2 cone_dist to **3.94Å**,
  0.44Å short of the 3.5Å near-attack threshold. **ddb1-full-msa (contract+plan fixed
  `approved`/`pending`→`done` today)**: job 8413 actually ran and was scored — full MSA alone
  made CRBN_RMSD worse, no bookkeeping had caught up to that result until now.
  **ddb1-forcetrue (contract+plan fixed `approved`/`pending`→`done` 2026-07-06)**: job 8442 ran
  2026-06-26 but scoring was never done until reconciled today. Scored result: hypothesis FAIL —
  only 3-4/12 force:true contacts actually satisfied, CRBN_RMSD unchanged (20.0-22.3Å) vs the
  force:false baseline. force:true alone does not fix DDB1 orientation; it only helps combined
  with template conditioning (as template-ddb1-combo already showed). Doc:
  `analysis/crl_integrative/ddb1_forcetrue_9nfr_results.md`.
- **ternary-benchmark-3systems (06-29, contract `done`)**: ran the same pipeline on BRD4/IKZF1 to
  check if VAV1's poor DockQ was pipeline-general or VAV1-specific. BRD4=0.325, IKZF1=0.489 vs
  VAV1=0.084 → confirmed VAV1-specific, validating that the DDB1 lane's target was real.
- **Why it stopped, not "why it failed"**: the DDB1 lane was still making real progress (3.94Å
  from a 3.5Å gate) when v2/encoder work (06-30 onward) showed **trunk-z ranking doesn't need an
  accurate pose at all** — the pose-independent latent beats the pose-conditioned one. That made
  pushing CRBN/cone geometry to <3.5Å no longer load-bearing for the potency-ranking goal, so
  attention moved to the latent lane and DDB1 was never explicitly declared done/paused/killed.
  If VAV1 ternary *structure accuracy* itself becomes a goal again (e.g. for the CRBN-MGD
  transfer-learning idea, which wants Boltz pose validated against real ternary structures),
  template-ddb1-combo's "next steps" (seed-expand ARM-2, or raise guidance_weight to 2.0-3.0) are
  the resume point, not a fresh start.

## Verdict — learned encoder (phase3, 2026-07-05)
ESCAPE VALVE. A learned encoder over the FULL interface z (BlockPMA-X 34k, design
panel) does NOT beat the mean-pool baseline at n=388 on cross-scaffold — significantly
WORSE (best 0.178 vs mean-pool Zt_z 0.363, bootstrap P(worse)=0.985). Within-scaffold it
beats mean-pool (0.398 vs 0.290) but loses to ligand 0.545. Attention inert (mean-only
ties full); fusion(pose-cond+affinity) hurts; stronger reg/drop-VP dont rescue. Ceiling =
Boltz features + sample size, not the pooling head. v1 ship model = L + mean-pool trunk-z;
next lever = cross-program transfer (more n). Full ablation table in encoder_results.md.

## Verdict — v2 structure-adds (results_v2.md)
- Structure ADDS over ligand QSAR, but only CROSS-scaffold and only via the cheap
  pose-INDEPENDENT TRUNK latent z. Powered 388 large-scaffold (n=135):
  L 0.249, Zt_z 0.363, **L+Zt_z 0.383** (Δ+0.134, paired-bootstrap 95% CI
  [+0.013,+0.267], P(Δ>0)=0.986). Within-scaffold (n=388) ligand gbdt 0.545 wins.
- Escalations did NOT pay off: pose-conditioned latent (s_conf/z_conf via
  return_latent_feats) only ties ligand within-scaffold (Zpc_z 0.242 vs 0.241),
  redundant (L+Zpc_z ≤ L); predicted affinity null for DC50 (direct ρ 0.138/-0.024);
  affinity g (384-d) 0.14-0.16. 143-oracle varying-pose set too scaffold-diverse/small
  to power cross-scaffold (n=27). Trunk z needs NO pose → the pose-generation program
  is unnecessary for this ranking task.
- v1 model = **L + trunk-latent-z** (ligand for within-series potency, trunk z for
  cross-chemotype generalization).

## Artifacts
- Scripts + results: `.agent/scratch/vav1_degrad_head/phase2/` (features_ligand/
  latent/affinity/affg, ablation_final, rank_harness, results_v2.md; CSV artifacts).
- Latents (kfs2): `vav1_2stage_alldock_20260702/latent` (388 trunk) +
  `vav1_oracle_latent_20260703/{latent,latent_pc,latent_affg,latent_out_aff}`
  (143 oracle trunk / pose-cond / affinity-g / affinity-json).
- Rootfs engine hooks (kfs2 COPY only, backups kept, flag-off byte-identical):
  boltz2.py BOLTZ_DUMP_LATENT + BOLTZ_RETURN_LATENT_FEATS + BOLTZ_DUMP_AFFG;
  affinity.py _g_dump. Affinity stock bug worked around: --diffusion_samples_affinity 1.

## Foundation (codex strong2, 2026-07-02)
- strong2 DC50 sweep + logbook at `/home/ubuntu/ablation_411_nosteer_20260701/`. 2-stage
  stage-1 REUSES the strong2 S2_LON Pfull d5 recipe (the only one that seats VAV1 productively).
- Limit = learned-prior gap, not architecture. Lever = YAML contact conditioning. DockQ ≠ potency.

## Approval gates
- T6 SLURM latent pass (only if Z pursued): kim `--qos=normal` (NOT batch — invalid as of 07-02).
- boltz2.py latent hook lives in ROOTFS copy only (kfs2), not the live WIP repo (backup .prehook_bak).
