---
owner_session: 399a2a3b-070e-4188-bc32-2e87f759b47d
owner_label: 
owner_agent: claude
version: 36
last_updated: 2026-06-08
heartbeat: 2026-06-08T11:47:25Z
remaining_actions:
  - '✅ 2026-06-08 SESSION CLOSED clean. SILCS v1/v2 A/B pilot (6488) was INVALID (stale baked module → fragmap silent-disable), root cause FOUND + FIXED: wiring committed 237f24b, mounts+smoke-gate 930f647, scorer+doc e6e92d6. Lesson #4 "FragMap 9NFR 잉여" AUDITED = SURVIVES (HIGH) → 2026-06-04 격하 전환 유효. No open blocker; no urgent decision. NEXT (optional/deferred, user-paused): v1/v2 re-run with the now-safe mount (ceiling predicts v2 also ≈0 on 9NFR), OR resume ubiquitination-geometry scoping (see DECISION entry below). Full record: reports/silcs_v1v2_ab_results.md + entries below.'
  - '❌ SILCS v1/v2 A/B pilot (job 6488, 2026-06-08) = INVALID (null-by-construction, NOT a v1/v2 verdict). 10/10 cells done (~1 GPU-hr) but A(v1) & B(v2) model_0.pdb BYTE-IDENTICAL all 5 seeds (same md5). ROOT CAUSE (fragmap-diagnose, sealed): SLURM mounts main.py+boltz_extension only, NOT src/boltz/model/modules/ → container ran STALE baked diffusionv2_extend.py (image .Created 2026-02-10) that lacks the fragmap→resampling wiring added 2026-05-19. In-container grep "Interface steering enabled"=0 (local=1); logs show 0 [FragMap] lines across 18 biophys+resample steps → fragmap_potential=None → frag_term=0. Configs+NPZ genuinely correct & different. 4th invalidated A/B (prior 3=wrong mode:feature). Scorer: analysis/.../src/eval_silcs_ab.py; CSV+report: reports/silcs_v1v2_ab_{eval.csv,results.md}. ⚠️ RETRO QUESTION: lesson#4 "FragMap 9NFR 잉여" may have been measured under same silent-disable — verify it rests on wiring-live runs.'
  - '✅ LESSON #4 AUDIT (2026-06-08, fragmap-diagnose, zero-compute): "FragMap 9NFR 잉여" SURVIVES (HIGH conf) → 6/04 격하 전환 유효, 방어용 재실행 불필요. Proof: surviving live-fragmap log /mnt/data/users/kim/fksfold_outputs/vav1_iface_anchor_20260521_161629/logs/VAV1_345_AB.log shows [FragMap] enabled w_frag=0.3 + per-step FragMap=/w_frag=0.300 (construction+combine ran) yet 9NFR offset moved ≈0; AND no-headroom ceiling derivable from baseline alone (silcs_map_revival REPORT + T1 PLI near-native LDDT-PLI 0.88-0.93). CORRECTIONS: (i) slice-note "mode별 안전성" WRONG — susceptibility is MOUNT-driven not mode-driven (invocation lives in diffusionv2_extend.py); (ii) D1 +0.131 is expanded-vs-baseline YAML, NOT fragmap-on/off — do not cite as fragmap-live proof. Two mount families existed: VULNERABLE (slurm_fragmap_surface_*_20260507.sh = main.py+boltz_extension only → fragmap silently dead) vs SAFE (May-21 anchor + slurm_fragmap_9nfr_abc_pilot.sh mount diffusionv2*).'
  - '✅ ROOT HAZARD RESOLVED (2026-06-08): fragmap invocation wiring WAS uncommitted — HEAD had 0 occ, working-tree had 12 (diffusionv2_extend.py) + 4 (diffusionv2.py), both M. Last commit: extend=caabf26 2026-04-10, v2=c80f92a 2025-09-24 init; image .Created 2026-02-10. So load-bearing fragmap code is in git nowhere + baked nowhere → runs ONLY when SLURM mounts working-tree diffusionv2_extend.py. DONE 2026-06-08 (user-approved): (1) ✅ fragmap wiring COMMITTED (237f24b — diffusionv2.py+diffusionv2_extend.py, diff fragmap-only, branch platform-versioning-r20260417); (2) ✅ 6488 prep+slurm now stage+mount diffusionv2* + per-cell SMOKE GATE hard-fails if "[FragMap] Interface steering enabled" absent (930f647); scorer+results doc committed (e6e92d6). REMAINING: rebuild glueplex-v2 ≥237f24b would make the mounts redundant (optional cleanup); OTHER vulnerable scripts slurm_fragmap_surface_*_20260507.sh still mount main.py+boltz_extension only (fix if ever reused). OPTIONAL/LOW-PRIORITY (user deferred, NOT needed for strategy): v1/v2 A/B re-run with safe mount — ceiling argument predicts v2 also ≈0 on 9NFR. Contract fragmap-silcs-v2-ab-pilot-20260604.md still covers re-run scope.'
  - 'DECISION: ubiquitination 기하를 새 상위 target으로 scope (ternary 형성=proxy, Ub transfer geometry=진짜 target). VAV1 SH3 lysine 5개(K788/804/810/814/815, 전부 17-26Å from glue, interface는 lysine-free). SH3-only graft skeleton(PDB 4TZ4/2HYE/7OKQ/6TTU, 16Å productive-lysine 기준 PMC9019245)=오늘 zero-GPU 가능하나 conservative lower-bound; 정량 답은 full-length VAV1 모델링(별도 integrative). ubiquitination-zone feasibility contract 초안 대기. 상세: .agent/scratch/fragmap_revised_plan_feasibility_20260604.md'
  - 'NEEDS-DATA: corpus causal-grammar(composite-surface 형성 문법) 보류 — /home/ubuntu/DeepTernary/data/MolecularGlue는 manifest-only(좌표 디스크 부재)+≥53% 비-글루+CRBN≈0. RCSB 큐레이션(글루 allowlist+apo+outcome) 선행. ★핵심 진단: SILCS/FragMap favorable density가 진짜 glue-VAV1 contact에서 7-11Å 오방향=범주오류(품질 아님). DeepTernary consensus(10예측 2.5Å 일치, crystal 4.0Å)가 더 나은 surface predictor. W400/biophysical 단독 down-weight 금지(VAV1을 3Å에 놓는 유일 신호)=regime-conditional factorial arm으로만. 상세: .agent/scratch/fragmap_vav1_map_geometry_diagnosis_20260604.md'
  - '✅ GCMC 10× DONE (job 6245, 2026-06-04 → v2 finalized 2026-06-05): v2 npz at /mnt/data/users/ubuntu/workspace/gcmc_ternary_10x_20260602/npz_v2/ternary_r2_maps.npz (650145 bytes, md5 7b97…), used as the B-arm map in pilot 6488. finalize_grandlig_atom_specific_channels.py produced ternary_r{1,2}_maps_v2.npz.'
  - '🔑 CRITICAL FINDING 2026-06-04 — fragmap 활용 방식 오류 발견: 성공 AB run (job 5638)은 **mode: target_occupancy** (configs/vav1_pipeline/fragmap_conditioning_target_t1_r10.yaml)을 사용. 이 모드는 VAV1 chain 전체를 target으로 삼아 GFE field 기반 resampling. 우리가 테스트한 **mode: feature** (feature_c6_mrt6160.yaml)는 warhead 특정 원자들→특정 hotspot 방식으로 전혀 다른 동작. 3회 A/B pilot(jobs 6298/6307/6323) 모두 wrong config mode → 결과 무효. 올바른 다음 테스트: target_t1_r10_v2interim.yaml (fragmap_npz 경로만 v2로 변경) vs target_t1_r10.yaml, lambda=20/npart=8/9nfr_mrt6160_vav1_14_19.yaml. SLURM contract 필요(fragmap-silcs-v2-ab-pilot-20260604.md 재활용 또는 신규). target_occupancy 모드 상세: mode=target_occupancy, target_chain=B, favorable_channels=[hydrophobe/aromatic/heteroaromatic/amide_acceptor/amide_donor/polar], target_reward_weight=10.0, gd_scale=0.0(resampling-only), w_frag=0.3. ★GCMC 10× 완료 후 이 테스트가 최우선★'
  - '✅ SILCS map-revival LANE CLOSED (2026-06-02, plan+contract DONE; FKSFold 44f80c5/600e655/6c31b97/1edb0ac + Fork-B crystal_ligand_ceiling.py + REPORT.md). FINDING: strong atom-specific donor/acceptor (grid_amide_donor/acceptor + imidazole/ether, GFEmin −2.2~−2.3) ALREADY exist in frozen npz; bug was only generic grid_donor=grid_acceptor=methanol (−0.413). Atom-type-aware post-hoc LGFE = REAL NULL: Task-4 125 well-placed AB poses coverage≈0 (mean 2.3%/median 0%, 48% protein-vdW, LGFE pinned +5 cap). **Fork B (user-gated, zero-GPU) pinned the mechanism**: frame hypothesis RULED OUT (map source equil.pdb 408/408 CA in exclusion; /tmp/9nfr_reference.pdb B/C chains raw-RMSD 0.00 vs equil = alignment target IS map frame); crystal ligand A1B (ground truth, map frame, no-align) ALSO coverage 0/21, LGFE +5.0, nearest-signal median 2.26Å (17/21 within 3Å). MECHANISM = sparse GFE field × NN point-sampling caps even at ground truth, independent of channel/pose/frame; needs ~3Å soft pooling = what STEERING does (explains lesson #4 at mechanism level). RECOMMENDATIONS: (a) adopt amide channels into post-hoc consumer = NO (re-key changes which capped value is read, not that it caps); (b) gap-a GPU tier (negative channel+pyridine) = NOT JUSTIFIED (limiter is sampling structure not chemistry). VALUE = generation steering. ⚠️ POST-CLOSURE CODE-VERIFY CORRECTION (REPORT.md Addendum 2026-06-02): the strong channels are NOT an unused steering candidate to hand over — fragmap_steering.py samples via trilinear + σ=3Å Gaussian kernel (L79/L784/L1194), its DEFAULT channels list (L264) + element typing (L229) ALREADY use amide/imidazole/ether, and production config fragmap_conditioning_feature_c6_mrt6160.yaml has enabled:true mode:feature with per-atom feature_definitions (carbonyls→amide_acceptor, N14→amide_donor) + feature_sigma 3.0. methanol grid_donor/acceptor = fallback-only (L250/L545), never reached → the bug was POST-HOC-ONLY, never degraded steering. So nothing to wire in. FORWARD-QUESTION GATE (diagnose-before-scale, REPORT.md §Forward-question gate, 2026-06-02): feature-mode FragMap steering experiment — **9NFR = NOT worth GPU** (lesson#4 result is YAML+λ+W400 SATURATION = no headroom, corroborated by T1 PLI near-native; robust to channel form → predictably ≈0). **143-set = only under-tested lever, LOW priority, aigen-fold-core's to run** as pre-registered generation measurement (per-compound accuracy dist, lesson#7), distinct from pocket-anchor steering T2/D3 Stage B killed (Stage B did NOT test FragMap feature steering). Evidence-correction: strong channels were available+routed since 4/30 freeze; May-20 code (bak_20260520) already had _channels_for_atomic_number in cluster/grid + optional feature_reward (modes then = cluster|grid|cluster_then_grid; target_occupancy/feature-as-mode added later). Exact job-5283 ablation config UNRECOVERABLE (May-19/20 run dirs gone from tree + /mnt/data, checked as kim) — but irrelevant to 9NFR verdict (ceiling-limited). HARD RULE still: no ternary_r*_maps.npz re-freeze. Notion reorg C (Experiments retag + job→Slice heuristic) still DEFERRED = harness-domain; aigen-fold-core array 5911 now FINISHED (Stage B KILL) so the 5911 gate is open → coordinate with harness owner.'
  - '✅ slice migration COMMITTED (1b42eb6). 📋 NEXT(승인대기): Notion 재정리 PLAN drafted = .agent/scratch/slice_migration_prep/NOTION_REORG_PLAN.md (seq A[notion_sync.py --migrate slices]→D[신규 ADR]→B[hub scope]→C[Experiments Slice 재태깅+job→Slice 휴리스틱 수정]→E[레거시 SILCS 페이지 정리]; F[held-out verdict report]=T2/D3 verdict 후로 deferred). 📋 NEXT(본작업): SILCS map revival /brainstorm (zero-GPU gap b·c 먼저). 세션종료 2026-06-01.'
  - '🔀 MIGRATION 2026-06-01 (claude): placement/held-out 검증 lane (T2/D3, AB) → aigen-fold-core (엔진 placement 출력 검증 = boundary상 aigen-fold-core 소관). 이 슬라이스는 이제 SILCS-Lite map build + scoring 전용. 다음 active = SILCS map revival (contract via /brainstorm; zero-GPU gap b[donor/acceptor finalizer re-key]·c[채널 검증] 먼저, GPU gap a[negative channel] 게이트 뒤). HARD RULE: downstream PROVE/KILL 열려있는 동안 ternary_r*_maps.npz 재freeze 금지. 이동된 T2/D3 durable 기록은 aigen-fold-core baton. 런북 .agent/scratch/slice_migration_prep/RUNBOOK.md.'
  - "✅ ACTIVITY-PREDICTION LANE CLOSED (2026-06-01): DC50 + Dmax 둘 다 KILL (사전등록·누수차단); coarse triage = MW/logP physchem (capstone, perm p=0.165). 플랫폼 = placement generator, NOT activity ranker. Decision report → Notion Reports DB 발행 (https://www.notion.so/3711e76c3b6081f59ef2c239a2f3cd82) + FKSFold 1bd72cd."
  - "✅ Charter A 문서화 + Measurement foundation(D) 설계 완료 (2026-06-01, zero-compute): docs/platform_charter_A_20260601.md (oracle placement generator + classic-pocket scope + AD MW 340–463; 활성-순위 주장 제거), docs/measurement_foundation_design_20260601.md (D1 methodology gates / D2 external decoy / D3 비순환 held-out / D4 evidence git-track / D5 seed reconcile)."
  - "✅ Measurement foundation zero-compute 3종 전부 완료 (2026-06-01): D1 gates 라이브러리 (analysis/foundation/activity_eval_gates.py, 회귀+분류 도메인-무관 API, smoke OK) + D4 evidence git-track (FKSFold 938e258 — analysis/fragmap_spectral_discriminator/ 18 src + 17 reports.md + 4 reports.json ~364K, shared-only data는 DATA_MANIFEST.md 포인터, *.csv/outputs*/ 정책 준수 force-add 없음) + D5 seed reconcile 설계 (FKSFold ffdefe2 — docs/seed_reconcile_design_20260601.md, 4 regime production[42,123,777]/ablation[314,777,99]/pilot seed=16/분석RNG42 라벨링 정책)."
  - "✅ Deep-insights 2차 채굴 + induced-fit 테스트 완료 (2026-06-01): 5개 병렬 에이전트가 6개월 corpus 재독 → 메타-메타 = 5 스케일에서 '프록시 vs 타깃 분리' 단층선 반복. 유일하게 MW로 안 녹던 placement 역신호(raw offset ρ=−0.305)를 사전등록 scaffold-blocked 테스트로 confirm/kill → KILL (within-chemotype SAR, NOT induced-fit: OOF ρ=−0.117, perm p=0.694; 단 MW 아티팩트도 아님 — partial −0.281 생존 = congeneric SAR). 사전등록 가치 실증(scaffold-block이 죽임). 종합문서 docs/deep_insights_tapestry_20260601.md (FKSFold 3554dde), 테스트 analysis/induced_fit_inverted_signal_20260601/ (cd4e79b), contract f7d06e6/result 9d1c6d3. Notion 발행: https://www.notion.so/3721e76c3b608156b9edc5f898e17907 (Reports DB, Research Update). charter A 강화, D3 escalation 비정당화, 마지막 미해명 활성 thread 종료."
  - "✅ Measurement-leverage 프로그램 착수 + T0 완료 (2026-06-01, brainstorm→write-plan→execute-plan): 5무늬 활용 3-tier 로드맵(.agent/plans/fragmap-leverage-program-20260601.md, 사용자 승인 T0→T1→T2 / 데이터 확보까지 OK). **T0 (Measurement Guardrails v1) DONE** — contract fragmap-measurement-guardrails-v1-20260601 (approved), plan 8 task 전부 done, FKSFold 6 commit(5be5ad2 mw_mediation_fraction, 1fc7acf within_between_scaffold, 394d238 power_preflight/n_needed[n≈350 floor], 75512a3 smoke, c35cd68 docs/proxy_audit_preflight.md, 2c2978c foundation 링크, c106991 Charter A confidence/enclosure 재라벨). smoke 'SMOKE OK'. 모든 신규 활성 주장은 이제 proxy-audit 체크리스트 + 3 게이트 통과 필수."
  - "✅ T1 (PLI-as-objective pilot) 종결 = KILL-by-diagnostic (2026-06-01, zero-GPU, contract baa6594/plan done): brainstorm→write-plan→execute-plan 풀체인. 메커니즘 정독으로 기존 GlueprintPotential ligand-contact term 재사용 결정, 단계화 T1a→T1b. **pre-submit 진단(MGD_eval, GPU 0)이 premise 깸**: AB-corrected 포즈 5/5가 이미 near-native PLI (LDDT-PLI 0.88–0.93, ligand-RMSD<0.8Å vs 9NFR A1BYX 코어) → headroom 0 → SLURM 미제출(사용자 'T1 닫고 T2/D3로'). '99.8% PLI 실패'=blind/pre-AB 아티팩트, AB가 코어-PLI 이미 풂. ★ near-native 포즈(placement 3.16Å+LDDT-PLI 0.92)인데 활성 null = category 문제 포즈 레벨 확인. 한계: 공유코어만 측정, per-analog 주변부는 D3 held-out 없이 비순환 불가. diagnose-before-scaling이 ~1–2 GPU-hr 회피. 보고서 FKSFold 990ce87 analysis/pli_objective_pilot_20260601/T1A_RESULTS.md."
contract_pointers:
  - .agent/contracts/fragmap-mdsilcs-rebuild-v2-20260602.md
  - .agent/contracts/fragmap-silcs-rebuild-v2-20260602.md
  - .agent/contracts/fragmap-ab-multiseed-20260526.md
  - .agent/contracts/fragmap-ab-139batch-20260526.md
  - .agent/contracts/fragmap-light-filter-recal-20260526.md
  - .agent/contracts/fragmap-dc50-overfit-scan-20260527.md
  - .agent/contracts/fragmap-unsteered-recovery-20260527.md
  - .agent/contracts/fragmap-multivariate-potency-test-20260529.md
  - .agent/contracts/fragmap-dmax-multivariate-test-20260529.md
  - .agent/contracts/fragmap-induced-fit-inverted-signal-20260601.md
  - .agent/contracts/fragmap-measurement-guardrails-v1-20260601.md
  - .agent/contracts/fragmap-pli-objective-pilot-20260601.md
  - .agent/contracts/fragmap-silcs-map-revival-20260601.md
  - .agent/contracts/fragmap-silcs-v2-ab-pilot-20260604.md
state: active
---
# FragMap / 9NFR Status

> **🧭 2026-06-04 STRATEGIC PIVOT (this session):** FragMap는 VAV1 인식의 primary가
> 아니라 support/diagnostic로 격하. SILCS favorable density가 진짜 glue-VAV1 contact에서
> 7-11Å 오방향 = 범주오류(품질 문제 아님). 플랫폼 = placement generator; steering =
> regime-stratified (OOD rescue / prior-good interfere) → W400/biophysical 단독 down-weight
> 아님. 진짜 target = ubiquitination 기하(lysine→E2~Ub zone). 전체 재정의·feasibility 판정·
> 다음 phase: `.agent/scratch/fragmap_revised_plan_feasibility_20260604.md` +
> `.agent/scratch/fragmap_vav1_map_geometry_diagnosis_20260604.md`.

> **🔀 2026-06-01 MIGRATION:** placement/held-out 검증 lane (T2/D3 held-out, AB pattern)이
> **aigen-fold-core 슬라이스로 이전**됨 (엔진 placement 출력 검증 = boundary상 aigen-fold-core 소관).
> 이 슬라이스는 이제 **SILCS-Lite map build + scoring 전용**. 다음 active 작업 = SILCS map revival
> (zero-GPU gap b·c 먼저, GPU gap a 게이트 뒤). 이동된 T2/D3 durable 기록 → `.agent/status/aigen-fold-core.md`.
> 런북 `.agent/scratch/slice_migration_prep/RUNBOOK.md`. 아래 §본문은 map+scoring·종료lane history.

> **As of 2026-06-01 — DECISION: 플랫폼 = placement generator, NOT activity ranker.**
> 활성-예측 lane 닫힘 (DC50 KILL + Dmax KILL + capstone triage=physchem, 전부 사전등록·
> 누수차단). Decision report: `docs/activity_prediction_decision_report_20260601.md`
> (FKSFold commit 1bd72cd). Notion 발행: https://www.notion.so/3711e76c3b6081f59ef2c239a2f3cd82
> (Reports DB, Experiment Closeout). 마지막 활성 후보 Step 1의 입력(job 5809)은 06-01 08:34 UTC
> empty timeout. ✅ 후속 완료: charter A 재포지셔닝(`docs/platform_charter_A_20260601.md`, Notion
> 3721e76c) + measurement foundation(D) 설계 + zero-compute 3종(D1 gates 라이브러리 / D4 evidence
> git-track 938e258 / D5 seed reconcile 설계 ffdefe2). 남은 D2/D3/D5-재baseline은 contract 게이트.
> 상세는 frontmatter remaining_actions + `docs/measurement_foundation_design_20260601.md`.

As of: 2026-05-26 🎯 **Phase 8/9 VAV1 paradigm + AB pattern + Phase 10 entry gate**
Prior milestones: 2026-05-19 breakthrough → 2026-05-20 145-batch + MMGBSA handoff → 2026-05-21 Phase 7/8/9 → 2026-05-22 viz wrap

## Where we are

### Plan completion
- **Probability steering plan** (`fragmap_probability_steering_6a8034a0`): 5/5 todos DONE
- **Generation steering plan** (`fragmap-generation-steering_7e2f2e29`): 5/5 todos DONE
- **Target occupancy plan** (`target_fragmap_occupancy_af712dd6`):
  - todo 1 (mode + parser): ✅ DONE (`fragmap-target-occupancy-20260519.md`)
  - todo 2 (patch aggregation): ✅ DONE (`fragmap-target-occupancy-scale-and-patch-20260519.md`)
  - todo 3 (diagnostics): pending (낮은 우선순위, 다른 트랙 활용중)
  - todo 4 (configs): ✅ T1-T8 등 다수 작성됨
  - todo 5 (pilot): ✅ 사용자 승인 후 multi-sweep 실행 완료

## 🎯 Generation Breakthrough — 완료 (2026-05-19~2026-05-20)

오랜 `ligand_target_contact_f1 = 0` barrier 깸. 원인 = **input YAML pocket constraint**의
잘못된 VAV1 residue 범위 (`16-26` → ground truth `14-19`). corrected YAML 한 줄 변경 +
L4 steering 조합으로 즉시 barrier 깸.

### Best config — P7 (현재 단일 baseline)
```
input:    examples/9nfr/9nfr_mrt6160_vav1_14_19.yaml (corrected)
seed:     16
npart:    8
λ:        20
FragMap:  configs/vav1_pipeline/fragmap_conditioning_target_t1_r10.yaml
W400:     anchor 16,17,18,19 (NOT 14-19; over-anchor 금지)
→ CRBN F1=1.0, VAV1 F1=0.800, iface F1=0.108, tgt_min=2.05 Å, face 5/5 GT
```

### Pareto front (seed만 다름)
- **seed=100 (Y5/S3)**: lig-VAV1 F1=0.800 (face 5/5), CRBN+VAV1 동시 만족 유일 case
- **seed=2024 (S7)**: iface F1=0.127 (단독 1위), combined score 1.047
- **seed=1000 (S6)**: tgt_min=2.03 Å (최저)
- **seed=16 (P7, npart=8)**: F1=0.800 + tgt_min=2.05 (Y5보다 더 가까움)
- 5/8 seeds break barrier (62.5% robustness)

## 🌐 145-Compound Generalization — 완료

normtest143 corrected YAML 패턴 적용 (sweep 5284, 2h 06m):
- 139/145 PDB 생성 (6 OOM)
- **63% (88/139) lig-VAV1 F1 > 0** (barrier 깸)
- **37% (52/139) F1 > 0.5**
- **12 compound가 Y5-class (F1=0.8)**
- **max iface F1 = 0.714** (VAV1_345) — 9NFR P7의 6.6배 신기록

### Top hits
| compound | iface F1 (mean) | DC50 | 신뢰도 |
|---|---|---|---|
| VAV1_345 | 0.616 (3 seeds robust) | 3.5 nM | ✅ super-hit |
| VAV1_292 | 0.285 | 12.7 nM | seed-dependent |
| VAV1_489 | 0.270 | 2.8 nM | seed-dependent |
| VAV1_209 | 0.211 | 7.3 nM | seed-dependent |

### Activity correlation (한계 확인)
- Pearson(log10 DC50, lig-VAV1 F1) = -0.001 (실질적 0)
- Pearson(log10 DC50, iface F1) = -0.163 (약한 negative)
- **top-10 by iface F1: 70% active precision** (1.72× baseline 40.6%)
- 단 top-50에서 enrichment 1.08× (top tail에만 강한 signal)

## 🔬 FragMap Necessity + Decoy Validation — 완료

### FragMap ablation (job 5283, 4 paired comparisons)
- **9NFR에서 FragMap 효과 ≈ 0** (전부 corrected YAML + λ + W400 덕분)
- **143-set에서는 일부 fine-tune**: VAV1_173 iface F1 +0.046, VAV1_285 VAV1 F1 +0.100

### Decoy negative control (job 5329)
| ligand | 분류 | lvF1 | iface F1 | p_vav1_lig |
|---|---|---|---|---|
| MRT6160 (native) | binder | 0.800 | 0.135 | 0.834 |
| caffeine | decoy | **0** | 0 | **0.610** |
| ibuprofen | decoy | 0.333 | 0.081 | 0.720 |
| PEG_fragment | decoy | **0.667** ❌ | 0.176 | **0.570** |

**Out-of-class detection (decoy) 작동, in-class ranking 안 됨**.

### Boltz confidence vs DC50 (zero-compute)
- iptm, plddt, pair_*_iptm 모두 활성/비활성 구분 못함 (Pearson 0.02-0.05)
- 단 **chemical class 분류 (PROTAC vs non-PROTAC)에는 작동**: `pair_vav1_lig`이 decoy 잡음

## 🔁 Light Filter Calibration — 완료

**MMGBSA 입력 후보 선별용**:
- 53% drop (이전 제안): top hit (VAV1_345) 잃음, 과한 강도
- mmgbsa structure-intrinsic 실패는 13%만 → 87%는 protocol-recoverable
- **Light filter spec**:
  ```
  PASS = NOT (ipde > 1.0 OR clash ≥ 1 OR plddt < 0.85 OR p_vav1_lig < 0.55)
  ```
- 결과: 99/139 (29% drop) 통과, top-10 winner 모두 보존

## 📦 MMGBSA Handoff (2026-05-20)

99-compound mmgbsa stage 1 prepare를 **mmgbsa session으로 handoff**:
- Sources: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/outputs/_mmgbsa_staging/norm143_corrected_sources.tsv`
- SLURM script: `scripts/mmgbsa_16gpu_multidir/slurm_mmgbsa_norm143_corrected_stage1.sh`
- Run as kim, qos=high, 2 node × 8 A100 = 16 GPU, RunA+B
- OUT_BASE: `/mnt/data/users/kim/mmgbsa_outputs/norm143_corrected_seed16_stage1_<TS>`
- 예상 출력: ~40-60 paired ΔΔG (Stage 1 + 2 + 3 + merge 후)

## Live truth

- Code (shared, SLURM source): `src/boltz_extension/steering/fragmap_steering.py` (target_occupancy + patch + normalize override)
- Code (local↔shared sync 상태, 2026-05-26 확인):
  - `fragmap_steering.py` — **동일** (둘 다 56078 bytes, 동일 내용). 이전 status의 미동기화 플래그는 stale
  - `interface_steering_utils.py` — **local이 shared보다 앞섬** (45252 vs 43597 bytes). local 전용: `_load_glueprint_config_from_biophysical_yaml` (glueprint loader) + `gd_floor` range normalization. Phase 6b hybrid 연구 arm용 — production AB pattern는 둘 다 사용 안 함, **Phase 10 Step 3는 shared as-is로 안전**. glueprint를 SLURM에서 쓰려면 별도 sync 필요
  - `fragmap_steering.py.bak_20260520` — local-only safety backup (정리 보류)
- Plans: `~/.cursor/plans/target_fragmap_occupancy_af712dd6.plan.md` 등
- Outputs: `outputs/fragmap_9nfr_*`, `outputs/norm143_full_20260519_173435/`, `outputs/_mmgbsa_staging/`,
  Phase 8 sweep `/mnt/data/users/kim/fksfold_outputs/vav1_iface_anchor_20260521_161629/` (5395),
  Phase 9 overfit `/mnt/data/users/kim/fksfold_outputs/9d0w_overfit_20260521_165307/` (5398)
- Analysis (shared): `analysis/fragmap_target_occupancy_{smoke,offline_diagnostic}.py`, `compare_ternary_metrics_9nfr.py`,
  `analysis/fragmap_spectral_discriminator/src/{steering_health_diagnostic,eval_vav1_iface_sweep,rotamer_orientation_diagnostic}.py`
- Analysis (local, Phase 8/9): `/home/ubuntu/analysis/9d0w/`, `/home/ubuntu/analysis/9nfr_crystal_interface.json`
- Diagnostic CSV (local, raw): `/home/ubuntu/failure_mode_diagnostic.csv` (139 rows, used by Phase 8 mispositioning + Phase 9 viz),
  `/home/ubuntu/dc50_stratified_AB5.csv` (5 rows, Phase 9 anecdotal DC50 stratification),
  `/home/ubuntu/ligand_position_features.csv` (rotamer features, hypothesis retracted)
- Best-structure bundle: `/home/ubuntu/best_structures/` — VAV1_345 P7 seed=16 PDB + 9NFR_reference.cif + 10 PNGs + PyMOL .pse
- Publish docs: `docs/fragmap_9nfr_breakthrough_20260519.md`, `docs/fragmap_9nfr_generalization_audit_20260519.md`
- Phase 8/9 reports (shared): `analysis/fragmap_spectral_discriminator/reports/{vav1_mispositioning_diagnostic,vav1_iface_anchor_sweep_results,overfit_validation,failure_mode_diagnostic,steering_health_diagnostic}.md`
- Viz bundle (Notion-ready): `/home/ubuntu/fragmap_viz_20260522/` — INDEX.md + 35 PNGs (9 new + 26 existing), `make_figs.py` reproduces

## Total SLURM jobs (오늘 19개)

| Job | Sweep | 결과 |
|---|---|---|
| 5253 | T1 single pilot | score만으론 안 됨 |
| 5254 | W400×FragMap weight | W400-attractor 가설 기각 |
| 5256 | lambda sweep | λ=20 임계점 발견 |
| 5258 | C2 hotspot | 과한 강도, F1 악화 |
| 5263 | FragMap isolate | λ alone vs +FragMap |
| 5266 | W400 anchor residue | 회전 barrier 확인 |
| 5267 | seed sweep | seed=100 outlier |
| **5268** | **YAML corrected** | **🎯 barrier 처음 깸** |
| 5269 | Y5 multi-seed | robust 5/8 |
| 5270 | fine-tune | seed=1000 saturation |
| 5272 | CRBN recovery | Y5 단독 sweet spot |
| 5273 | num_particles | P7 새 best |
| 5276/5277 | normtest143 1-case | F1 0→0.800 generalize |
| 5280 | 8-compound batch | 4/7 success |
| 5283 | FragMap ablation | 9NFR 잉여, 143 약간 도움 |
| **5284** | **Full 145 batch** | 63%/37% break + top hit VAV1_345 |
| 5327 | Top hit multi-seed | VAV1_345 robust 1위 |
| 5329 | Decoy negative control | F1 단독 한계 입증 |

→ MMGBSA stage 1 (mmgbsa session, jobid TBD)

## 🆕 D1 Expanded-YAML paired test (job 5340) — Track A verdict (2026-05-20)

Expanded YAML 패턴 (14-19 + FragMap-derived 32/36/41) 가설 검증:

- **Generation-centric 결과 (n=81 paired)**:
  - iface F1 Δ mean **+0.131**, median +0.075, win rate **72%** (Wilcoxon p<0.0001)
  - iface RMSD Δ **-3.44 Å**, win rate **82%**
  - tgt_min Δ -1.15 Å
- **초기 verdict (Track C, screening framing) 정정**: top-K precision -20pp는 screening
  메트릭이고 우리 목적(per-compound generation accuracy)과 다름. 사용자 push back으로 재해석.
- **Super-hit mechanism (`superhit_mechanism.py`)**:
  - VAV1_345 "crash"는 noise — GT recall 4/6→4/6 동일, 34/50 추가 (broader)
  - VAV1_292만 진짜 alternate basin (recall 0.67→0.33), 1/81 케이스
  - 32/36/41 anchor는 자체를 끌어당기지 않고 인접 34/37/39/50 surface stabilize
- **Production baseline decision pending**: P7 (14-19) vs expanded (14-19+32/36/41) vs hybrid

## 🎯 CDK2/9D0W Phase 7 pilot — SUCCESS (2026-05-21, job 5392)

- 9NFR P7 setup이 **재튜닝 없이 CDK2 MGD target에 transfer**
- One-shot Cpd 4 결과:
  - **lig-CDK2 F1 = 0.826** (9NFR 145-batch best 0.714 초과)
  - Inner shell hinge/DFG 8/8 recall (F80, E81, F82, L83, H84, D86, K89, Q131 모두 회복)
  - target_min_dist 2.47Å, clash 0
  - iptm 0.82, ligand_iptm 0.96
  - CRBN-CDK2 iface F1 0.40 (broader than GT — 9NFR expanded 패턴과 동일)
- CDK2 hinge가 VAV1 SH3보다 훨씬 강한 structural prior — F1 barrier 자체가 약함
- Artifacts:
  - `examples/9d0w/9d0w_cpd4_cdk2.yaml`, `9d0w_ground_truth_report.md`, `9d0w_ground_truth.json`
  - `workflow/slurm_9d0w_cpd4_pilot.sh`
  - `analysis/9d0w/9d0w_cpd4_pilot.md`
  - `/mnt/data/users/kim/fksfold_outputs/9d0w_cpd4_pilot_20260521_131605/`

## Critical lessons (재사용 가치)

1. **Input YAML pocket constraint가 진짜 손잡이**: 모든 ternary 실험 시작 전 ground truth와 일치 확인 필수
2. **interface_lambda ≥ 20** 필수: default 0.05이면 resampling 무력화
3. **W400 anchor는 14-19 over-anchor 금지**: 16-19가 적정
4. **FragMap은 9NFR 잉여, 143-set fine-tune 도구**: 본질적 기여는 작음
5. **Confidence + F1만으로는 in-class ranking 한계** (top-10 70%): MMGBSA ΔΔG 필요
6. **Light filter (29% drop)이 sweet spot**: 53%는 과함
7. **Generation 평가 ≠ Screening 평가**: 생성 모델 verdict는 per-compound accuracy distribution
   (mean/median, win rate, RMSD) 사용. Top-K precision은 정보용으로만, decision driver 금지.
8. **Super-hit "crash"는 메트릭 결함 가능성**: 원자쌍 iface F1이 residue-level GT recall과
   다르게 움직이면 broadening artifact일 수 있음 — `superhit_mechanism.py`로 검증.

## Open

### Phase 10 entry (next session)
- **Step 1**: status doc 재정합 (this edit; in-progress)
- **Step 2 ✅ 완료** (2026-05-26): `fragmap_steering.py`는 이미 동일 (이전 플래그 stale). `interface_steering_utils.py`는 local이 앞서지만 glueprint/gd_floor만 차이 → AB pattern과 무관, sync 보류
- **Step 3 ✅ 완료** (SLURM 5628 TIMEOUT@45:17 + 5631 followup COMPLETED@12:54, 2026-05-26): AB multi-seed robustness — 25/25 cells, **F1@5Å = 0.909 across all 25** (recall 1.0, prec 0.833, seed std = 0.000). vav1_offset mean 2.91–3.97 Å per compound (std 0.21–0.76). Median lift +0.242 to +0.338 vs baseline on 5/5 compounds × 5/5 seeds. **VERDICT: GO** (seed=16 outlier hypothesis falsified). Caveat: F1@5Å saturated at 0.909 ceiling; F1@4Å has small seed sensitivity (std 0–0.059); finer discrimination via vav1_offset. Report: [ab_multiseed_robustness.md](../../FKSFold-Boltz_Advancement/analysis/fragmap_spectral_discriminator/reports/ab_multiseed_robustness.md). CSV: `ab_multiseed_eval.csv`
- **Step 4 ✅ 완료** (SLURM 5638 COMPLETED 2026-05-26 17:00, 02:45:48 elapsed, 8 GPU × 1 node, host-10-0-3-160): AB 139-batch (145 cpd × seed=16) → **125 valid PDB (86%)**, 20 silent-fail cells (predictions/ empty, log rc=0 — 새 5638-only failure mode). Verdict: **GO** with margin.
  - **수치 정정 (2026-05-27 검토)**: 최초 보고 "F1@5Å win 96.7% / +0.455"는 AB f1_5A를 baseline f1_4A(스크립트 default)와 비교한 **metric 불일치** — 4Å→5Å 완화 효과 혼재. 공정 비교(AB f1_4A vs baseline f1_4A): **win 80.3% (98/122), median lift +0.333** (criterion ≥60% 통과).
  - vav1_offset < 5 Å: **90.4%** (113/125 evaluated) / **78%** (113/145 attempted) — evaluated 기준 통과, attempted 기준 80% 바로 아래 (20 silent-fail survivorship bias)
  - median d_tgt_min −0.57 Å (closer to target), F1@4Å median 0.75 / max 0.857, vav1_offset median 3.16 Å / max 24.19 Å (12 AB-resistant outliers)
  - **GO 유지**: vav1_offset axis(evaluated robust) + F1@4Å 공정비교(80.3% ≥60%) 둘 다 통과. 단 margin이 최초 보고보다 얇음.
  - Caveat: cell count 125 < 130 contract §2 threshold (20 silent-fail). F1@5Å은 0.909 saturated — ranking 불가, vav1_offset+F1@4Å이 discriminator
  - Report: [ab_139batch_results.md](../../FKSFold-Boltz_Advancement/analysis/fragmap_spectral_discriminator/reports/ab_139batch_results.md). CSV: `ab_139batch_eval.csv` (125 rows), `ab_139batch_paired_vs_norm143.csv` (122 rows)
- **Step 6 ✅ 완료** (2026-05-27, exploratory DC50 overfit scan, zero-compute): n=84 (DC50 보유), active n=35. 9 metric × Spearman/Pearson × full/active = 36 test, BH-FDR.
  - **Survivors (q<0.05 + expected direction): 0/36** → **강한 overfit-negative 신호**. AB-improved pose quality가 potency와 무관. Within-class ranking null이 이제 4개 method(confidence/F1/MMGBSA ΔΔG/generation geometry)에서 일관.
  - 최강 raw 신호 3개(offset/rotation/centroid spearman full, ρ≈−0.27~−0.31)는 **역방향**(better 9NFR-match → less potent), 단 FDR 후 q≥0.13 비유의. AUC 전부 ≤0.51 (placement metric은 <0.5 anti-predictive).
  - 해석: AB는 **9NFR 한 포즈 재현**일 가능성 높음 — 포즈를 더 잘 맞춰도 더 좋은 binder 아님. Structure recovery(90% 정위치)는 유효하나 potency ranking은 미지원.
  - Power 주의: n=84는 |ρ|≥0.30 검출, n=35 active는 |ρ|≥0.46만 — active subset 약신호는 놓칠 수 있음.
  - Report: [dc50_overfit_scan_20260527.md](../../FKSFold-Boltz_Advancement/analysis/fragmap_spectral_discriminator/reports/dc50_overfit_scan_20260527.md). 명시적 exploratory, gate 판정 아님.
  - Contract: [fragmap-dc50-overfit-scan-20260527.md](../contracts/fragmap-dc50-overfit-scan-20260527.md), Plan: [fragmap-dc50-overfit-scan-20260527.md](../plans/fragmap-dc50-overfit-scan-20260527.md)
- **Step 5 (light filter) — 재평가 필요**: contract approved이나 Step 6 결과로 우선순위 하락. mmgbsa Stage 2 cohort 선별이 목적인데, Step 6가 "포즈가 potency와 무관" 보였으므로 cohort 선별 자체의 가치가 약해짐. Stage 2 go/no-go 결정(별도)이 선행돼야.
- **다음 gated 결정**: Stage 2 MD를 AB 포즈에 투입할지 — Step 6 증거상 potency 예측용으로는 정당화 약함. Step 6b(사전등록 gate, 독립 데이터)로 갈지 / Stage 2 보류할지 사용자 결정.
- **Un-steered recovery 분석 ✅ 완료** (2026-05-27, zero-compute, 진짜 overfit 테스트): DC50가 못 닫은 순환성 질문을 pose correctness로 직접 테스트.
  - **Primary: ligand contact-F1은 구조적으로 완전 순환.** 9NFR VAV1-ligand contact(GT_5A={15,16,18,19,39}, GT_4A={15,16,19})가 **전부 steered pocket(14-19∪32-41) 안** → un-steered ligand contact 0개. F1=0.909는 미는 residue를 채점하므로 구조적 보장값. **ligand pose correctness의 비순환 증거 원천 불가** (지표 한계, 튜닝으로 해결 안 됨).
  - **Secondary: VAV1 rigid-body 배치는 비순환 lean.** CRBN-VAV1 PPI interface의 un-steered residue {13,49,50,51} placement recall **0.908** (steered 0.695보다 높음, gap −0.213) → VAV1 body가 anchor만이 아니라 전역적으로 제 위치. 단 n=4 저power + rigid-body 부분순환 caveat.
  - **종합**: AB는 VAV1 domain 배치는 신뢰성 있게 함(geometric placement 유효), 그러나 **contact-F1 "pose recovery" headline은 순환** — ligand pose correctness 주장 불가. 두 주장은 다름; 배치만 유효.
  - 진짜 비순환 테스트는 held-out crystal (Phase 9 CDK2: nativeAB 0.913 > wrongAB 0.857 > baseline 0.826 = 기존 약신호) 또는 orthogonal experiment. 별도 scope.
  - Report: [unsteered_recovery_20260527.md](../../FKSFold-Boltz_Advancement/analysis/fragmap_spectral_discriminator/reports/unsteered_recovery_20260527.md). Contract: [fragmap-unsteered-recovery-20260527.md](../contracts/fragmap-unsteered-recovery-20260527.md)
- **Sweep wrapper OOM-guard ✅ 수정** (2026-05-27): `slurm_vav1_ab_139batch.sh`의 rc=0-on-OOM 2중 결함 수정 (docker OOM exit 0 + run_cell이 echo로 끝나 fail 카운터 무력) → predictions/*.pdb 부재 시 FAILED(cuda_oom) + return 1. 5638 출력에 retro-검증: 125 PASS/20 FAILED 정확. bash -n clean, cp backup. (mmgbsa worker bug와 동류, 향후 batch silent undercount 방지)
- **Stage 2/overfit decision memo ✅ 작성** (2026-05-27): `stage2_overfit_decision_memo_20260527.md` — 권고 (b)+(a). 사용자 결정 대기.
- **20 silent-fail ✅ 진단완료** (2026-05-27): per-cell 로그 분석 → 전부 **CUDA OOM during diffusion** (18 explicit "ran out of memory, skipping batch"→boltz graceful skip→rc=0; 2개 426/460은 predict loop 진입 전 GPU 교란). 성공 cell은 OOM 0회 → node-wide contention 아닌 **compound-specific peak memory** (8-way/node). **pose-quality 무관** → Step 4 survivorship 해소, 90.4% evaluated가 신뢰값(78% attempted는 과보수적). Report: [ab139_silentfail_diagnosis_20260527.md](../../FKSFold-Boltz_Advancement/analysis/fragmap_spectral_discriminator/reports/ab139_silentfail_diagnosis_20260527.md).
- **잔여 (별도 트랙)**: (a) 20 OOM cell recovery — lower GPU concurrency(4/node 또는 serial) 재실행→~145/145, 작은 SLURM. (b) sweep wrapper의 rc=0-on-OOM 버그 수정 (OOM-skip/predictions 부재를 FAILED로 — mmgbsa worker bug와 동류). (c) wrong-direction 신호 scaffold-confound 점검. (d) held-out crystal로 ligand pose 비순환 검증 (overfit 결정과 연결).
- **Step 5 (conditional)**: light filter recalibration on AB (`p_vav1_lig` threshold + new `vav1_offset < 5Å` metric)
- **Step 6 (conditional)**: DC50 correlation at n=139 (Phase 9 n=5 → proper power)

### Carry-over (lower priority)
- 145 expanded batch 미완성 61개 보충 (OOM/MSA staging interval 늘려서) — Phase 6 잔여
- VAV1_345 등 top hit MGD Phase 2 (50-100ns 정밀 run) — 별도 트랙, 사용자 승인 게이트
- target occupancy의 reference-free recruitment field 정의 — Open Question
- T3 weak late target GD / T4 patch aggregation ablation — fragmap scoring mode ablation
- Production baseline 공식 close-out (Phase 10 결과 후): P7+AB > P7 단독 > expanded 가설 확인

### Orthogonal (mmgbsa slice 별도)
- MMGBSA Stage 2-4 disposition (n=37 v3-original null + 03_npt stall) — `.agent/status/mmgbsa.md` 참조

## Closed (recent)

- ✅ Hybrid pocket weight 시도 — 결론: production 부적합, research tool (Phase 6b, 2026-05-20)
- ✅ Steering health 진단 — verdict GO (Phase 6c, 2026-05-21)
- ✅ Phase 7 CDK2/9D0W pilot — lig-CDK2 F1 0.826 one-shot (2026-05-21, job 5392)
- ✅ F1=0 failure mode diagnostic — `failure_mode_diagnostic.md` (2026-05-21)
- ✅ **Rotamer hypothesis 폐기** — GT 4Å threshold artifact. R17은 crystal에서도 AWAY. (2026-05-21)
- ✅ **VAV1 mispositioning paradigm 확정** (2026-05-21):
  - 139/139 baseline에서 VAV1이 CRBN 대비 17.4 Å 평균 변위 (0개 ≤5Å)
  - F1 vs vav1_offset ρ = −0.44 (p<1e-7)
  - User insight: "ligand 문제가 아니라 VAV1 위치 문제"
- ✅ **Phase 8: VAV1 iface anchor sweep** (job 5395, 13:31, 15 cells)
  - AB (contact + pocket extension) → vav1_offset **3.39 ± 0.29 Å** (80% 감소)
  - F1 @4Å +0.164 lift (5/5 compounds), F1 @5Å 0.909 across all
  - 단일 condition (A or B) 불충분
  - `vav1_iface_anchor_sweep_results.md`
- ✅ **Phase 9: Overfit validation** (job 5398 + zero-compute, 2026-05-21)
  - Cross-target test on 9D0W: wrongAB F1 0.857, nativeAB 0.913, baseline 0.826
    — wrong constraints do NOT crash F1 → AB mechanism is not pure crystal-fit
  - DC50 stratified (n=5): AB top-2 catches 1/2 most potent (vs baseline 0/2), anecdotal
  - VAV1 rigid-body paradigm는 target-dependent — CDK2 hinge prior가 너무 강해 generalize 안 함
  - `overfit_validation.md`
- ✅ **Phase 9 wrap: viz bundle** (2026-05-22)
  - `/home/ubuntu/fragmap_viz_20260522/` — 35 PNGs (신규 9 + 기존 26), `INDEX.md`로 Notion paste 순서 가이드
  - 신규: seed Pareto / top-K enrichment / mispositioning hist+scatter / AB intervention / overfit cross-target / DC50 stratified / decoy / timeline / lessons infographic
  - 기존 보존: d1_paired (6) + steering_health (8) + failure_mode (2) + best_structure (9) + mmgbsa (1)
  - `make_figs.py`로 재현 가능 (CSV inputs는 §Live truth 참조)
- ✅ **CDK2/9D0W ground truth** (2026-05-21) — `examples/9d0w/9D0W.cif`, `9d0w_ground_truth.json`, `9d0w_ground_truth_report.md`. Phase 7+9에서 사용됨
- ✅ **mmgbsa stage 1 verdict** (2026-05-21, mmgbsa subsession) — n=37 v3-original × intdiel=4 × 20ns 결과 **ddTOTAL vs logDC50 Pearson −0.095 (null), AUC 0.426**. Within-class ranking null 확정. mmgbsa Stage 2-4 disposition은 별도 트랙
- ✅ **Within-class ranking null 확정** (2026-05-21) — Critical lesson #2 FALSIFIED: 세 independent method (Boltz iptm, FragMap iface F1, MMGBSA ΔΔG) 모두 within-class ranking null. VAV1 ternary system이 현재 도구 resolution (~kcal/mol) 한계 이하. Coarse discrimination (active vs decoy)은 작동
