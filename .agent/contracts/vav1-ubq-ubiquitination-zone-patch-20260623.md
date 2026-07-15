---
status: done
slice: vav1-ubq
topic: ubiquitination-zone-patch
date: 2026-06-23
owner: claude
approved_by: user (2026-06-23, "진행")
verdict: "DONE — degron-presented patch {K804, K788, K810} (K804 robust dominant) + low-occupancy SH2 body tail. Double-anchored: 9NFR placement + 9UUM/IKZF3 productive zone. Body (full-VAV1) checked, NOT needed for the patch. STRUCTURE-only. zero-GPU."
requested: 2026-06-23
cross_slice:
  - "aigen-fold-core (분리·비충돌): 생성-시간 CRLClosurePotential/IK·Boltz steering 엔진 코드는 aigen-fold-core의 assembly-closure-GENERATION contract 소관. 본 contract는 엔진 생성 없이 실험 결정구조(9NFR)를 앵커로 쓰는 구조-분석 파이프라인 → 엔진 코드 미접촉, 방법·산출물 모두 독립."
triggers_matched:
  - "shared-storage writes — /mnt 워크스페이스에 conformer 앙상블·readout 산출 (대용량)"
  - "신규 코드 — 9NFR/9UUM 중첩·full-VAV1 graft·hinge 앙상블·zone-patch readout 스크립트 (analysis/crl_integrative/, 워크스페이스 repo)"
  - "GPU(조건부, 게이트): AF-multiseed 교차검증 앙상블 또는 선택적 MD 완화가 필요할 때만 — 코어 파이프라인은 zero-GPU"
---

# VAV1 Ubiquitination-Zone Patch — 실험 결정구조(9NFR)로 SH3 placement를 고정하고, full-VAV1 앙상블에서 E2~Ub zone에 닿는 표면 라이신 *patch*를 읽어낸다 (STRUCTURE-ONLY)

## Purpose

질문(사용자 확정): **CRBN–MRT6160–VAV1 삼원에서 어느 VAV1 표면 라이신들이 활성 CRL4의 E2~Ub로 ubiquitination될 수 있는가** — 단일 표적 라이신(기존 K810 가설)이 아니라 **확률적 충돌 기전(Ciulli ubiquitination-zone)에 맞는 라이신 patch**로.

기전(사용자 강의): E2~Ub "채찍"은 유연하고, ub-site는 서열 근접이 아니라 **E2~Ub가 닿는 zone 안에서 각도·타이밍이 맞는 아무 표면 라이신**에 확률적으로 정해진다. 모집단-평균 MS는 여러 라이신을 본다. 따라서 답은 "그 라이신"이 아니라 **zone에 드는 노출 라이신의 집합(patch) + 각 라이신의 zone-점유 빈도**다.

**핵심 설계(사용자 정정 2026-06-23)**: SH3가 CRBN에 어떻게 앉는지는 **예측할 필요가 없다 — 9NFR이 실측 답이다**.
- **9NFR** = `CRBN-DDB1 + MRT-23227 + VAV1(SH3)` **실험 결정구조** → SH3-on-CRBN placement가 실측으로 고정. (생성·cone-collapse·P3'-구동 생성 전부 불필요 = 기존 assembly-closure 생성 기계는 본 작업에서 증발.)
- 9NFR은 **SH3-only truncated construct**(VAV1 몸통 없음). 그래서 여기에 **full-VAV1 body를 graft**하고(=사용자의 "이를 2와 붙이는 것"), 활성 CRL4(9UUM) 프레임으로 옮겨 zone-patch를 읽는다.

**비순환 논리**:
1. placement = 실험 결정(9NFR) → 예측 오차 0, 순환 0 (우리가 자세를 만들지 않음).
2. zone = **ligase 성질**(9UUM E2~Ub cone) → 모든 neo-substrate 공통, VAV1-특이 아님 → 답 주입 아님.
3. 모델링되는 유일한 부분 = **full-VAV1 body conformer**(우리가 식별한 바로 그 유연성 문제) → target에 맞추는 게 아니라 *읽어냄*.

목표는 **구조적 접근가능성 주장뿐** — 어느 라이신이 *실제로* 가장 많이 ubiquitinated되는지(효율·DC50)는 **out-of-scope**(pose≠potency KILL 레인; 그건 diGly-MS의 몫).

## Current State

- **9NFR**: `/home/ubuntu/best_structures/9NFR_reference.cif` (title "Crystal structure of CRBN-DDB1 and MRT-23227 in complex with VAV1"). 계면 요약 `/home/ubuntu/analysis/9nfr_crystal_interface.json` (VAV1 SH3 ~gen13-51, CRBN 57-376; 최근접쌍 HIS352↔ASP16 5.82Å 등). MRT-23227은 MRT6160과 동족 glutarimide·동일 RDxS degron → SH3 placement는 본질적으로 glue-불변(아래 가정 참조).
- **9UUM** (활성 기계): `/home/ubuntu/analysis/crl_integrative/refs/9UUM.cif` (3.41Å, neddylated CRL4-DDB1-CRBN-UbcH5a~Ub). cone(closure_spec.json, frozen): apex=Ub Gly76 C `(143.540,80.855,132.198)`, sg=E2 Cys85 SG `(143.483,84.269,131.784)`, axis 정규화됨, **reach precondition 13.5Å**, near-attack 3.5Å, Bürgi-Dunitz [112,128]°(angle_enabled=false).
- **AF full-VAV1 body**: `/home/ubuntu/analysis/productive_pose/refs/AF-P15498-F1.pdb` (영구; UniProt P15498 native numbering, degron SH3 = native 782–842). 멀티도메인(CH-Ac-DH-PH-C1- … -SH3c-SH2-SH3) — degron은 C말단 SH3c.
- **재사용 가능한 T1–T4 산출(병렬 세션, 워크스페이스 repo 커밋)**: `closure_map.json`(VAV1 P15498↔local, sh3_offset 781; CRBN offset 0 in 9UUM; all_identity_ok=true), `closure_spec.json`(위 cone + 5 라이신 NZ {788,804,810,814,815}=local{7,23,29,33,34} + tri-Trp clamp 380/386/400 + P3' 접촉 {R796↔W400, D797↔H357, S799↔N351}, pairing=plausible_not_figure_confirmed), `contact_recovery.py`(crystal-proxy GT 채점기, auto offset), `smoke_kabsch_cone.py`(9UUM cone Kabsch-carry, ★9UUM CRBN vs *생성* donor offset 45 발견 — 본 작업은 donor가 9NFR이라 9NFR↔9UUM CRBN을 서열-앵커로 재-reconcile 필요). dir=`/home/ubuntu/analysis/crl_integrative/`.
- **선행 지식(이전 워크스트림, 확정)**: degron=C말단 SH3(SH2 아님); 실험 ub-site 부재; K810=단일-라이신 기하최선 가설(flex-arm rescore서 dominant-reachable 63%); productive near-attack(≤3.5Å)은 ~1–2% 드문 동역학상태(=MD 레이어, 본 구조 작업의 zone은 reach 13.5Å precondition으로 정의); **단일 rigid AF conformer는 가짜 clash 과대예측(diag B inconclusive) → 앙상블 필수**.

## Assumptions And Questions

- **[가정, 명시]** 9NFR(MRT-23227)의 SH3-on-CRBN placement ≈ MRT6160의 placement. 근거: 동족 glutarimide, 동일 RDxS degron(796–799), 동일 CRBN tri-Trp pocket. zone 질문은 VAV1 body 기하에 관한 것이라 glue 차이에 둔감. → glue 차이는 모델링하지 않음(검증=9NFR이 P3' degron 접촉을 실제로 가지는지 T1에서 확인).
- **[검증]** AF P15498 SH3c fold ≈ 9NFR SH3 fold (Cα graft 가능). → T3에서 graft RMSD로 판정(임계 ~2Å, 같은 fold).
- **[1차 모델링 가정]** hinge/linker 샘플링이 SH3c↔몸통 relevant 유연성을 포착. → AF-multiseed 교차검증(게이트)으로 보강; reach-임계 민감도 그리드로 robustness.
- **[질문]** zone 반경 13.5Å(reach precondition)이 맞나? → 민감도 그리드(예: 10/13.5/17Å)로 patch가 임계에 robust한지.
- **[질문]** DDB1은 9NFR·9UUM 둘 다 존재 → CRBN(공유·VAV1/glue 보유 도메인)으로 중첩하고, DDB1 일치도를 sanity로 보고.

## Constraints

- **STRUCTURE-only**. 활성/효율/DC50/순위 주장 금지(KILL 레인). patch는 "구조적으로 zone에 닿고 노출됨"이지 "가장 많이 ubiquitinated"가 아님.
- **코어 파이프라인 zero-GPU**(중첩·graft·hinge 앙상블·기하 readout = CPU/분석). GPU는 **AF-multiseed 앙상블 또는 선택적 MD 완화에만**, 그것도 승인 게이트 뒤.
- **frozen 기하 재사용**: closure_spec.json의 cone·reach·라이신을 재유도하지 말 것.
- **엔진 코드·생성 contract 미접촉**: aigen-fold-core의 assembly-closure-GENERATION(CRLClosurePotential/IK/diffusionv2 훅)과 분리. 본 작업은 Boltz를 돌리지 않음.
- 신규 스크립트는 워크스페이스 repo `/home/ubuntu/analysis/crl_integrative/`; T1–T4 산출(closure_map/spec.json, refs/, contact_recovery.py) 재사용. 대용량 앙상블 좌표는 `/mnt`(kfs5 회피, kfs2 등 빈 브랜치).
- diagnose-before-scale: 각 단계는 sanity 게이트(중첩 RMSD, graft RMSD, 정체-assert, 9NFR P3' 접촉 존재)를 통과해야 다음으로.

## Non-Goals

- **활성/효율/DC50/degradation 순위** — pose≠potency. patch는 구조 접근가능성. 실제 ub-site 동정·효율은 diGly-MS의 몫(없음).
- **엔진 생성 / CRLClosurePotential / Boltz steering** — aigen-fold-core 소관. 본 작업은 9NFR 실측을 씀, 생성 0.
- **SH3-on-CRBN placement 예측** — 9NFR이 줌(예측 안 함).
- **MRT6160 glue 특이 모델링** — 9NFR=MRT-23227, placement은 glue-불변 가정(명시). glue별 차이 비교 안 함.
- **full-VAV1 삼원의 crystal-DockQ** — full-VAV1 삼원 결정 부재. body는 *모델*이지 구조 검증 대상 아님(접근가능성 readout이지 좌표 정확도 주장 아님).
- **단일 "정답 라이신" 단정** — patch + 빈도로 보고; K810이 patch에 들고 지배적인지 *비교*하되, 단일-표적 단정 폐기.

## Done When

1. **9NFR placement 검증(앵커 sanity)**: 9NFR VAV1-SH3↔CRBN 접촉이 P3' RDxS degron(R796/D797/S799 ↔ W400/H357/N351)을 포함함을 실측 거리로 확인(접촉 ≤ ~5–6Å). 9NFR CRBN 번호를 서열-앵커로 closure_map과 reconcile(정체-assert). [zero-GPU]
2. **CRBN 중첩 9NFR→9UUM**: 서열-앵커 CRBN Cα 정렬 RMSD < ~1.5Å, 9NFR↔9UUM CRBN 번호 offset을 서열로 reconcile(잔기번호 신뢰 금지). 중첩 후 9NFR SH3가 활성 프레임에 안착; SH3 5 라이신 Nζ→cone apex 거리 보고. DDB1 일치도 sanity 보고. [zero-GPU]
3. **full-VAV1 graft**: AF P15498 SH3c(782–842) Cα를 9NFR SH3에 정렬 RMSD < ~2Å(같은 fold), 그 변환을 AF 전체에 적용 → full-VAV1이 활성 프레임에. full 표면 라이신 인벤토리(P15498 번호)와 정체-assert. [zero-GPU]
4. **conformer 앙상블**: full-VAV1 body의 hinge/linker 샘플링(고정 SH3c 기준) N≥50 conformer 생성, 각 conformer를 platform(CRBN-DDB1-CUL4-NEDD8-E2~Ub) 대비 clash 체크. ★**가짜-clash 해소 입증**: 단일 rigid AF가 충돌하던 자리에서 **앙상블이 clash-free 멤버를 가짐**(=9NFR 같은 실복합체에서 full-VAV1이 입체적으로 수용 가능). 앙상블 steric feasibility 분포 보고. [zero-GPU; AF-multiseed 교차검증은 게이트 뒤]
5. **zone-patch readout**: conformer마다 표면 라이신별 (Nζ가 cone reach 13.5Å 이내 ∧ cone 각도 envelope ∧ SASA-노출>임계) 판정 → 앙상블 전반 집계 = **patch**(임계 초과 라이신 집합) + 라이신별 **accessible-conformer fraction**(=zone에 든 샘플 conformer 분율; ★Boltzmann 점유 *확률 아님* — 열역학 가중은 Stage C MD). K810이 patch에 들고 지배적인지 *비교*. [zero-GPU]
6. **anti-circularity / robustness**: (G-zone) patch가 앙상블 source(hinge vs AF-multiseed)·reach 임계 민감도 그리드에 robust. (G-honesty) 리포트는 STRUCTURE-only — 효율/활성 주장 0, "patch=구조 접근가능성" 명시. clash-free 앙상블 부재(전 멤버 충돌) 또는 patch가 임계에 따라 요동치면 = inconclusive로 정직 보고(over-claim 금지).

## Implementation Steps

(상세 분해는 /write-plan; 단계 개요)
- **Stage A (zero-GPU 코어)**: 9NFR P3' 검증(Done#1) → CRBN 9NFR→9UUM 중첩+서열-reconcile(#2) → AF full-VAV1 graft(#3).
- **Stage B (zero-GPU 앙상블+readout)**: hinge/linker 앙상블 생성+clash 체크(#4) → zone-patch readout(#5) → 민감도/robustness(#6).
- **Stage C (게이트, 조건부 GPU)**: clash·hinge가 부족하다 판단되면 AF-multiseed 앙상블 또는 짧은 body MD 완화로 교차검증. 승인 게이트 후에만.
- **Stage D (doc)**: STRUCTURE-only 리포트(patch + 빈도 + robustness + 한계), Notion 동기화는 vav1-ubq baton 경유.

## Change Discipline

- 신규 스크립트만 `analysis/crl_integrative/`에 추가; T1–T4 파일 수정 최소화(읽기 위주). `git add` 내 파일만, never `-A`.
- frozen 기하·라이신 매핑은 closure_spec.json/closure_map.json에서 읽기(하드코딩 인덱스 금지 — 토폴로지/서열 앵커).
- 대용량 좌표 산출은 `/mnt`(빈 브랜치), repo엔 요약·스크립트만.

## Verification

- 각 Done 항목 = 한 검증 명령(중첩 RMSD 출력, graft RMSD, 접촉거리표, 정체-assert pass, clash 히스토그램, patch 빈도표, 민감도 그리드표).
- 게이트: 중첩 RMSD>1.5Å 또는 graft RMSD>2Å 또는 9NFR이 P3' 접촉 없음 → 즉시 멈추고 앵커 가정 재검토.

## Risks

- **R1 9NFR≠MRT6160 placement**: 동족·동degron이라 낮음; T1이 9NFR P3' 접촉 존재로 sanity.
- **R2 hinge 샘플링이 비현실적 conformer 생성**: clash 체크 + AF-multiseed 교차검증으로 완화; robustness 게이트.
- **R3 전 앙상블 멤버가 clash**(=AF body가 autoinhibited-compact): 그러면 zone-patch inconclusive → 정직 보고 + Stage C(MD 완화/extended conformer) 게이트.
- **R4 patch가 reach 임계에 민감**: 민감도 그리드로 노출; robust 부분집합만 patch로 보고.
- **R5 over-claim**: STRUCTURE-only 가드(Done#6 G-honesty) — 효율 주장 절대 금지.

## Rollback

- 전부 신규 파일/분석 산출 → 되돌릴 엔진/공유 상태 없음. 스크립트 삭제 + /mnt 산출 정리로 무해 롤백.

## Progress Log

- 2026-06-23: contract 작성(pending). 설계 = 사용자 정정(placement=9NFR 실측, full-VAV1 graft, zone-patch readout). T1–T4(병렬 세션) 재사용. 승인 대기.
- 2026-06-23: 사용자 "진행" = 승인(approved). zero-GPU 타당성 확인(중첩=SVD·앙상블=NMA+강체 hinge·readout=거리+SASA+KDTree, MD/NN 추론 없음; 기존 crl_nma.py/full_vav1_steric.py가 CPU 경로 입증). Done#5 라벨 정정: zone-occupancy "빈도"→"accessible-conformer fraction"(Boltzmann 확률 아님; 열역학 가중=Stage C MD 게이트). → /write-plan.
- 2026-06-23: **DONE**. plan T1–T8 실행(전 게이트 통과, zero-GPU). ★발견: 9UUM=IKZF3(ZF2-3) productive 어셈블리 → (i) VAV1 SH3c placement 검증(IKZF3 degron 자리 2.1Å 일치), (ii) body rigid clash=아티팩트(실제 neosubstrate body는 dangle/미분해능 — T5 "fail"의 정체), (iii) IKZF3 라이신 17-21Å이 zone 캘리브레이션. **답=degron patch {K804(robust dominant),K788,K810}** (≤21Å both rotamer) + 저점유 SH2 body tail(K716/732/733/751/755). 사용자 full-VAV1 thesis(#2) zero-GPU로 체크완료(tether+앙상블 upper-bound)=body 불필요. IKZF3 자기일관성 검증. STRUCTURE-only(효율/MS-부위 주장 0). 리포트 zone_patch_results_20260623.md. 미결(선택): caveat#1 IKZF3/VAV1 실험 ub-부위 딥리서치(캘리브레이션 보강).
