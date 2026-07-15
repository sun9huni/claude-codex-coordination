---
contract: .agent/contracts/vav1-ubq-fullcomplex-docking-dc50-20260714.md
slice: vav1-ubq
status: done
total_tasks: 10
estimated_total_min: 34
---

# Plan: VAV1 full-complex Glide docking-score vs DC50

phase 순서: Data → Receptor/grid prep → Analysis tool → Pilot(hard gate) → Full → Docs.
USER GATE 태스크(6, 9)는 유저가 Maestro서 Glide 실행하는 handoff 지점(내 code diff 아님) — /execute-plan은 여기서 멈추고 유저 산출을 기다린다. zero-GPU(내 몫).

## Task 1: 단일-assay VAV1 DC50 시리즈 식별 + 화합물 테이블

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/ikzf3_gt/dock/build_dc50_series.py`, `.agent/scratch/ikzf3_gt/dock/dc50_series.csv`
- **Change shape**: sar/vav1-ubq DC50 데이터에서 same-source/single-experiment(단일 assay) 시리즈를 식별하는 스크립트 + 출력 CSV(compound_id, SMILES, DC50, log_DC50, assay_source, censored flag). 가장 큰 단일-assay 배치를 고른다(strict R² bar 전제). 여러 배치면 각 배치 n + 출처를 로그.
- **Verification**: `python3 .agent/scratch/ikzf3_gt/dock/build_dc50_series.py` → `단일-assay 시리즈: source=<X>, n=<N>, DC50 range <a>-<b>, censored <c>` 출력 + CSV 행수 == N
- **Estimated time**: 5 min
- **Rollback (if this task only)**: rm build_dc50_series.py dc50_series.csv

## Task 2: Receptor A (full) Maestro-prep-ready + reference ligand 추출

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/ikzf3_gt/dock/prep_receptors.py`, `.agent/scratch/ikzf3_gt/dock/receptorA_full.pdb`, `.agent/scratch/ikzf3_gt/dock/ref_ligand_a1b.pdb`
- **Change shape**: baseline(vav1_fullcx_nativepose_declashed_full.pdb)를 복사해 receptorA_full.pdb로 저장(단백질+ion, A1B 글루 분리), A1B(chain G)를 ref_ligand_a1b.pdb로 추출(grid 중심용). prep_receptors.py가 검증(9→단백질 체인, clash-free, ref ligand 원자수). Protein-Prep Wizard 세팅은 grid_spec 문서(Task 4)에 명시(유저 실행).
- **Verification**: `python3 .agent/scratch/ikzf3_gt/dock/prep_receptors.py --check A` → `receptorA: chains=[C,D,N,U,R,B,A,V], ref_ligand A1B <n>atoms, VAV1<->E2/CRBN clash 0`
- **Estimated time**: 4 min
- **Rollback (if this task only)**: rm receptorA_full.pdb ref_ligand_a1b.pdb (prep_receptors.py는 Task 3와 공유)

## Task 3: Receptor B (ternary 대조) 생성

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `.agent/scratch/ikzf3_gt/dock/prep_receptors.py`, `.agent/scratch/ikzf3_gt/dock/receptorB_ternary.pdb`
- **Change shape**: prep_receptors.py에 ternary 모드 추가 — baseline서 촉매모듈(E2=D, Ub=U, NEDD8=N, RBX1=R, CUL4=A) strip + glue(G)도 제거(도킹 리간드) → CRBN(C)+DDB1(B)+VAV1(V) = 논문 Fig4C 대조 receptor(8D7Z=CRBN/DDB1/neosubstrate ternary와 동형, receptorA처럼 glue-removed). receptorB_ternary.pdb 저장.
- **Verification**: `python3 .agent/scratch/ikzf3_gt/dock/prep_receptors.py --check B` → `receptorB: chains=[C,B,V], no E2/Ub/RBX1/NEDD8/CUL4/glue`
- **Estimated time**: 3 min
- **Rollback (if this task only)**: rm receptorB_ternary.pdb + revert prep_receptors.py ternary block

## Task 4: Glide grid + Maestro 세팅 가이드 문서

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `.agent/scratch/ikzf3_gt/dock/glide_setup_guide.md`
- **Change shape**: 유저 Maestro 실행용 가이드 — grid center=(133.18, 93.86, 153.25), inner box ~12Å, outer box ~32-36Å, GDI-side 재정의(CRBN Lon H103/F102/F150), Protein Prep(add H/PropKa pH7/restrained-min 0.3Å OPLS4), LigPrep(Epik pH7±2, stereoisomer), **Glide SP unconstrained**(constraint/IFD 금지=재현 조건). receptorA/B 둘 다 동일 grid. 논문 대조(full vs ternary) 명시.
- **Verification**: `grep -c '133.18\|outer\|H103\|standard precision\|unconstrained' glide_setup_guide.md` → ≥5
- **Estimated time**: 4 min
- **Rollback (if this task only)**: rm glide_setup_guide.md

## Task 5: 분석 스크립트(docking_dc50_correlation.py) 작성 + selftest

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/ikzf3_gt/dock/docking_dc50_correlation.py`
- **Change shape**: Glide 출력(GScore CSV: compound_id, gscore [, pose_pdb]) + receptor를 받아 (1) GScore vs log_DC50, (2) 도킹 포즈의 글루→CRBN Lon(H103/F102/F150) min-heavy engagement 거리 vs log_DC50를 각각 R²/Pearson/Spearman 계산(pure-stdlib + gemmi/numpy). full/ternary 두 입력 비교. `--selftest`로 합성 데이터에 대해 통계 함수 검증.
- **Verification**: `python3 .agent/scratch/ikzf3_gt/dock/docking_dc50_correlation.py --selftest` → `selftest PASS (R2/Pearson/Spearman on synthetic OK)`
- **Estimated time**: 5 min
- **Rollback (if this task only)**: rm docking_dc50_correlation.py

## Task 6: Pilot 화합물셋 선정 (~15-20, DC50 spanning)

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/ikzf3_gt/dock/select_pilot.py`, `.agent/scratch/ikzf3_gt/dock/pilot_set.csv`
- **Change shape**: dc50_series.csv서 DC50 범위를 spanning하는 15-20개 선정(quantile bins서 균등 추출) → pilot_set.csv(compound_id, SMILES, DC50).
- **Verification**: `python3 .agent/scratch/ikzf3_gt/dock/select_pilot.py` → `pilot n=<15-20>, DC50 span <a>-<b> covers full range` + CSV 행수 확인
- **Estimated time**: 3 min
- **Rollback (if this task only)**: rm select_pilot.py pilot_set.csv

## Task 7: Pilot smina docking (claude, re-scoped from Glide — 유저가 Maestro 접근 불가)

- **Status**: pending
- **Prereq tasks**: 2,4,6
- **Files touched**: `.agent/scratch/ikzf3_gt/dock/run_smina_dock.sh`, `.agent/scratch/ikzf3_gt/dock/prep_ligands.py`, `.agent/scratch/ikzf3_gt/dock/pilot_gscore.csv` (+ pose SDF dir on kfs2)
- **Change shape**: RE-SCOPE — Glide 접근 불가라 smina로 대체(gnina는 github/docker egress 차단으로 불가; smina raw + flat 시 MM-GBSA rescoring으로 민감도 보강), executor=claude. pilot_set(19) SMILES → 3D(rdkit/obabel) → smina docking(receptorA_full.pdb, box center 133.18/93.86/153.25, size ~32-36Å 또는 pilot서 조정) → smina affinity(Vinardo/Vina) 추출 → pilot_gscore.csv(compound_id, gscore[=smina affinity], pose_sdf). smina raw docking(논문 raw-score 재현); raw flat 시 MM-GBSA rescoring(우리 파이프라인) 보강. GPU 사용.
- **Verification**: `python3 -c "import csv;r=list(csv.DictReader(open('.agent/scratch/ikzf3_gt/dock/pilot_gscore.csv')));print('pilot gscore rows',len(r),'cols',list(r[0].keys()))"` → rows == 19, cols include compound_id+gscore
- **Estimated time**: 15-30 min (설치+prep+GPU docking)
- **Rollback (if this task only)**: rm run_smina_dock.sh prep_ligands.py pilot_gscore.csv

## Task 8: Pilot hard gate 분석

- **Status**: pending
- **Prereq tasks**: 5,7
- **Files touched**: `.agent/scratch/ikzf3_gt/dock/pilot_gate_verdict.md`
- **Change shape**: docking_dc50_correlation.py를 pilot_gscore.csv에 실행 → GScore/Lon-engagement 분포 + DC50 trend. **gate 판정**: spread 있고(GScore std 유의) DC50 방향으로 흔들리면 PASS→Task 9, flat이면 STOP(NULL 판정, dynamics로 이관). verdict 문서에 기록.
- **Verification**: `python3 .agent/scratch/ikzf3_gt/dock/docking_dc50_correlation.py --input pilot_gscore.csv --receptor receptorA_full.pdb` → GScore/Lon-engagement 분포+trend 출력, verdict PASS/STOP 명시
- **Estimated time**: 3 min
- **Rollback (if this task only)**: rm pilot_gate_verdict.md

## Task 9: 전체 단일-assay 셋 smina docking (full + ternary) (claude)

- **Status**: pending
- **Prereq tasks**: 3,8
- **Files touched**: `.agent/scratch/ikzf3_gt/dock/full_gscore_A.csv`, `.agent/scratch/ikzf3_gt/dock/full_gscore_B.csv` (+ pose SDF dirs on kfs2)
- **Change shape**: **Task 8 gate PASS 시에만.** 전체 단일-assay 셋(399)을 receptorA(full) + receptorB(ternary) 둘 다 smina docking → CNNaffinity + Vina + 포즈. GPU(SLURM kim, 병렬). full+ternary CSV 산출.
- **Verification**: `test -f full_gscore_A.csv -a -f full_gscore_B.csv` + 행수 == 시리즈 n(≈399)
- **Estimated time**: GPU 병렬 ~1-3h
- **Rollback (if this task only)**: rm full_gscore_A.csv full_gscore_B.csv

## Task 10: 최종 상관분석 + PASS/NULL 판정 + results 문서 + baton

- **Status**: pending
- **Prereq tasks**: 5,9
- **Files touched**: `.agent/scratch/ikzf3_gt/dock/results_docking_dc50.md`, `.agent/status/vav1-ubq.md`
- **Change shape**: docking_dc50_correlation.py를 full_gscore_A/B에 실행 → GScore+Lon-engagement vs log-DC50, full vs ternary R²/r/ρ. 계약 Done-When 판정: PASS(R²>0.7 또는 r>0.8 AND full>>ternary) 또는 NULL(flat→dynamics). results 문서 + baton remaining_actions 갱신.
- **Verification**: `python3 .agent/scratch/ikzf3_gt/dock/docking_dc50_correlation.py --input full_gscore_A.csv --ternary full_gscore_B.csv --receptor receptorA_full.pdb --ternary-receptor receptorB_ternary.pdb` → full/ternary R²·r·ρ + n + PASS/NULL verdict
- **Estimated time**: 5 min
- **Rollback (if this task only)**: rm results_docking_dc50.md + revert baton
