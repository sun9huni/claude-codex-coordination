# aigen-fold-core — self-supervised pretraining of the interface-latent encoder

Status: done
Slice: aigen-fold-core
Topic: ssl-interface-encoder-pretrain
Date: 2026-07-06
Approval: requested 2026-07-06; approved by: user (2026-07-06 "승인"); RESUMED 2026-07-07 (see below)

## FINAL VERDICT (2026-07-07) — ESCAPE, independently re-verified

The original question — does self-supervised pretraining let the full-input
interface encoder beat the pooling baseline at VAV1 n=388, without
overfitting — was actually tested end to end (Tasks 4/6/7/8, resumed after
the guide_score pivot below was investigated and dropped). Real result,
directly re-derived and independently spot-checked against the raw OOF CSVs
and against `phase4/sweep.py`'s own `oof_pairwise()` (not just trusted from
the subagent's report):

- Cross-scaffold (large_scaffold, n=135), same architecture/hyperparameters/
  seed/CV-splits, only the transplanted TokenProj init differs: no-pretrain
  control rho=-0.098 -> pretrain+finetune rho=+0.191. Paired-bootstrap delta
  +0.289, 95% CI [+0.072, +0.509], P(delta>0)=0.994 — a REAL, CI-separated
  positive effect from pretraining. The "buy representational capacity with
  unlabeled data" mechanism is genuine, not a null result.
- But: vs the historical no-pretrain BlockPMA-X baseline (0.178, 5-seed
  ensemble): delta +0.014, CI [-0.112,+0.136] spans zero — pretrain+finetune
  only reaches noise-level parity with the OLD, already-superseded
  supervised-only encoder, not a decisive win over it.
- vs the v1.1 pooling+pairwise champion (0.558, reconstructed to 0.5584,
  independently re-verified this session to match): delta -0.361, CI
  [-0.544,-0.189] — clearly, decisively trails.
- **ESCAPE per the contract's literal success criteria** (PASS required BOTH
  beating 0.178 by a CI-separated margin AND landing within noise of/beating
  0.558 — neither condition met, and the ESCAPE condition — "still trails
  0.558 by a CI-separated margin" — is met).

Honest interpretation: pretraining works in *direction and in kind* (real,
well-isolated generalization signal, exactly the cross-scaffold-only /
within-scaffold-flat signature the theory predicts) but the corpus (2,089
compounds, ~5.4x VAV1's 388) is 2-3 orders of magnitude too small to close a
0.37-rho gap to the pooling champion — ESM/AlphaFold-scale pretraining
operates on millions of sequences/structures, not low thousands. This is a
genuine, informative answer to give the CEO: the method is real and the
theory is correct, but the sub-population regime we can access here is
much smaller than would be needed to see a decisive within-encoder win
over the already-strong pooling+pairwise baseline. **v1.1 (pooling +
pairwise ranking, cross-scaffold rho=0.558) remains the shipped VAV1 DC50
model.** Full writeup: `phase6/pretrain_results.md`. Standing next lever
unchanged: same-assay VAV1 label expansion, not further architecture or
pretraining investment at this corpus scale.

## Progress note (2026-07-07, RESUMED, pivot investigation superseded by the above)

The original question (does pretrain+finetune let full-input beat pooling)
was initially left untested — only the adjacent guide_score/semantic-object-
model PIVOT was tested and rejected (see Notes below, kept for record). User
confirmed the original question was still the one to answer, so it was
resumed and completed (see FINAL VERDICT above) once all prerequisites
existed (2,089-compound corpus + latents + code-reviewed LP sub-encoder from
Tasks 1/2/3/5).

## Notes — pivot investigation (2026-07-07, kept for record, does NOT close this contract)

Plan executed Tasks 1/2/3/5 (corpus pull, YAML build, latent extraction, LP
sub-encoder architecture) then STOPPED — the user proposed a different framing
mid-execution ("semantic object model": predict a guide_score + Boltz affinity
value from a Boltz-compatible input object, rather than pretrain an interface
encoder). Tasks 4/6/7/8 (raw-token extraction, pretraining loop, fine-tune,
OOF eval) were never run; see plan file for per-task detail.

The new framing's precondition (a usable continuous "guide_score") was checked
before any new infra was built, per this slice's diagnose-before-scale norm.
Two independent zero-GPU checks on the existing VAV1 388 2-stage outputs:
- CULTsum (the only guide-style object with any demonstrated cross-item use,
  from `AIGENFold/api/pipeline.py`): 91% of compounds cluster in a 9.4-9.7Å
  band (near-zero variance), 4-9% form a large outlier tail (up to 82.6Å);
  seed-to-seed agreement is high (rho=+0.897, real not noise) but correlation
  with logDC50 is null (rho=+0.069, p=0.176).
- Boltz's own confidence output (ipTM/pLDDT/etc, already computed for free):
  identical shape (e.g. ipTM p25-p75 = 0.962-0.967, min=0.669), also null vs
  logDC50 (rho=-0.117), and correlates STRONGLY with CULTsum (rho=-0.603,
  p=7.6e-40) — i.e. these are not two independent structural-quality axes,
  they are two windows onto the SAME phenomenon (did stage-1 placement
  succeed, ~91-96% yes / ~4-9% fail), which itself is orthogonal to potency.

Conclusion: no continuous structural "guide" signal currently exists in this
pipeline's outputs to serve as a distillation teacher. Building the proposed
semantic-object-model infra on top of CULTsum or Boltz confidence would just
re-derive the already-known placement-success/failure gate at higher cost.
The "semantic object model" direction is NOT pursued further as originally
conceived. CDK2 (proposed downstream target) confirmed out of scope for now
per user.

Reusable byproducts kept (not wasted): `phase6/crbn_corpus_raw.csv`
(warhead-confirmed CRBN-glue compounds, ChEMBL-sourced; **correction,
2026-07-11**: originally reported/filtered as 2,127 compounds using a
`CRBN_WARHEAD_SMARTS` glutarimide pattern (`O=C1CCC(=O)N1`) that is actually
a 5-membered succinimide ring, not the true 6-membered glutarimide
(`O=C1CCCC(=O)N1`); fixed in `phase6/pull_chembl_crbn.py`, corpus
re-filtered from the same unfiltered pull — corrected count is **3,672**
(true-glutarimide 3,657 OR phthalimide 2,087; see
`phase6/verify_smarts_fix.py`). The pre-fix file is kept for audit at
`phase6/crbn_corpus_raw_PRE_SMARTS_FIX_buggy_2127.csv`. This does NOT change
the ESCAPE verdict below — the conclusion turned on corpus magnitude
(low-thousands) vs the millions typically used for self-supervised
pretraining, which holds at 2,127 or 3,672 alike. It DOES mean the GPU
latent extraction below (job 16178, kfs2 bundle
`vav1_crbn_pretrain_corpus_20260706/latent/`, 2,089/2,090 latents) was run
against the OLD, smaller, mislabeled-filter corpus, not the corrected 3,672
— extracting latents for the corrected delta would need a new GPU job if
this direction is ever revisited.), kfs2 bundle
`vav1_crbn_pretrain_corpus_20260706/latent/` (2,089/2,090 binary CRBN+glue
trunk-z latents, job 16178, computed from the pre-fix 2,127 corpus — see
correction above), `phase6/Zpretrain_LP.csv` (LP-block pooled features for
those 2,089 compounds), `phase6/pretrain_model.py` (standalone LP
sub-encoder architecture, code-reviewed, untested on real data),
`phase6/cultsum_388.csv` + `phase6/confidence_388.csv` (the two zero-GPU
checks above, for future reference — do not re-derive these numbers, cite
them). v1.1 (pooling + pairwise ranking, cross-scaffold rho=0.558) remains
the shipped, unchanged VAV1 DC50 model. Standing next lever reaffirmed:
same-assay VAV1 wet-lab data expansion, not further structural feature
engineering — this session tested 4 independent structural-signal directions
(learned encoder, set-kernel, CULTsum, Boltz confidence) and all 4 hit the
same n=388 ceiling.

## Purpose

Answer the CEO's question concretely: is there a way to consume the FULL
interface latent (no mean/std/median pooling) at n=388 without overfitting?
Two zero/low-cost tests this session already ruled out two of the three
known routes:
- Learned full-input encoder, supervised only (BlockPMA-X, contract
  `aigen-fold-core-latent-interface-encoder-20260704.md`): OVERFITS —
  cross-scaffold 0.178 vs pooling 0.363.
- Zero-parameter full-input consumption (set-kernel / MMD over raw LP/VP/LV
  tokens, this session, `phase4/set_kernel_full_input.py`): FAILS WORSE —
  cross-scaffold rho NEGATIVE for every block (-0.27 to -0.45); ruled out
  scale-dominance via per-channel standardization (still -0.45).

The third, untested route: pretrain the SAME encoder architecture
self-supervised (no DC50 labels) on a much larger corpus of CRBN-glue
BINARY structures, so its parameters are constrained by structure instead
of by 388 labels, THEN fine-tune on VAV1 388. This is the standard
"buy representational capacity with unlabeled data" pattern (ESM/AlphaFold-
style pretrain-then-finetune).

## Current State

- v1.1 champion (pooling + pairwise loss) stays the number to beat:
  within 0.545, cross-scaffold 0.558 (`phase4/results_v3.md`).
- BlockPMA-X architecture + training loop already exist and work end-to-end:
  `phase3/{interface,build_pairs,data,model,train,eval_encoder}.py`.
- Binary CRBN+glue latent-extraction pipeline is proven TODAY (job 15583,
  `vav1_crbn_binary_latent_20260706/`, 506 compounds in ~20 min on 8 GPU) and
  is the correct extraction target for a pretrain corpus: CRBN + glue only,
  no neosubstrate needed, matches the LP block (ligand x CRBN pocket) already
  shown to be the load-bearing, target-agnostic signal.
- ★CORRECTED PREMISE (checked this session, do not re-cite the old number):
  DeepTernary's "~3.8만" (22,302 MolecularGlue + 16,241 PROTAC) corpus is
  NOT a CRBN-glue dataset — `data/MolecularGlue/complex.txt` /
  `data/PROTAC/complex.txt` are generic PDB_chain_chain_ligand triples from
  ANY protein-protein-small-molecule complex in the PDB, used to train
  DeepTernary's own docking model. CRBN essentially does not appear as a
  chain in this set (fragmap slice found this independently in June;
  re-confirmed by inspecting the files directly 2026-07-06). Using it as-is
  would repeat the exact PCA-domain-contamination mistake caught earlier
  this session (GSPT1 aux test) at much larger scale. REJECTED as the
  pretrain corpus (user decision 2026-07-06).
- ChEMBL scouted instead (2026-07-06, MCP `mcp__claude_ai_ChEMBL`): CRBN is
  richly annotated as ~299 distinct targets (single protein CHEMBL3763008 =
  1432 activities; PLUS ~280 CRBN-neosubstrate PPI/ternary targets covering
  many chemotypes beyond IKZF1/GSPT1/IKZF3 — e.g. Cereblon/BRD4 = 911
  activities, Cereblon/Ikaros = 309, Cereblon/BRD4+DDB1 = 166,
  Cereblon/BRD4+CUL4A = 37, and ~275 more targets not yet sized). Realistic
  corpus size after de-dup by `molecule_chembl_id` + drug-likeness filtering
  (drop solvent/control entries like DIMETHYL SULFONE) is expected to land in
  the **low thousands** (order of magnitude 1,000-5,000 unique CRBN-engaging
  compounds), not tens of thousands. This is the honest number to give the
  CEO — meaningfully bigger than 388 (roughly 3-15x), not "3.8만".

## Scope

1. **Corpus assembly (zero-GPU)**: pull bioactivity for every CRBN-tagged
   ChEMBL target (~299, single-protein + PPI/complex), dedup molecules by
   `molecule_chembl_id`, keep drug-like entries (filter obvious solvents/
   fragments/controls), canonicalize SMILES. Optionally supplement with
   PROTAC-DB glutarimide-warhead entries if easily scriptable. Output: one
   compound list (SMILES only, CRBN sequence is fixed/shared, no neosubstrate,
   no potency label needed) + a size/composition report before spending GPU.
2. **Latent extraction (GPU, kim qos=normal)**: run the SAME CRBN+glue binary
   YAML + latent-dump pipeline used today (`vav1_crbn_binary_latent_20260706`)
   on the assembled corpus. Output: LP-block (ligand x CRBN pocket) raw
   trunk-z tokens per compound, same format as `phase3/pairs/*.npz`.
3. **Self-supervised pretraining (GPU or CPU, small model)**: extend
   `phase3/model.py` (BlockPMA-X) with a pretext task that touches no DC50
   label — masked-token reconstruction on the LP token cloud and/or
   contrastive (same-compound-different-seed vs different-compound). Train
   on the full pretrain corpus.
4. **Fine-tune + evaluate**: initialize from the pretrained encoder, fine-tune
   on VAV1 388 with the existing pairwise-ranking objective
   (`phase4/pairwise_ranker.py` style loss), scaffold + large-scaffold OOF
   Spearman with paired-bootstrap CI vs the v1.1 champion (0.558) and vs the
   no-pretrain BlockPMA-X baseline (0.178).

## Out of scope

- Neosubstrate-specific / ternary modeling for the pretrain corpus — binary
  CRBN+glue only (matches today's proven pipeline; ternary would need a
  per-target neosubstrate sequence and multiplies GPU cost for no clear gain
  since LP is the target-agnostic block).
- The generic DeepTernary ~3.8만 PDB corpus — rejected above (domain mismatch).
- IKZF3 label-based transfer-pilot extension — separate, already-deferred
  decision (`aigen-fold-core-crbn-transfer-pilot-20260706.md`).
- Any change to the live WIP Boltz repo; engine reuse stays read-only against
  the existing kfs2 rootfs copy.
- A second pretrain stage on the generic PDB corpus (the "hybrid" option) —
  not pursued unless the CRBN-only pretrain shows a clear positive signal
  first.

## Triggers matched

- SLURM submission (GPU) — corpus latent extraction, kim `--qos=normal`.
  Expected scale: linear extension of today's proven 506-compound/~20min/8GPU
  binary run to an estimated 1,000-5,000 compounds — low single-digit GPU-hours,
  NOT the "3.8万 forward passes" scale that the original (wrong) premise implied.

## Success criteria

- **PASS**: pretrained+fine-tuned encoder's large-scaffold (cross) OOF Spearman
  on VAV1 388 beats the no-pretrain BlockPMA-X baseline (0.178) by a
  CI-separated margin, AND is within noise of or beats the v1.1 pooling+
  pairwise champion (0.558) — i.e. full-input consumption becomes competitive
  once the encoder has non-label-derived structural prior.
- **ESCAPE (documented, not failure)**: if fine-tuned cross-scaffold rho still
  trails 0.558 by a CI-separated margin, conclude that a pretrain corpus of
  this size (low thousands) is insufficient to rescue full-input consumption
  at n=388 — record the corpus-size finding itself (real N is 3-15x VAV1, not
  100x) as the answer to "why doesn't more data fix this" and stop; v1.1
  pooling stays the shipped model.
- Verification: results doc (`phase3/pretrain_results.md` or equivalent) with
  an OOF table (pretrain+finetune vs no-pretrain BlockPMA-X vs v1.1 pooling
  champion) + paired-bootstrap CI, plus the final corpus size/composition
  actually used (so the CEO gets an honest number, not the corrected-away
  38k figure).

## Resource budget

- Corpus assembly: zero-GPU, ChEMBL MCP + local scripting.
- Latent extraction: kim `--qos=normal`, gpu:1 array (same shape as job
  15583), expected 1-5k compounds -> low single-digit GPU-hours. Output to
  a new kfs2 bundle (ubuntu-owned, chmod 777 for kim writes), NOT kfs5/kfs6
  (both >=98% full).
- Pretraining + fine-tuning: small model (<=100k params per BlockPMA-X
  precedent) -> CPU or single-GPU, sweep-able cheaply if useful.
- GPU is abundant once justified (per standing guidance) — once the corpus
  size is confirmed in Task 1, scale extraction width generously rather than
  running a slow narrow array.

## Rollback plan

- All new artifacts confined to a new kfs2 bundle (e.g.
  `vav1_crbn_pretrain_corpus_20260706/`) + `.agent/scratch/vav1_degrad_head/
  phase3/` scratch scripts. Revert = `sudo -u kim scancel <jobid>; rm -rf
  <new kfs2 bundle>`. Read-only against existing VAV1 388 latents/models and
  the v1.1 shipped model — nothing about the current champion changes unless
  this contract's PASS criterion is met and a follow-up promotion decision is
  made separately.

## Progress log

- 2026-07-06: /brainstorm. User picked "CRBN-glue binary corpus, newly
  collected" over "DeepTernary 3.8만 as-is" and "hybrid two-stage" after the
  DeepTernary corpus was found to be CRBN-irrelevant. ChEMBL scouted for a
  realistic corpus-size estimate (low thousands). Draft pending approval.
