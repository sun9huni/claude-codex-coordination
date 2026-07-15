---
status: done
slice: fragmap
topic: heldout-placement-validation
date: 2026-06-01
owner: claude
approved_by: user (2026-06-01, "승인" via /brain → write-plan). NOTE: Stage B SLURM 제출은 별개 2차 게이트 — submit 전 별도 "go" 필요.
triggers_matched:
  - "SLURM workflow 신규 제출 (held-out 타깃 생성, GPU)"
  - "4개 파일 이상 (held-out CIF/GT + 타깃별 input YAML + config + eval + report)"
  - "local↔shared 동시 (held-out 구조 + 생성 src/ 핀)"
program: .agent/plans/fragmap-leverage-program-20260601.md (T2 / D3)
result: "DONE = KILL (2026-06-01, FKSFold 65a487f, array 5911+5961, 36/36 DockQ). Option-1(AMENDMENT 2) 실행: single-chain target-pocket steering + 재유도 CRBN 앵커. 동결 PROVE/KILL: (i) median nativeAB DockQ≥0.23는 1/4만(9NGT 0.734; 9NYR 0.109/9NFQ 0.040/9OS2 0.036<0.23) → FAIL; (ii) nativeAB>baseline FAIL(9NYR 0.109≪baseline 0.508=steering 해로움; 9NGT 0.734≈0.726 tie) → KILL. 핵심: held-out placement = intrinsic-prior 주도(baseline가 9NGT 0.73/9NYR 0.51 medium), oracle target-pocket steering은 neutral-to-harmful; nativeAB>wrongAB는 damage signal(mis-steering 붕괴)이지 value 아님 = enclosure≠recognition을 비순환으로 확정. ★positive sub-finding: baseline(steering 0)이 2/4 held-out에서 medium DockQ = intrinsic cross-target placement 능력 존재(Charter A는 'intrinsic prior places some classic-pocket targets' 약형으로 sharpen). n=3 seed/4 target 저power→bound. 보고서 analysis/heldout_placement_20260601/STAGEB_RESULTS.md."
decisions:
  - 성격= PRE-REGISTERED, STAGED. zero-compute(CIF 다운로드+GT 추출+input YAML+사전등록)가 GPU 생성 전 선행 게이트. 점수 보기 전 PROVE/KILL 동결, 사후 변경 금지.
  - 목표= 죽은 VAV1-활성 질문을 *살아있는* placement-타당성 질문으로 교체. 모델이 안 본 held-out CRBN-ternary에서 placement 일반화를 비순환 채점 → Charter A "oracle placement generator + classic-pocket 전이" 확정/반증.
  - recon (.agent/scratch/d3_heldout_recon_20260601.md)= 9NFR가 PDB 유일 CRBN-VAV1 ternary(VAV1-특이 held-out은 external) → 본 검증은 **cross-target placement 메커니즘**을 검증(Charter A scope와 정합, VAV1 활성 아님). 다른-타깃 CRBN ternary 다운로드 가능.
  - **비순환 핵심 (동결)**: held-out에서도 oracle 모드(GT 포켓 주어짐) → **lig-target contact-F1은 순환**(steering 잔기로 채점) = 맥락용 secondary. **1차 endpoint = CRBN–target 단백질-단백질 인터페이스 DockQ** (포켓 제약이 6-DOF 배치를 결정 안 함 → 비순환 일반화 신호).
  - 패널 (동결)= held-out 3-4개: **9NYR**(CDK2/CycE1+Cpd24, 9D0W을 새 화합물로 확장), **9NGT**(mTOR), **9NFQ**(NEK7, 9NFR 동일 논문) [+ **9OS2** G3BP2 optional 4번째]. 각 타깃 ≥3-condition.
  - condition matrix (동결, Phase 9 9D0W 설계 차용)= 타깃별 **nativeAB**(GT 포켓 steering) / **wrongAB**(잘못된/전치 제약) / **baseline**(AB 없음), 각 3 seed.
  - PROVE/KILL (사전 동결):
    - PROVE = **전부**: (i) median nativeAB DockQ ≥ 0.23 (CAPRI-acceptable) on ≥3/4 타깃, AND (ii) nativeAB DockQ > baseline (oracle steering이 도움), AND (iii) **nativeAB DockQ가 wrongAB를 유의 margin 초과** (placement가 *특이적* — 단순 포켓-prior 아님; 이게 9D0W 약점 차단 게이트). → cross-target placement 일반화 확정 → Charter A 강화 + classic-pocket 제품 확장 정당.
    - KILL = median DockQ < 0.23 (incorrect) OR nativeAB ≈ baseline (steering 무의미) OR nativeAB ≈ wrongAB (신호가 타깃 포켓 prior지 CRBN-상대 placement 아님). → "placement 일반화"는 enclosed-pocket prior의 재방출이며 진짜 cross-target 배치 능력 아님 → Charter A의 전이 주장 약화/철회.
    - contact-F1은 과거 9D0W 0.826과의 연속성 맥락으로만 보고(순환 명시), 결정 인자 아님.
  - leakage/guard (동결, T0)= DockQ는 held-out GT(모델 미사용)로 채점 = 비순환. proxy-audit pre-flight 통과. power_preflight: n=3-4 타깃은 저power → 결과를 bound로(개별 타깃 + 패널 일관성). wrongAB는 crystal-memorization 차단 control.
  - 한계 (동결)= (a) oracle-only(blind 무관); (b) contact-F1 순환(secondary); (c) n=3-4 타깃 저power; (d) VAV1 활성/특이성과 무관(별개 dead lane); (e) DockQ 3.9Å cryo-EM(9NYR) 등 참조 해상도 caveat.
---

# Held-out cross-target placement validation (T2/D3)

## Purpose

T1 KILL이 보였듯 활성은 죽었고 near-native 포즈도 활성을 안 준다. 그러나 Charter A의
*살아있는* 핵심 주장은 **oracle placement generator + classic-pocket 전이**다. 이를
모델이 학습/steering에 안 쓴 **held-out PDB CRBN-ternary 구조들**에서 비순환(DockQ)으로
검증/반증한다. 이것이 제품의 durable 강점을 진짜 out-of-distribution에서 시험하는,
활성-lane을 대체하는 올바른 다음 실험이다.

> **⚠️ AMENDMENT 2 (2026-06-01) 적용됨 — 아래 §AMENDMENT 2 참조.** Purpose의
> 핵심(비순환 held-out placement 검증)은 유지되나, 9D0W 비교가능성 framing이
> 제거되고 질문이 재정의되었다. 아래 모든 9D0W-비교 관련 문구는 AMENDMENT 2가
> supersede한다.

## AMENDMENT 2 (2026-06-01) — Option-1 reframe (9D0W 비교가능성 제거, 비순환 단독 검증)

**근거.** steering-recipe 하위 contract(`fragmap-heldout-steering-recipe-20260601`,
BOUNCE, FKSFold 07cdf2a)가 본 설계의 치명 모순을 드러냄: 차용한 9D0W 'AB'는
**inter-chain CRBN↔target crystal CA-CA pair** steering이라 — 비교가능성을 위해
재현하면 DockQ가 채점하는 그 인터페이스를 직접 steering(순환)하고, 비순환을 위한
single-chain 설계는 9D0W-비교불가. 사용자 지시(2026-06-01, "세 방향 중 장기적으로
최선")에 따라 **Option 1 채택**: 비순환 DockQ 설계 유지, 9D0W 비교가능성 제거.

왜 장기 최선: (a) 활성-lane이 닫힌 지금 플랫폼의 durable 주장(Charter A = placement
일반화)을 *비순환으로* 시험하는 게 핵심 가치; (b) 버리는 9D0W baseline은 n=1·contact-F1
(순환)·pocket-prior 지배(보고서 자체 인정)라 보존 가치 낮음; (c) Option 2(inter-chain
pair + disjoint readout)는 2 pair가 6-DOF를 사실상 결정해 부분-순환 누수 위험 큰
방법론적 지뢰밭; (d) Option 3(lane 폐기)는 플랫폼 핵심 주장을 미검증 방치. → Option 1은
후퇴가 아니라 방법론적 업그레이드(순환 contact-F1 → 비순환 DockQ).

**재정의된 질문.** "ligand를 *참* target pocket에 single-chain steering + CRBN warhead
앵커가 주어졌을 때, oracle placement generator가 *안 본* held-out 타깃에서 CRBN을 target
상대로 올바르게 배치하는가 — 그리고 그 배치가 *올바른 pocket에 특이적*(nativeAB > wrongAB)
인가, 아니면 generic enclosure인가?"

**제거(supersede).** 9D0W 비교가능성(0.913/0.857/0.826 baseline) · "Phase 9 9D0W 설계
차용" 정당화 · inter-chain CRBN↔target pair steering(순환 메커니즘). 기존 decisions/
Current State/PROVE-KILL의 "9D0W 연속성 맥락"·"contact-F1 0.826 연속성" 문구는 더 이상
결정 근거 아님(맥락 보고만, 비교 baseline 아님).

**유지 (이제 9D0W 독립으로 재정당화).**
- 1차 endpoint: CRBN–target DockQ. **비순환성은 *상대적*** — single-chain target-pocket
  제약(ligand↔target)은 CRBN↔target 인터페이스를 *직접* 지정하지 않고, ligand bridge가
  6-DOF를 *느슨히 결합하나 결정하지 않음*. 완전 비순환은 아니나 inter-chain pair 대비
  훨씬 덜 순환 = 가용 옵션 중 최선. (이 한계 명시 보고.)
- 조건: nativeAB(corrected single-chain target pocket, AMENDMENT 1) / wrongAB(corrected
  opposite-face fold — 내부 일관, 9D0W transplant 아님) / baseline(no target pocket).
- PROVE/KILL(동결 임계값 유지, 재정당화): median nativeAB DockQ ≥0.23 on ≥3/4 AND
  >baseline AND >wrongAB margin. 각각 (i) held-out 배치 품질 acceptable, (ii) 올바른
  pocket 정보가 도움, (iii) 도움이 *참* pocket 특이(generic enclosure 아님)를 시험 —
  9D0W 무관하게 성립.
- CRBN 앵커: per-target 재유도(recipe Task 2, 4/4; `verify_heldout_anchor.py`).

**정직한 새 리스크.** tapestry 'enclosure ≠ recognition' + 9D0W 자체 관찰("ATP pocket
prior가 CRBN 배치와 무관하게 지배")상 **null 가능성 실재**(nativeAB ≈ baseline ≈ wrongAB
= 배치가 target 자체 pocket-prior 주도, CRBN-상대 recognition 아님). 그 null도 Charter-A를
*sharpen*하는 유익한 결과(placement 일반화 = pocket-prior re-emission). wrongAB/baseline
대비가 바로 이 둘을 가름. power_preflight: n=4 저power → bound 보고.

**다운스트림.** Stage B plan(`fragmap-heldout-placement-stageB-20260601`) UNBLOCK.
config task 명확화: per-target = 재유도 CRBN 앵커 + single-chain target steering(corrected
pocket) + VAV1-전용 glueprint `target_key_residues` 비활성. wrongAB/baseline YAML은
AMENDMENT-1 corrected positions 사용. **SLURM submit는 여전히 별도 gated(WORKFLOW §3).**

## Current State

- recon: `.agent/scratch/d3_heldout_recon_20260601.md` (held-out 후보 PDB + 검증 verdict A).
- held-out 후보(web-confirmed): 9NYR(CDK2/CycE1+Cpd24, cryo-EM 3.9Å), 9NGT(mTOR, 2.95Å), 9NFQ(NEK7, 3.25Å), 9OS2(G3BP2, 2.5Å) + ~15 더.
- 기존 약 held-out: CDK2/9D0W(nativeAB 0.913>wrongAB 0.857>baseline 0.826, n=1, contact-F1=순환·포켓-prior 지배). 본 contract가 이를 DockQ + 다중 타깃 + wrongAB-margin로 강화.
- 평가도구: MGD_eval(DockQ/LDDT/ligand-RMSD, pure-python) — T1에서 smoke 확인됨.
- 생성 harness: glueprint pilot SLURM array + FK src/ 핀(`analysis/pli_objective_pilot_20260601/PINS.md`). 9D0W input YAML 레시피 존재(`examples/9d0w/`).
- T0 가드레일: `analysis/foundation/activity_eval_gates.py` + `docs/proxy_audit_preflight.md`.

## Constraints

- allowed: held-out CIF 다운로드 + GT 추출 + 타깃별 input YAML + config + eval/report를 repo에 git-track(*.cif는 gitignore 확인 필요 → 정책대로); 생성 출력은 scratch OUT_BASE.
- forbidden: production ranking/weights 변경(진단); steering 에너지 수식 변경(설정만); threshold 사후 변경; **승인 없는 SLURM 제출**.
- external: no-GT 규칙 무관(여기선 held-out GT가 정답); DockQ 1차·contact-F1 맥락; per-target + 패널 bound.

## Non-Goals

- VAV1 활성/DC50 (dead lane), VAV1-특이 held-out (9NFR 유일 → external).
- production ranking 교체.
- blind-mode 검증(oracle-only 도구).
- contact-F1을 결정 인자로 사용(순환).

## Done When

- **Stage A (zero-compute)**: 3-4 held-out CIF 다운로드 + GT(PP-interface 잔기 + 포켓) 추출 + 타깃별 input YAML(seq+포켓 제약) + condition matrix(nativeAB/wrongAB/baseline) 사전등록. DockQ 평가 파이프라인 held-out에 smoke.
- **Stage B (GPU, 별도 submit go)**: 타깃 × 3-condition × 3-seed 생성 → MGD_eval DockQ(1차)+contact-F1(맥락).
- PROVE/KILL을 사전등록 threshold에 bound로 판정. 스크립트+config+GT+report git-track.

## Approval Gates (STOP)

- **SLURM 제출(Stage B)** = WORKFLOW §3 정지 게이트. contract 승인 후에도 정확한 resource request와 함께 별도 "go" 필요.
- Stage A(zero-compute)는 게이트 없이 진행 가능; Stage B 진입은 Stage A 완료 + 사용자 go.

## Resource Budget

- Stage A: zero-compute(다운로드+추출+YAML). Stage B: 3-4 타깃 × 3 condition × 3 seed × npart=8 ≈ 수십 GPU-hr(타깃 규모 의존). 사용자 appetite "데이터 확보까지 OK" 확인.

## Rollback

- 진단 전용 — production 미접촉. 생성 출력 scratch → 폐기. 코드/설정 git revert.

## Verification

- Stage A: held-out별 GT 추출 표 + input YAML parse + DockQ smoke on 1 held-out baseline.
- Stage B: 타깃×condition DockQ 표 + nativeAB-vs-wrongAB-vs-baseline 비교 + PROVE/KILL bound + proxy-audit 통과.

## Progress Log

- 2026-06-01: spec 초안 (brainstorm, recon verdict A 반영, DockQ 1차 + wrongAB-specificity 게이트). 승인 대기.
- 2026-06-01: 승인. write-plan → Stage A (7 task, zero-GPU) execute-plan 완료. FKSFold a90ca46(4 CIF)→45cb8a6(GT script)→c980452(4 GT)→80c2efa(4 nativeAB YAML)→ba5e3b7(DockQ de-risk: self 1.0/+5Å 0.53)→8114afc(pre-register 36-job + frozen DockQ PROVE/KILL + wrongAB transform). Plan: .agent/plans/fragmap-heldout-placement-validation-20260601.md (stage-a-done).
- **Stage B (GPU generation + DockQ verdict) = GATED**: 별도 write-plan 라운드 + SLURM submit go 필요. Stage-B-entry check: 9NGT GT pocket author-numbering(2088-2092) index 규약을 nativeAB/wrongAB 동일 footing으로 확정.
- 2026-06-01: **Stage-B-entry check ✅ RESOLVED (zero-GPU, FKSFold 3a7debd).** 9NGT 플래그가 9NGT-한정이 아니라 *체계적* 버그로 판명: Task 4가 GT JSON의 author/PDB `resi`를 pocket `contacts`에 그대로 복사했으나 Boltz contacts는 **1-based sequence position** (production W400→355 앵커로 증명: `w400_residue_index=355`, `CRBN_SEQ[354]=='W'`). nativeAB 3/4 오류 — 9NGT(author 2088-2092 = N=93 범위초과, 에러), 9NFQ(NEK7 author 20부터 → ~19 silent off), 9OS2(G3BP2 author 6부터 → ~5 silent off); 9NYR만 우연히 정확(CDK2 author 1부터). wrongAB 표도 동일 버그 상속. **수정(전부 pre-GPU, 점수 0; 동결 intent·transform·PROVE/KILL 불변):** 3 nativeAB YAML 재매핑(9NGT 67-71 / 9NFQ 16-18,33-38 / 9OS2 5,8,9,11,12,62,65), PREREGISTER.md AMENDMENT 1로 wrongAB 표 재계산(원표 supersede 보존), SOURCES.md 규약 기록. 각 재매핑 position을 chain-B 서열 resname과 교차검증(4/4 통과), wrongAB는 GT pocket과 disjoint(충돌 0). Provenance: `analysis/heldout_placement_20260601/fix_pocket_numbering.py`. → nativeAB/wrongAB가 모든 타깃에서 동일 footing. Stage B 입력 정확성 게이트 통과(나머지 Stage-B prep: wrongAB/baseline YAML 빌드 + SLURM array + 생성→GT 체인매핑은 별도 write-plan 라운드).
- 2026-06-01: **⚠️ STAGE B BLOCKED — 재spec 필요 (BOUNCE).** Stage-B steering recipe 하위 contract(fragmap-heldout-steering-recipe-20260601, FKSFold 07cdf2a)가 **BOUNCE 판정**. 발견: 본 contract가 차용한 "Phase 9 9D0W 설계"의 실제 'AB' 메커니즘 = **inter-chain CRBN↔target crystal CA-CA pair** steering(overfit_validation.md SLURM 5398, 0.913/0.857/0.826 출처에서 인용 검증)이지, Stage-B held-out YAML이 쓰는 single-chain target-pocket 제약이 아님. **치명적 충돌**: 9D0W 비교가능성 = inter-chain CRBN↔target steering = 본 contract의 1차 endpoint(CRBN–target DockQ)가 채점하는 바로 그 인터페이스 → 순환. 비순환을 위해 동결한 single-chain 설계는 9D0W-비교불가. 동결 condition matrix로는 비교가능성·비순환성 둘 다 성립 불가. → **이 contract를 /brainstorm으로 재spec 필요** (옵션 ①비교가능성 포기·비순환 유지[질문 재정의] ②9D0W 메커니즘·비순환 endpoint 신설 ③lane 폐기→D2). 부산물(durable, 어느 옵션이든 재사용): CRBN 앵커 4/4 재유도(verify_heldout_anchor.py; production idx 355 무효 확인). Stage B plan(fragmap-heldout-placement-stageB-20260601)은 재spec 전 BLOCKED.
- 2026-06-01: **재spec 완료 = AMENDMENT 2 (Option 1, 사용자 "장기적으로 최선" 위임).** 비순환 DockQ 설계 유지 + 9D0W 비교가능성 제거 → 질문 재정의("single-chain target-pocket + CRBN 앵커로 held-out CRBN-target placement가 올바르고 pocket-특이적인가"). PROVE/KILL 임계값 동결 유지, 9D0W 독립 재정당화. 비순환성=상대적(ligand bridge 한계 명시). null 리스크(enclosure≠recognition) 정직 기록. Stage B plan UNBLOCK; config task 명확화(재유도 CRBN 앵커 + single-chain steering + VAV1 glueprint target term 비활성). SLURM 여전히 gated. 다음=Stage B plan write-plan refresh(Task 1-2 redefine) → SLURM go.
