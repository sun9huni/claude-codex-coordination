---
status: done
slice: aigen-fold-core
topic: assembly-closure-generation
date: 2026-06-23
owner: claude
approved_by: user (2026-06-23, "승인")
requested: 2026-06-23
cross_slice:
  - "aigen-fold-core (coordinate): boltz_extension/steering 엔진 코드(potentials.py, interface_steering_utils.py, diffusionv2_extend.py)는 aigen-fold-core 소관 + #12 wiring WIP와 얽힘 → 신규 potential 추가 시 owner와 조율(별도 checkpoint/flag-gated)"
triggers_matched:
  - "신규 생성 semantics — 생성-시간 CRLClosurePotential(reward) + CRLClosureIK(proposal). prior가 뽑는 포즈를 바꿈"
  - "SLURM/GPU submission — Stage 2 paired generation, Stage 3 positive-control + IK 런"
  - "shared-storage writes — /mnt 워크스페이스 생성 출력"
  - "4+ files / 신규 코드 — crl_closure_potential.py + crl_closure_ik.py + config 필드 + apply_interface_gd/diffusionv2_extend edits + spec 생성기 2개"
---

# Assembly-Closure Generation — crystal 없는 CRBN–glue–VAV1 삼원의 *구조*를, 활성 CRL4 기계 기하로 자세 축퇴를 collapse시켜 예측 (STRUCTURE-ONLY)

## Purpose

VAV1 mgd 삼원은 **crystal이 없다**. **glue–CRBN + VAV1–CRBN/glue 접촉이 *잔기-잔기 수준(양쪽 잔기)* 으로 알려졌으나**(=주어진 binding 제약), **3D neo-interface 자세는 미지**고 그 계면은 평평·얕고 OOD(coevolution 신호 0) → 학습 predictor(AF3/Boltz)·모든 재가중치 scheme이 무너진다(deepsample falsification CONFIRMED: prior는 *증폭기*지 basin 생성기 아님; 붕괴타깃 best-of-64 DockQ 9DWW 0.008/9H59 0.016 < 0.10).

**핵심 베팅(신박)**: 평평한 *2체* neo-interface는 under-determined지만 ***전체 활성 CRL4 어셈블리*는 over-determined**다 — VAV1 자세는 얕은 계면이 아니라 **보존·리간드-무관한 E2~Ub thioester near-attack cone(9UUM)에 기질 라이신이 닿아야 한다는 하류 boundary condition**이 핀으로 박는다. 그 cone 기하는 E3 ligase의 성질(모든 neo-substrate 공통)이라 **주입해도 답을 주입하는 게 아니다**. 6-DOF 자유 부채꼴이 **≤3-DOF manifold로 collapse**한다.

목표는 **구조 예측 정확도뿐**(활성·순위 아님 — 그 레인은 KILL됨, 엮지 않는다).

★**목표 확정(사용자 2026-06-23)**: 아직 없는 VAV1 삼원 **crystal을 최대한 재현**하는 *가장 정확한 구조 모델* 산출 + **YDS-GlueFold/AF3 모델을 교차검증·보강**. 즉 (a) 독립 방법으로 진짜 삼원을 예측해 published 모델들과 *수렴*하면 crystal 부재서 신뢰↑, (b) 우리 assembly-closure가 더하는 제약(catalytic-competence: 라이신이 E2~Ub cone 도달)으로 YDS/AF3 포즈가 *생산적인지*까지 본다. 검증 = mutagenesis 접촉(R796/D797/S799↔W400/H357/N351) 재현(=crystal proxy GT) + held-out 결정(9OTY/9Q33) + G1/G2 self-consistency.

## Current State

- **엔진 배관(검증됨, grounding wf_164275dd)**: `potentials.py` Potential ABC(compute/compute_gradient), `FlatBottomPotential`(:235)·`DistancePotential`(:306), `GlueprintPotential`(:1318 autograd in `inference_mode(False)`), `MDReferenceRestraintPotential`(`from_path`, Kabsch align + atom_pairs + pos_restraints), 호출 `apply_interface_gd`(interface_steering_utils.py:592) GD 루프 `guidance_update -= lr*grad`(diffusionv2_extend.py:440-446), `#12` flag-gating 선례(:633-662). SMC 재샘플러 `log_G`(diffusionv2_extend.py:540-542,565).
- **9UUM 활성 기계(rebuild 완료, e0f6396)**: `analysis/crl_integrative/refs/9UUM.cif`(3.41Å, neddylated CRL4-DDB1-CRBN-UbcH5a~Ub, 공개 2026-06-10). cone apex=Ub Gly76 C `(143.540,80.855,132.198)`, 축→Cys85 SG `(143.483,84.269,131.784)`. CRBN superpose 1.3Å(`crl_rebuild.py` PyMOL `super`).
- **frozen 기하**(`reach_envelope.md`): near-attack ≤3.5Å(PMC4086935), Bürgi-Dunitz [112,128]°, 라이신 rotamer reach 6.5Å, receptor-box 7.0Å → reach precondition 13.5Å.
- **VAV1 SH3 라이신** K788/804/810/814/815 = **chain-B 로컬 1-61에서 {1,7,23,29,33,34}**(AF 788+ 그대로 쓰면 인덱스가 조용히 빈다).
- **tri-Trp clamp**: W380/W386/W400(cage 강성 0.7–1.3Å; W386 0.74Å 최강).
- ★**알려진 binding 접촉(문헌 실측, bioRxiv 2025.06.08.658535 "Beyond the G-Loop", mutagenesis 검증)**:
  VAV1 **SH3c RT-loop degron, RDxS 796–799** ↔ CRBN. H결합 네트워크 = **VAV1 {R796, D797, S799} ↔ CRBN {W400, H357, N351}**
  (chain-B-로컬 796–799→15–18). 이게 **P3'의 비순환 앵커**(우리 docking 아님). Design 1은 이 접촉을 binding-side flat-bottom으로
  합법 주입, Design 2 P3'=이 접촉쌍. ★보고된 삼원은 **computational model(YDS-GlueFold), crystal 아님** → 신뢰 단위는
  *mutagenesis 검증된 접촉쌍*(3D 포즈 아님).
- ★**우리 repo 정정(이번에 발견)**: 기존 모델링은 VAV1 *라이신* K788/804/810/814/815를 interface/CV 앵커로 썼으나, 문헌상
  **결합 degron = RT-loop 796–799(P3'), 라이신 = 유비퀴틴화 표적(P4)** = *다른 구조요소*. 결합면을 라이신으로 앵커한 건 오류 →
  P3'는 RT-loop로, P4(cone 도달 라이신)는 emergent로 분리한다.
- ★주의: binding 접촉(=문헌 데이터)은 합법 주입, **catalytic register(어느 라이신·near-attack 폐쇄·productive 3D 포즈)는 절대 주입 안 함**(emergent = anti-circularity).
- **판별기(frozen, 생성기-독립)** `crl_confirm.py`/`crl_confirm_glue.py` 4축: near-attack ≤3.5Å · clash<50(severe<1.5Å) · register(min-over-5 라이신) · 삼원유지(DOF span>0.5Å). **이게 채점 기준**(crystal 불요).
- **baseline 음성=헤드룸**: static graft 스크린·MD 8098 모두 productive≈0 / 자세 generic → 개선 여지 있음.

## Assumptions And Questions

- assumptions:
  - 페어드(같은 seed·config, 차이는 closure on/off뿐)가 교란 제거.
  - E2~Ub cone은 CRBN에 (근사) rigid — neddylation 후 arm 회전폭은 미확보(아래 risk).
  - 실제 active degrader엔 productive ternary가 존재하므로 회복 대상이 있다.
- resolved/frozen (2026-06-23, 사용자):
  - **cone = distance-only v1** → Bürgi-Dunitz 각 항은 distance-only가 Stage 2 통과 후에만 추가.
  - **P3' = VAV1 {R796,D797,S799} ↔ CRBN {W400,H357,N351}**(문헌 mutagenesis 검증, bioRxiv 2025.06.08.658535) — RT-loop degron, PROTAC warhead 아님. 강한 비순환 핀.
  - ★**prior art 인지**: YDS-GlueFold(bioRxiv 2024.12.23.630090, "AF3-type 능가" 주장)가 *이미* 이 VAV1 삼원을 모델링했다. 우리 접근의 신규성 = assembly-closure(E2~Ub cone over-determination); YDS-GlueFold/AF3는 비교 베이스라인으로 둔다(우리가 최초 아님 — 명시).
  - **Stage 2 임계**: 선결로 OFF productive-fraction 측정 → PASS = ON near-attack ≥30% AND ≥5×OFF AND clash<50 AND DOF span>0.5; 에스컬레이션 트리거 = ON<2×OFF OR clash-only OR G2 snap-back.
  - **양성대조**: CK1α 9OTY(best-of-64 0.759)·PRDM1 9Q33(둘 다 *glue 유도* neo-substrate 결정 → glue-계면 검증); wall-test 붕괴 = Nek7 9H59(0.016)·PDE6D 9DWW(0.008)·9Q03(0.027).
  - **테스트 집합**: MRT6160/VAV1 리드 1개(STRUCTURE-only; 활성기 'degrader 패널 subset' 드롭).
- tradeoffs:
  - Design 1(reward)은 싸지만 증폭기(벽). Design 2(IK proposal)는 벽-면역이나 비싸나, P3'가 강해(잔기-잔기 known) manifold 잘 고정됨.

## Constraints

- allowed change scope:
  - 신규 `src/boltz_extension/steering/crl_closure_potential.py`(Design 1) + `crl_closure_ik.py`(Design 2).
  - `interface_steering_utils.py` config 필드 + build/cache 블록 + norm-matched blend(glueprint 뒤, blind scaling 앞).
  - `diffusionv2_extend.py`: Design 2만 proposal hook(~:406 이후) + `log_G` swap(:565). Design 1은 로직 변경 0.
  - `analysis/crl_integrative/`: spec 생성기 2개 + 채점/검증 스크립트.
- forbidden change scope:
  - 활성/순위 endpoint 일절 금지(STRUCTURE-only).
  - K810/라이신 identity·VAV1 orientation·촉매 register **주입 금지**(엔진이 발견해야 함 = anti-circularity).
  - `crl_confirm.py` 판별기 4축·frozen 기하 상수 변경 금지(생성기-독립 유지).
  - aigen-fold-core 미커밋 #12 WIP에 git checkout/reset 금지; 신규 potential은 별도 파일·flag-gated.
- external constraints:
  - GPU는 un-containerize(boltz_native) + kim batch/ubuntu high; free-GPU selector.
  - Stage 게이트 전까지 GPU 제출 금지(diagnose-before-scale).

## Non-Goals

- 활성/DC50/순위 예측 — 명시적 out of scope(엮지 않는다).
- 전장 VAV1 모델링(SH3 도메인 placement만).
- pathway/kinetic 도달성(productive 기하의 *존재·자세*만; "실제 경로로 닿는가"는 범위 밖).
- 보정된 SMC marginal 확률 주장(Design 2는 structure-only; Jacobian 추적 안 함).

## Done When

- **Stage 0 (zero-compute)**: 3 smoke PASS — (a) crl_grad가 norm-match blend서 W400 range grad에 안 묻힘, (b) Kabsch가 9UUM cone을 알려진 t0/seed42 프레임에 올바르게 안착, (c) chain-B-로컬 라이신이 'NZ'로 디코드(CA fallback 아님).
- **Stage 1**: 1-step end-to-end 무오류(inference_mode/autograd) + 앙상블서 glue glutarimide→cage RMSD<1.0Å(tri-Trp clamp 유지).
- **Stage 2 (분기점)**: MRT6160/VAV1 paired OFF/ON(≥8 seed), `crl_confirm.py` 채점 → PASS(ON near-attack ≫ OFF + clash<50 + DOF span>0.5) → Design 1 충분; FAIL/ON<2×OFF/clash-only/G2 snap-back → 벽 → Stage 3.
- **Stage 3 (조건부)**: CRLClosureIK가 양성대조(9OTY/9Q33)서 cone 복원(best-of-3 DockQ≥0.23 + near-attack 2/3 seed) + 붕괴타깃서 ARM2−ARM1 ≥0.13(벽-면역 입증) → 그 후 VAV1.
- **Stage 4 (조건부)**: hybrid(IK support + soft/prior internals) + G1(emergent near-attack, 라이신·register 미주입; binding 접촉은 주어진 데이터라 합법 주입) + G2(constraint-off relax snap-back<1.0Å, 2/3 multi-seed) + scrambled-contacts 민감도 유의.
- **종합 성공 (crystal 재현 목표, 비순환 정량)**:
  1. ★**접촉 재현(crystal proxy GT)**: 예측 삼원이 mutagenesis 검증 H결합 **{R796,D797,S799}↔{W400,H357,N351}** 를 재현(3쌍 중 ≥2 within 거리 컷). RT-loop degron이 CRBN 인지 패치에 안착.
  2. ★**catalytic-competence(우리 value-add)**: VAV1 라이신이 E2~Ub cone ≤3.5Å 도달(P4 emergent — 어느 라이신인지 주입 안 함). YDS/AF3가 안 쓴 제약.
  3. **교차검증/보강**: 예측 포즈를 YDS-GlueFold published model + AF3 baseline과 비교(RMSD/DockQ-to-model). 독립 수렴 = 신뢰↑; 우리 포즈가 접촉 재현 ≥ 그들 AND cone-compat 추가면 *보강* 성공. (불일치 = uncertainty 추정.)
  4. **held-out 보정**: 같은 파이프라인이 결정 있는 glue 삼원(9OTY/9Q33) 재현(DockQ 바) → VAV1 신뢰 전이.
  5. **self-consistency**: G1(emergent register) + G2(constraint-off relax snap-back<1.0Å, 2/3 seed).
  - **deliverable**: 진짜 crystal의 최선 추정 구조(또는 φ-family + relax-선택 member) + 접촉재현·cone-compat·교차검증 리포트 + calibrated confidence.

## Implementation Steps

1. **Stage 0 — 공유 closure 코어 + zero-compute smoke** (verify: 3 smoke PASS; ★문헌 접촉(VAV1 796–799·CRBN W400/H357/N351)+라이신을 *서열정렬*로 우리 프레임 매핑 + 잔기-정체 assert, 'NZ' assert)
2. **Stage 1 — Design 1 CRLClosurePotential**(MDRef autograd 1:1, `_build()` in inference_mode(False)) + config/blend wiring (verify: 1-step 무오류 + cage RMSD<1.0Å)
3. **Stage 2 — paired ON/OFF** (선결: P1 clamp 유지 + P2 OFF가 glue-CRBN 접촉맵 일치) → 채점·분기 기록 (verify: `crl_confirm.py` 4축, PASS or 벽)
4. **Stage 3 — Design 2 CRLClosureIK**(analytic 2-point + CCD fallback + proposal hook + log_G swap), 양성대조 먼저 (verify: 9OTY/9Q33 cone 복원 + wall-test)
5. **Stage 4 — hybrid + φ 해소 + G1/G2 + scrambled-contacts** → 예측 포즈 deliver (verify: G2 2/3 + honesty re-run 통과)
6. **docs/handoff** — 결과 doc + baton (verify: `.agent/status/vav1-ubq.md` 갱신)

## Change Discipline

- simplest adequate approach: Design 1(기존 #12/glueprint 배관 재사용, 신규 1파일+소edit)부터; Design 2는 게이트 실패 시에만. closure 수학 100% 공유 → 에스컬레이션 저렴.
- new abstractions introduced: CRLClosurePotential, CRLClosureIK(둘 다 flag-gated, default-off).
- unrelated code touched: 없음(판별기·frozen 상수 불변).
- request-to-diff trace: brainstorm wf_df965304(이론) + wf_164275dd(구체화) → 이 컨트랙트.

## Verification

- `analysis/crl_integrative/crl_confirm.py --traj --fes` (frozen 4축, 생성기-독립)
- Stage 0 smoke 스크립트(grad-norm·Kabsch·atom-resolution)
- 양성대조 DockQ(9OTY/9Q33) + 붕괴타깃 wall-test
- task-specific: paired OFF/ON near-attack fraction + G1/G2 + scrambled-warhead 민감도
- Chrome QA: N/A (web UI 아님)

## Risks

- **증폭기 벽(Design 1, CONFIRMED)**: soft reward는 없는 basin 못 만듦. GATE = Stage2 선결 P2 + ON≥2×OFF 트리거 → 실패 시 IK 에스컬레이션(null을 "closure 무용"으로 오독 금지).
- **tri-Trp clamp 미끄러짐(둘 다, fail-by-construction)**: glue 떨어지면 하류 전부 무의미. GATE = cage RMSD<1.0Å.
- **NZ vs CA(둘 다, silent ~2.4Å)**: 이름 못 풀면 CA fallback. GATE = 'NZ' hard-assert.
- **★잔기 번호 매핑(둘 다, silent mis-pin — 사용자 지적 2026-06-23)**: 모든 외부/문헌 번호(VAV1 RT-loop 796–799·라이신 788…; CRBN W400/H357/N351)를 **우리 예측 프레임으로 *서열정렬* 매핑 + *잔기 정체* assert**(번호 아님: R→R,D→D,S→S,W→W,H→H,N→N). 위험: (i) VAV1 chain-B=로컬 1-61(796–799→15–18, 라이신→{1,7,23,29,33,34}), (ii) **CRBN construct/isoform 번호가 9UUM/생성프레임과 다를 수 있음**(paper W400=우리 W400면 표준 정렬 *긍정 신호*나 가정 금지; H357/N351 정렬 확인). GATE = Stage 0 정렬+정체 assert + non-empty, 불일치 hard-fail.
- **inference_mode autograd 함정(둘 다)**: `_build()`가 inference_mode(False) 밖이면 backward 텐서 저장 불가(job 7962가 잡음). GATE = 1-step end-to-end.
- **cone이 CRBN에 rigid 아닐 수 있음(open)**: arm 회전폭 미확보. GATE = distance-only v1 먼저; 실패 시 cone-family(RING-Zn pivot arc softmin).
- **P3' 접촉쌍 정확도(Design 2)**: 잔기-잔기 known이라 핀은 강하나, 접촉이 부정확하면 manifold 위치가 틀어짐. GATE = scrambled-contacts 민감도(올바른 접촉쌍 vs 뒤섞은 것의 margin이 유의해야; 안 그러면 cone이 과구동=답 누수).
- **양성대조 transfer**: 9OTY/9Q33는 *glue 유도* neo-substrate 결정 → glue-templated 계면을 실제 검증(natural degron 아님; 합성이 우려한 gap은 약함). 단 VAV1과 표적이 다르므로 일반화는 wall-test+scrambled-contacts로 보강.

## Rollback

- revert strategy: 신규 potential 전부 flag-gated default-off → flag 끄면 baseline 엔진 그대로(코드 revert = 신규 파일 삭제 + config 필드 제거).
- containment strategy: 별도 파일·별도 checkpoint, aigen-fold-core #12 WIP 미접촉. GPU 출력은 /mnt 워크스페이스 격리. 판별기·frozen 상수 불변이라 기존 결과 오염 없음.

## Progress Log

- 2026-06-23: initial draft. 이론(wf_df965304: 40 idea→2 survivor→synthesis) + 구체화(wf_164275dd: 코드 grounding + 두 설계 상세) 기반.
- 2026-06-23: open questions 5건 resolved. cone distance-only v1; Stage 2 임계(ON≥30%&≥5×OFF, 트리거 ON<2×OFF); 양성대조 9OTY/9Q33 + wall 9H59/9DWW/9Q03; 테스트=MRT6160/VAV1 리드.
- 2026-06-23: ★P3' 실측 grounding (사용자가 "publish된 MRT6160 논문" 지목 → 문헌 추출). bioRxiv **2025.06.08.658535** "Beyond the G-Loop"(PubMed 40661494): VAV1 RT-loop degron **796–799(RDxS)**, H결합 **{R796,D797,S799}↔{W400,H357,N351}**, mutagenesis 검증, 삼원=YDS-GlueFold *model*(crystal 아님). **repo 정정**: 결합 interface=RT-loop(P3')지 라이신(=P4) 아님. prior art: YDS-GlueFold(bioRxiv 2024.12.23.630090). 이전 "잔기 known" frozen은 데이터 미확인 가정이었음 → 실측으로 대체. status: pending, 승인 대기.
- 2026-06-23: 목표 확정(사용자) = YDS/AF3 교차검증·보강 + 아직 없는 crystal 최대 재현. Done When을 접촉재현(crystal proxy GT)+cone-compat+교차검증+held-out+G1/G2로 구체화.
- 2026-06-23: ★잔기 번호 매핑 hazard(사용자 지적) baked — 문헌 번호(VAV1·CRBN 양쪽)를 *서열정렬+정체 assert*로 우리 프레임 매핑(번호 그대로 금지), Stage 0 hard-gate. CRBN construct 번호 차이 가능성 명시.
