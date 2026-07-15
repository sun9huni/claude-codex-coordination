---
contract: .agent/contracts/vav1-ubq-gdi-occupancy-md-dc50-20260715.md
slice: vav1-ubq
status: in-progress
total_tasks: 11
estimated_total_min: 64
---

# Plan: VAV1 GDI-anchor PMF vs DC50 (fixed-model glue placement)

경로(적대검증 후 최종): co-fold/GPU 폐기 → **fixed full-complex 모델에 글루 MCS 배치 → productive_geometry 검증 build로 MD 시스템 → B200서 WTMetaD/OPES PMF → GDI PMF 깊이 vs DC50**. **내 쪽 GPU 없음**(전부 rdkit/tleap/CPU). 유일 외부 게이트 = 유저 B200 MD(Task 9→10 사이).

적대검증 반영 fix: register 확정(K804 apex/K815 anchor), SMILES-중복 제거·n≥15, 관찰량=PMF 깊이(raw 점유율 아님), CV는 VAV1-한정 원자, antechamber net-charge-aware, full assembly(truncation 없음, tleap 파손·Zn소실 회피).

## Task 1: docking 축 NULL 종결 (독립)

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/ikzf3_gt/dock/results_docking_dc50.md`, `.agent/contracts/vav1-ubq-fullcomplex-docking-dc50-20260714.md`, `.agent/plans/vav1-ubq-fullcomplex-docking-dc50-20260714.md`
- **Change shape**: 실 Glide 결과(260715_ubi_test, n=388 r=+0.026/R²=0.001/ρ=−0.073, within-scaffold −0.002, within-cluster −0.005, 포즈 TBD3.2/Lon8/apex24Å, 그림 png/·정렬셋 aligned/) results 문서 + NULL. docking 계약+플랜 status→done, Notes에 NULL + 대체(gdi-occupancy-md) 포인터.
- **Verification**: `grep -c 'NULL\|r=+0.026\|within-cluster\|gdi-occupancy' .agent/scratch/ikzf3_gt/dock/results_docking_dc50.md` → ≥4 AND `grep '^status:' .agent/plans/vav1-ubq-fullcomplex-docking-dc50-20260714.md` → done
- **Estimated time**: 5 min
- **Rollback**: rm results 문서 + revert 두 frontmatter

## Task 2: register 확정 + CV atom 설정 (kill-gate 형식화)

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/vav1_gdi_md/reconcile_register.py`, `.agent/scratch/vav1_gdi_md/cv_config.json`
- **Change shape**: fixed 모델 + 9NFR서 5개 VAV1 Lys Nζ→apex(Ub-G76-C)·→Lon(I152/H103/F102) 측정 → register 확정(K804=apex/K815=anchor), 6월29 graft-pose 모순 주석. cv_config.json에 frozen CV atom(GDI: VAV1 K815 NZ / CRBN I152 ; apex: VAV1 K804 NZ / Ub G76 C ; 보조 N813-H103, W831-F102) — 전부 VAV1-한정, chain+resnum+atom 명시.
- **Verification**: `python3 .agent/scratch/vav1_gdi_md/reconcile_register.py` → `model: apex-nearest K804(12.1) Lon-nearest K815(5.0); 9NFR K815-I152 3.8; register=K804 apex/K815 anchor` + cv_config.json 존재
- **Estimated time**: 5 min
- **Rollback**: rm reconcile_register.py cv_config.json

## Task 3: 화합물 선정 (중복제거 + n≥15 + net-charge)

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/vav1_gdi_md/select_compounds.py`, `.agent/scratch/vav1_gdi_md/pilot_compounds.csv`
- **Change shape**: in-house 단일assay boron-free non-censored를 **canonical-SMILES 중복 제거**(AIG22071A/B 등 동일구조 1개만) 후 log-DC50 spanning n≥15 선정(26개 pool). RDKit 파싱·net-charge 계산 컬럼 추가(antechamber용). CSV(compound_id, SMILES, DC50_nM, log_DC50, net_charge).
- **Verification**: `python3 .agent/scratch/vav1_gdi_md/select_compounds.py && python3 -c "import csv;r=list(csv.DictReader(open('.agent/scratch/vav1_gdi_md/pilot_compounds.csv')));s=[x['SMILES'] for x in r];print('n',len(r),'uniq',len(set(s)),'charges',sorted(set(x['net_charge'] for x in r)))"` → n≥15, uniq==n(중복없음)
- **Estimated time**: 5 min
- **Rollback**: rm select_compounds.py pilot_compounds.csv

## Task 4: GDI/PMF 지표 스크립트 (+ selftest + 9NFR 캘리브레이션)

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `.agent/scratch/vav1_gdi_md/gdi_metric.py`
- **Change shape**: cv_config.json 읽어 구조/궤적서 GDI CV(K815 Nζ-I152) 거리 + 보조 접촉 + apex CV(K804 Nζ-Ub-G76-C) 측정. 궤적 모드: WTMetaD/OPES bias log → reweight PMF 깊이(ΔG) + occupancy(saturation 사전확인용). 단일구조 캘리브레이션 모드. `--selftest`(합성좌표), `--calibrate 9NFR`.
- **Verification**: `python3 .agent/scratch/vav1_gdi_md/gdi_metric.py --selftest && python3 .agent/scratch/vav1_gdi_md/gdi_metric.py --calibrate /home/ubuntu/9NFR_crystal.pdb` → `selftest PASS` + `9NFR GDI CV K815-I152 3.8A = ENGAGED`
- **Estimated time**: 6 min
- **Rollback**: rm gdi_metric.py

## Task 5: 글루 배치 (fixed 모델에 MCS 정렬)

- **Status**: done
- **Prereq tasks**: 3
- **Files touched**: `.agent/scratch/vav1_gdi_md/place_glues.py`, `.agent/scratch/vav1_gdi_md/placed/` (글루별 full-complex PDB)
- **Change shape**: fixed 모델(vav1_fullcx_nativepose_declashed_full.pdb)의 A1B(chain G) 좌표를 기준으로, 각 pilot 글루를 MCS(A1B와 공유 core, feasibility 55-72% 확인됨)로 constrained-embed(rdkit)해 A1B 위치에 정렬 → 모델의 A1B를 배치 글루로 치환, 나머지 8체인(machine+CRBN+VAV1)·Zn 유지 → placed/<id>.pdb. 가변부는 core 정렬 후 임베드(MD가 이완).
- **Verification**: `python3 .agent/scratch/vav1_gdi_md/place_glues.py && ls .agent/scratch/vav1_gdi_md/placed/*.pdb | wc -l` → == n; 각 PDB에 9체인 + Zn + 배치 글루 존재
- **Estimated time**: 8 min
- **Rollback**: rm place_glues.py placed/*

## Task 6: 배치 검증 (GDI 유지·core RMSD·clash)

- **Status**: done
- **Prereq tasks**: 4,5
- **Files touched**: `.agent/scratch/vav1_gdi_md/check_placement.py`, `.agent/scratch/vav1_gdi_md/placement_report.md`
- **Change shape**: 배치 글루별로 (a) glue core가 A1B에 정렬됐나(MCS 원자 RMSD), (b) GDI 접촉(K815-I152 등) 배치로 안 깨졌나(gdi_metric), (c) 글루-단백 clash 없나. 실패 글루 플래그. A1B 자기 재배치를 sanity 대조로.
- **Verification**: `python3 .agent/scratch/vav1_gdi_md/check_placement.py` → 글루별 `core RMSD <Å>, GDI K815-I152 <Å>, clash <n>` 표 + PASS/FLAG
- **Estimated time**: 5 min
- **Rollback**: rm check_placement.py placement_report.md

## Task 7: MD 시스템 빌드 (full assembly + junction + VAV1-한정 CV)

- **Status**: pending
- **Prereq tasks**: 2,6
- **Files touched**: `.agent/scratch/vav1_gdi_md/build_md_systems.py` (+ kfs2 systems/<cmpd>/ prmtop/inpcrd/atom_index.json)
- **Change shape**: productive_geometry build(param_tleap/parmed_junction_fix/build_md_system) **로컬 복사본**을 배치 full-complex에 적용 — full assembly(CUL4A/NEDD8/E2/Ub/RBX1/Zn 다 존재)라 스크립트 그대로 작동. thioester(E2 Cys85 S-C) + isopeptide(N-C) junction. **antechamber는 화합물 net_charge 전달**(하드코딩 0 금지). atom_index.json: cv_config 기반 **VAV1-한정** GDI CV(K815 NZ/I152) + apex CV(K804 NZ/Ub-G76 C). t0 sanity(GDI 거리=배치와 일치).
- **Verification**: `python3 .agent/scratch/vav1_gdi_md/build_md_systems.py --verify` → 글루별 prmtop/inpcrd + junction(thio 1.81/iso 1.335Å) present + atom_index CV가 VAV1 K815/K804 가리킴 + t0 GDI 오차 <0.1Å
- **Estimated time**: 9 min
- **Rollback**: rm build_md_systems.py + kfs2 systems/

## Task 8: WTMetaD/OPES PLUMED + driver 설정

- **Status**: pending
- **Prereq tasks**: 7
- **Files touched**: `.agent/scratch/vav1_gdi_md/plumed/` (per-cmpd plumed.dat), `.agent/scratch/vav1_gdi_md/crl_md_run.py`
- **Change shape**: crl_md_run.py(OpenMM+openmm-plumed) 로컬 복사 수정 — GDI 거리 CV(K815 NZ-I152)에 WTMetaD/OPES bias + apex CV(2차) 병행 출력 + reweight/수렴출력. plumed.dat: GDI CV bias(국소·shallow라 near-attack보다 좁은 범위/빠른 수렴), 중성 Lys 주석. min/equil/production 단계.
- **Verification**: `python3 -c "import ast;ast.parse(open('.agent/scratch/vav1_gdi_md/crl_md_run.py').read());print('driver OK')"` + `grep -c 'METAD\|OPES\|K815\|DISTANCE' .agent/scratch/vav1_gdi_md/plumed/*.dat | head` → CV·bias 존재
- **Estimated time**: 6 min
- **Rollback**: rm -r plumed/ crl_md_run.py

## Task 9: B200 패키지 tar.gz

- **Status**: pending
- **Prereq tasks**: 8
- **Files touched**: `.agent/scratch/vav1_gdi_md/package/` (systems/·plumed/·run/·README.md), `.agent/scratch/vav1_gdi_md/vav1_gdi_md_b200.tar.gz`
- **Change shape**: chronobridge md-generation 형식 — systems/<cmpd>(prmtop/inpcrd/atom_index) + plumed/ + run/(crl_md_run.py) + README(B200 실행 명령·OpenMM/CUDA/PLUMED 버전·화합물별 GPU-hr 추정·수렴판정 기준·회수 산출[PMF/bias/궤적/거리시계열]). tar.gz.
- **Verification**: `tar tzf .agent/scratch/vav1_gdi_md/vav1_gdi_md_b200.tar.gz | grep -c 'prmtop\|plumed\|crl_md_run\|README'` → ≥ (n+3); README에 실행명령+버전+회수산출
- **Estimated time**: 6 min
- **Rollback**: rm -r package/ vav1_gdi_md_b200.tar.gz

## Task 10: GDI PMF 상관분석 + 2단계 게이트 (B200 MD 이후)

- **Status**: pending
- **Prereq tasks**: 4,9
- **Files touched**: `.agent/scratch/vav1_gdi_md/gdi_occupancy_correlation.py`, `.agent/scratch/vav1_gdi_md/correlation_results.csv`
- **Change shape**: **유저 B200 MD 산출(bias/PMF/궤적) 회수 후.** gdi_metric로 글루별 GDI PMF 깊이(+apex, +occupancy sanity) → log-DC50 Spearman ρ + **permutation p** + bootstrap CI + 수렴진단(block-error/시간수렴/replica 일치). 2단계 게이트(ρ≥0.6 & p<0.05 PASS / 0.3-0.6 apex escalate / else NULL).
- **Verification**: `python3 .agent/scratch/vav1_gdi_md/gdi_occupancy_correlation.py --md <b200_outdir> --dc50 pilot_compounds.csv` → GDI PMF/apex vs log-DC50 ρ·perm-p·CI·n + 수렴 + 게이트 PASS/ESCALATE/NULL
- **Estimated time**: 5 min (회수 후)
- **Rollback**: rm gdi_occupancy_correlation.py correlation_results.csv

## Task 11: results 문서 + baton 갱신

- **Status**: pending
- **Prereq tasks**: 10
- **Files touched**: `.agent/scratch/vav1_gdi_md/results_gdi_occupancy.md`, `.agent/status/vav1-ubq.md`
- **Change shape**: GDI PMF vs DC50 표 + 9NFR 재현 + 수렴진단 + 2단계 게이트 + 설계 함의(PASS면 Lon-도달 글루 설계 근거) 기록. baton remaining_actions 갱신.
- **Verification**: `grep -c 'ρ\|Spearman\|PASS\|ESCALATE\|NULL\|9NFR' .agent/scratch/vav1_gdi_md/results_gdi_occupancy.md` → ≥4; baton last_updated=오늘
- **Estimated time**: 4 min
- **Rollback**: rm results_gdi_occupancy.md + revert baton
