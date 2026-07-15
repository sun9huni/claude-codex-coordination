---
slice: vav1-ubq
cross_slice: [aigen-fold-core, sar]
status: approved
requested: 2026-07-15
approved_by: user 2026-07-15
---

# VAV1 GDI-anchor occupancy MD vs DC50 (dynamics discriminator, supersedes NULL docking)

## Purpose

정적 docking이 VAV1 효능을 못 예측함을 확정한 뒤(실 Glide n=388 r=0.03 R2=0.001 NULL, 260715_ubi_test), VAV1이 IKZF3처럼 GDI-유사 앵커를 가져 ubiquitination을 돕는가를 동역학으로 검증한다. 실험 9NFR에서 관측된 VAV1-Lon 앵커(K815 Nζ-CRBN I152 3.6Å / N813-H103 3.2Å / W831-F102 3.8Å)의 MD 접촉 안정성(점유율·자유에너지)이 in-house DC50를 가르는지 본다. 성공 시 (1) 정적 docking이 못 준 VAV1 구조기반 DC50 예측자 확보, (2) Lon-도달 글루 설계 전제 검증을 동시에 얻는다.

## Current State

- docking 축 NULL 확정: receptorA_full에 실 Glide SP 388개(특허 WO2024151547) → GScore vs log-DC50 r=+0.026/ρ=−0.073, within-scaffold ρ=−0.002, within-FP-cluster ρ=−0.005. 포즈 실측: 글루가 TBD 3.2Å에 정착하나 Lon 8Å·apex 24Å 미도달 = 글루-스코어가 잴 게 없음(mechanism). 그림 260715_ubi_test/png/, 정렬셋 260715_ubi_test/aligned/.
- 근본 원인: rigid docking이 VAV1을 얼려 글루별 배향 차이(효능 결정자)를 구조적으로 못 봄. coord-GD(생성/강제) DC50 discriminator도 NULL(ρ0.14) — 생성은 기하를 강제할 뿐 열역학 저항을 안 잼. MD WTMetaD만 신호(ρ0.714, n=8, 결함 有).
- 실험 앵커: 9NFR(X-ray 삼원)에 VAV1-Lon GDI 접촉 실재(K815-I152 3.6/N813-H103 3.2/W831-F102 3.8Å). 글루 A1B는 TBD-only라 이 계면을 단백질에 통째로 맡김 = 설계·검증 여지.
- 포즈 생성 방식(2026-07-15 적대검증 후 최종): co-fold 폐기 → **fixed full-complex 모델 + 글루 MCS 배치**. 검증된 full assembly(vav1_fullcx_nativepose_declashed_full 계열, Zn·loaded E2~Ub 3.71Å·full scaffold 보유)에 각 글루를 A1B에 MCS-constrained 정렬로 얹음. **내 쪽 GPU 없음**(글루 배치=rdkit, MD 시스템=tleap/CPU; Boltz 재넘버링·Zn소실·E2~Ub drift·RBX1 gap 전부 회피). productive_geometry의 검증된 param_tleap/parmed_junction_fix가 이 full assembly용이라 그대로 작동.
- 관찰량(적대검증 후 최종): raw unbiased 점유율 폐기(saturation·build품질 지배 위험) → **GDI-앵커 결합 자유에너지(PMF 깊이)**를 WTMetaD/OPES(GDI 거리 CV)로. unbiased 점유율은 saturation 여부 싼 사전확인용만. 이전 유일 양성 신호(ρ0.714)가 FES 장벽이었음과 정합.
- register 확정(kill-gate, 2026-07-15): canonical 모델서 **K804=apex(12.1Å), K815=Lon-anchor(I152 5.0Å)**; 모델↔9NFR 일치. 6월29 "K815 near Ub"는 다른 graft 포즈. CV 원자: GDI=K815 Nζ-CRBN I152, apex(2차)=K804 Nζ-Ub G76-C.
- 준비(.agent/scratch/vav1_gdi_md/): pilot_compounds.csv(in-house boron-free non-censored). 글루 MCS feasibility 확인(A1B와 55-72%). AIG22071A/B는 SMILES 동일이라 1개만.
- 재사용: aigen-fold-core 2-stage 파이프라인(api.pipeline.build_stage2_yaml, VAV1_CONFIG), productive_geometry_20260629/build/*(full-assembly + thioester/isopeptide junction), crl_md_run.py(OpenMM), crl_atom_index.json.

## Assumptions And Questions

- assumptions: 9NFR GDI 앵커가 full-complex(machine 부착)에서도 생산적으로 유지된다(검증 대상); congeneric 시리즈가 이 앵커 안정성서 변별된다(글루가 VAV1을 직접 붙들어 배향 편향, 도킹서 19/29원자 VAV1 접촉 = 물리적 근거); in-house DC50 단일assay가 strict 상관 전제 성립.
- open questions: 점유율이 saturated(글루 무관 상수)일 가능성; truncation이 Lon conformation 왜곡 여부; 짧은 unbiased MD 수렴; stage-2 포즈가 9NFR GDI 재현하나.
- tradeoffs: non-censored만(값 신뢰 우선, 유저 결정) → 범위 ~2.2log로 좁아 n=8은 검정력 약함 → non-censored 내에서 n을 15±로 늘려 보강(범위 넓히지 않고 표본만); GDI-점유율(equilibrium)은 near-attack 장벽(transition-state)보다 싸고 실험-anchored지만 촉매속도의 직접 대리물은 아님(positioning proxy).

## Constraints

- allowed change scope: `.agent/scratch/vav1_gdi_md/`(글루 배치·MD 시스템 빌드·B200 패키지·분석), kfs2 출력. B200 MD는 유저 서버(파일 scp/rsync). **내 쪽 SLURM/GPU 없음**(글루 배치=rdkit, tleap=CPU).
- forbidden change scope: 엔진/api·productive_geometry build 스크립트 read-only 재사용(로컬 복사본만 수정); host tree 미변경; kfs5/kfs6 출력 금지(kfs2만); 글루 신규 설계 루프는 별도 계약.
- external constraints: DC50 = in-house 단일assay·boron-free·non-censored·SMILES-중복제거(force-field 청정 + 값 신뢰). fixed 모델 = vav1_fullcx_nativepose_declashed_full 계열(full assembly, Zn·loaded E2~Ub 보유). 9NFR = 독립 실험 검증 앵커. B200 MD는 유저 실행.

## Non-Goals

- Lon-도달 VAV1 글루 신규 설계(별도 계약 — 이 계약은 예측자·전제 검증까지).
- 전체 셋 MD(파일럿 spanning n≥15만; 확대는 게이트 PASS 후).
- co-fold 포즈 생성(적대검증서 폐기 — Zn소실·재넘버링·E2~Ub drift; fixed-model 배치로 대체).
- truncation(적대검증서 tleap 파손·기하왜곡 위험 → full assembly 사용, 검증된 productive_geometry 시스템 재사용).
- boron 함유 화합물(48%, force-field gap; 파일럿 제외).
- docking 축 재측정(NULL 확정, 이 계약이 대체).

## Done When

2단계 게이트로 판정(성공/escalation/NULL 다 valid outcome). 통계는 적대검증 반영: **n≥15**(non-censored non-boron 26개 실재), 단일 사전등록 관찰량 + **permutation p** + bootstrap CI, 범위 천장 2.2log 명시(pilot):

- **PASS**: GDI-앵커 결합 자유에너지(GDI 거리 CV WTMetaD/OPES PMF 깊이) vs log-DC50 **Spearman ρ≥0.6 & permutation p<0.05 & CI 0 제외** AND PMF 수렴 확인 AND A1B/근접 화합물이 9NFR GDI 재현. → VAV1 GDI-앵커가 효능 예측자로 확립, 확대 + 설계 계약 근거.
- **ESCALATE**: ρ 0.3-0.6 → apex 자유에너지(K804 Nζ→Ub-G76-C, ρ0.714 재현 셋업)로 2차 판정.
- **NULL**: 둘 다 미달 → GDI-앵커 자유에너지는 DC50 축 아님, 문서화.
- 검증 커맨드: `python3 .agent/scratch/vav1_gdi_md/gdi_occupancy_correlation.py --md <b200_outdir> --dc50 pilot_compounds.csv` → 화합물별 GDI PMF 깊이 + apex + Spearman ρ/perm-p/CI + 9NFR 재현 + 게이트 판정.
- 산출: results 문서(PMF vs DC50 표 + 9NFR 재현 + 수렴진단 + 게이트) + B200 패키지(tar.gz).

## Phase Gates (실행 순서)

1. **Phase 0 (zero-GPU, 완료됨)**: register 재조정(K804 apex/K815 anchor 확정) + 글루 MCS feasibility + 화합물 셋 + GDI/PMF 지표 정의 + 9NFR 캘리브레이션.
2. **Phase 1 (zero-GPU)**: 각 글루를 fixed full-complex 모델에 A1B-MCS 정렬로 배치 → 배치 검증(GDI 접촉 유지, core RMSD, clash).
3. **Phase 2 (zero-GPU 준비 + B200 MD)**: MD 시스템 빌드(full assembly + 배치 글루, productive_geometry param_tleap/junction 재사용, GDI+apex CV atom-index) → WTMetaD/OPES PLUMED(GDI 거리 CV) → B200 패키지 → 유저 B200서 향상표집 MD(수렴까지, ×2-3 replica).
4. **Phase 3 (zero-GPU, B200 이후)**: GDI PMF 깊이 + apex 측정 → DC50 상관(ρ/perm-p/CI) → 2단계 게이트 → results + baton.

## Triggers matched

- cross_slice: aigen-fold-core(엔진·productive_geometry build read-only), sar(DC50). shared-storage 쓰기(kfs2).
- 4+ 파일(scratch 배치·빌드·분석·패키지). **내 쪽 SLURM/GPU 없음**(fixed-model 배치·tleap 전부 CPU). B200 MD는 유저 compute(외부).

## Resource budget

- 내 몫: **zero GPU-hour**(글루 배치 rdkit + MD 시스템 tleap/CPU + 패키지 + 측정). 
- MD: 유저 B200. 화합물당 full-assembly WTMetaD/OPES 수렴까지(GDI CV는 국소·shallow라 near-attack보다 빠른 수렴 기대) × 2-3 replica; pilot n≥15 = 유저 서버 수일. GPU 풍부(유저 B200).

## Risks

- GDI PMF가 글루 무관(saturated) → flat. 완화: 글루가 VAV1 직접 접촉(19/29원자)이라 배향/앵커 안정성 편향 물리적 근거; PMF 깊이는 raw 점유율과 달리 saturation서도 차이 드러냄; pilot이 직접 판정.
- non-censored 범위 좁음(2.2log)+n. 완화: n≥15(26개 실재), permutation p, pilot 명시.
- 순환성(fixed 모델의 GDI를 재서 안정성 측정). 완화: MD가 시작포즈 아닌 열역학 안정성을 재고, 9NFR(실험) 재현 게이트로 앵커 진위 교차확인.
- 시작 포즈가 모델(full-complex GDI conformation; 9NFR은 machine 없는 ternary라 앵커의 full-complex 지속성 미검증). 완화: MD서 앵커 안정성 관찰 + 9NFR 재현.
- WTMetaD/OPES 미수렴 → spurious ρ. 완화: replica + block-error + 시간수렴 진단.
- AIG22071A/B 등 SMILES-중복은 구조지표로 원리상 구분 불가. 완화: 중복 제거(Task 3).

## Rollback

- revert strategy: 전부 `.agent/scratch/` + git commit + kfs2 출력. revert로 원복, 외부 부작용 없음(B200는 유저 서버, 유저가 파일 관리).
- containment strategy: 각 Phase 게이트서 STOP 가능. NULL/ESCALATE도 valid outcome이라 문서화하고 종료·이관. stage-2 GPU는 소량이라 낭비 미미.

## Progress Log

- 2026-07-15 HH:MM: 계약 초안. Phase 0(템플릿·화합물·YAML·GDI지표) 완료 상태. docking 계약(vav1-ubq-fullcomplex-docking-dc50-20260714)은 NULL 종결 예정, 이 계약이 대체.
