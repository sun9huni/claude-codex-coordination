# glue8 productive-geometry screen (orientation campaign, up to before MD)

- **Status**: approved
- **Slice**: vav1-ubq
- **Approval**: requested 2026-06-17; approved by: user 2026-06-17
- **Triggers matched**: GPU/SLURM submission (~768 Boltz runs); /mnt/data shared writes; 4+ files; container run. → contract required.
- **Revision**: rev2 (2026-06-17) — addressed contract-review defects C1–C4, I1–I4, M1 (see Defect-fixes).

## Purpose
Run 8 CRBN molecular-glue compounds — 6 new VAV1 candidates (g1–g6) + MRT6160 (0.9 nM active control) + C147 (10000 nM inactive control) — through the BYTE-FAITHFUL MRT6160 integrative pipeline (steered Boltz-2 orientation scan → 9UUM active-frame graft → 5-lysine in-line reach scan), UP TO MD-ready prmtop. Produces a per-compound **orientation-marginal** productive-geometry verdict on a scale anchored by the known active/inactive, gated by an active/inactive-separation KILL test. Feeds the inactive-control / TPD-predictor program (Gate-1).

## Current State
- Pipeline reverse-engineered + locked from `mrt6160_orientation_scan_20260609` logs/hparams (NOT vanilla, NOT the ab_multiseed cmd): Boltz-2 official weights, container `fksfold-boltz:glueplex-v2`, `--num_particles 8 --use_interface_steering --interface_scoring_type biophysical_hybrid --interface_lambda 20 --interface_resampling_interval 3 --sampling_steps 50 --recycling_steps 3 --diffusion_samples 1 --use_potentials --output_format pdb --enable_interface_gd --interface_gd_lr 0.01 --gd_start_t 0.5`; steering config = container-baked `oracle_generation.yaml` (glue-independent: VAV1[15,16,18,19,37,39]/CRBN[351,355,357]); NO w400/external-fragmap.
- Staged (zero-GPU): 36 input YAMLs (6 glues × 6 angle-configs) + 14 templates + launcher (SMOKE mode) + manifest at `/mnt/data/users/ubuntu/workspace/glue6_orientation_campaign_20260617/`. (Implementation will add g_mrt6160 + g_c147 → 48 YAMLs.)
- C147 SMILES RESOLVED (defect C3): extracted from the deposited PDB via CONECT (the structure the DC50=10000nM label was assigned to), glutarimide-verified, C23F2N2O3: `O=C1CC[C@@H](C(=O)N1)c1c(F)ccc(c1F)c1ccc(cc1)Cn1ccccc1=O` (Cl→F2 difluoro variant). MRT6160 SMILES = registry-confirmed canonical.
- Assets verified: fork overlays, oracle_generation.yaml, shared MSA (mount to avoid 768× MSA recompute), container (15.1GB). 6 new SMILES validated (glutarimide ✓; g5/g6 stereo unspecified, run as-is).
- Harnesses: `crl_pose_scan.py`/`crl_rebuild.py` (graft+5-lysine), `crl_md_prep.py` (prmtop), Tier-1 swept-reach SEMI gate (`reach_envelope.md`).

## Assumptions And Questions
- assumptions: oracle_generation.yaml is the container-baked biophysical_hybrid default (orig log path); glue-independent → reused. shared MSA mounted (CRBN+VAV1 identical across all 8 → MSA computed once).
- open questions, LOCKED at SMOKE: exact `--interface_gd_steps` (hparams 20 vs ab_multiseed 10); oracle config baked vs explicit — both resolved by diffing the smoke cell steering log vs an original orient run.
- tradeoff acknowledged (defect I4): N=1 inactive (C147) makes this a SCREEN, not a validated discriminator; a real discriminator needs ≥3 binding-inactives (future scope).

## Constraints
- allowed change scope: campaign dir under `/mnt/.../glue6_orientation_campaign_20260617/`; analysis scripts (graft/lysine-scan/triage/marginal/null-ablation) under `analysis/crl_integrative/`; /mnt outputs.
- forbidden change scope: ANY change to the locked Boltz generation params (byte-faithful replica required); the running MD job 7207; other slices.
- external constraints: ~50–65 GPU-hr; pipeline byte-faithfulness is the hard requirement; GPU submission via approval gate.

## Non-Goals
- The metadynamics MD itself (separate contract — stops at MD-ready prmtop).
- TPD-predictor model training (separate program).
- New chemotypes beyond the 8; any pipeline param tuning (faithful replica only).

## Done When
0. **(pre-req) C147 input ready** — extracted SMILES used as-is (resolved). MRT6160 + C147 YAMLs added (48 total).
1. **SMOKE gate PASS** — 1 cell (g1/p60/seed314) steering-log signature matches an original orient run (8 particles · oracle_generation.yaml · Lever 1–5 · interface_gd ligand_volume+clash); the 2 open flags locked. Verify: `diff` smoke signature vs original.
2. **Full campaign complete** — 768 poses (8 × 6 angles × 16 seeds) generated; success rate reported; FAILED cells enumerated (no silent drop).
3. **★ ACTIVE/INACTIVE SEPARATION KILL-GATE (defect C2)** — pre-registered: on the orientation-marginal metric (#4), MRT6160 (active) must separate from C147 (inactive). **If they do NOT separate → the metric is uninformative → STOP; the 6-glue triage is NOT trusted, report as method-negative (음성 자동선언 금지: weak, surface to user).**
4. **Productive triage table (8 rows), MARGINAL not best-pose (defect C1)** — per-compound label = **fraction of the orientation ensemble** that presents an in-line clash-free lysine (Nζ→Ub-Gly76-C AND →Cys85 dual-register, on 9UUM active frame), with per-seed spread. Best-pose min reported SEPARATELY, never as the verdict (avoids seed-selection bias). MRT6160/C147 anchor the scale.
5. **Circularity ablation (defect C4)** — the marginal-reach separation must BEAT a Boltz-internal null (does 9UUM-frame reach add signal over Boltz's own iPTM/placement confidence?). If the separation is fully explained by Boltz confidence → flag as circular (no added value), bound the claim accordingly.
6. **Survivor gate defined (defect I2)** — a pose is a "survivor" iff it passes the Tier-1 swept-reach SEMI gate (≤18 Å rotamer+receptor), same as MRT6160. MD-ready prmtop built ONLY for compounds WITH ≥1 survivor; **"no survivor" (expected for C147) is a VALID informative outcome, not a failure (defect I3)**.
7. Result doc committed (triage marginal table + separation-gate verdict + null-ablation + survivors + static-reach caveat) under `analysis/crl_integrative/`.

## Resource budget
- ~768 Boltz runs × ~3–5 min (num_particles 8, **shared MSA mounted** so computed once) ≈ ~50–65 GPU-hr; ~8–10 h wall on one 8-GPU node (qos=normal; launcher --time set with headroom). Empirically grounded: clean per-cell ≈ 2–3 min cached (defect I1; the 477–505 min mtimes were processed-dir artifacts).
- zero-GPU post: graft+marginal lysine-scan+null-ablation (~1–2 h), MD-prep for survivors (~CPU).

## Rollback plan
- `scancel` campaign job(s); delete `/mnt/.../glue6_orientation_campaign_20260617/outputs/` (regenerable). No repo/source state changed by the run (analysis additions are new files; git-revert). SMOKE gate prevents committing the full ~60 GPU-hr to a misaligned pipeline; the separation KILL-gate prevents trusting a circular/uninformative triage.

## Defect-fixes (from contract-review, rev1→rev2)
- C1 marginal-not-min label (Done#4) · C2 active/inactive separation as KILL-gate (Done#3) · C3 C147 SMILES resolved (Current State) · C4 circularity ablation (Done#5) · I1 budget re-grounded (Resource) · I2 survivor gate = SEMI (Done#6) · I3 C147-no-survivor=valid (Done#6) · I4 N=1 screen caveat (Assumptions) · M1 static-reach induced-fit error bar flagged (Done#7, borderline calls need pocket-repack/MD).

## Verification
- SMOKE log diff; full-campaign pdb count vs expected (minus reported failures); marginal triage table + separation-gate pass/fail; null-ablation result; survivor list; prmtop sanity (`crl_confirm.py --t0` style) on built systems.
