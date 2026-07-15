---
status: done
slice: fragmap
topic: unsteered-recovery
date: 2026-05-27
owner: claude
approved_by: user (2026-05-27, "진행")
decisions:
  - 목적: AB가 9NFR 포즈를 "강제 재현"하는지(순환) vs "진짜 포즈를 찾는지"(비순환)를 판정하는 진짜 overfit 테스트. DC50(potency)이 아니라 pose correctness 기반.
  - 핵심 설계: 9NFR ligand-facing VAV1 contact 전체를 STEERED(AB가 직접 미는 14-19 ∪ 32-41) vs UN-STEERED(그 밖)로 분할, 두 그룹의 recovery(recall) 비교.
  - 판정: un-steered recovery ≈ steered recovery → 비순환 (모델이 제약 안 한 contact도 독립 recover). un-steered ≪ steered → 순환 (제약한 residue만 맞춤).
  - Input: 기존 125 AB-139 PDB + 9NFR reference crystal. zero-compute.
  - Numbering: gen VAV1 resid + 781 = ref VAV1 resid (eval_vav1_iface_sweep 규약). steered set = gen {14-19, 32-41}.
---

# Un-steered contact recovery — the real 9NFR overfit test

## Purpose

DC50 scan(Step 6)은 "generation geometry가 potency를 랭킹하나"를 답했고(아니오 — 생성 모델엔 당연), 과편향/순환성 질문은 못 닫았다. 사용자 지적: generation은 구조만 만들 뿐이라 DC50-null은 정상. 과편향을 제대로 보려면 **pose correctness**를 봐야 한다.

핵심 순환성: 채점하는 GT_5A={15,16,18,19,39}가 거의 다 AB가 steer하는 pocket(14-19, 32-41) 안에 있다 → "여기로 밀고 여기서 채점". F1=0.909는 상당 부분 보장됨. 본 분석은 9NFR contact를 steered/un-steered로 분할해, **모델이 제약 안 한 contact까지 recover하는지**로 순환 여부를 직접 판정한다.

## Current State

- AB-139 PDB 125개: `outputs/vav1_ab_139batch_20260526_231435/`
- 9NFR reference: `/home/ubuntu/best_structures/9NFR_reference.cif` (B=CRBN, C=VAV1, ligand chain 별도)
- 기존 eval은 curated GT_5A={15,16,18,19,39} (gen numbering)만 사용 — full contact set 미추출
- AB steered VAV1 residue (gen numbering): pocket 14-19 ∪ 32-41 (+contact 16, 35 — 이미 범위 내)
- 순환성 probe(2026-05-27): true-GT 0.91 vs shuffled 0.00 (trivial 순환 배제했으나 steered/un-steered 분할은 안 함)
- circularity 분석 기반: `analysis/fragmap_spectral_discriminator/reports/vav1_placement_decompose_20260527.md`

## Assumptions And Questions

- assumptions:
  - 9NFR ref에서 ligand chain 식별 가능 (B/C 아닌 chain). decompose.py의 ligand 탐지 버그는 본 분석용으로 재작성 필요
  - ref VAV1 = gen VAV1 + 781 매핑이 full contact set에도 성립
  - 9NFR full ligand-facing VAV1 contact set에 un-steered residue가 충분히 존재 (14-19, 32-41 밖에 ligand contact 있는지 — 없으면 분석 불가, 그 자체가 "GT가 전부 steered 안에 있다=구조적으로 순환 불가피" 결론)
- open questions:
  - un-steered GT contact 개수가 몇 개인가? (적으면 통계력 약함 — 보고 필수)
  - steered vs un-steered recovery 격차가 compound마다 다른가 (분포)
- tradeoffs:
  - 단일 crystal(9NFR) 기반이라 "9NFR 포즈가 맞다"는 전제는 여전 — 단 un-steered recovery는 그 전제 하에서 비순환 신호로 유효 (held-out crystal은 별도 scope)

## Constraints

- allowed change scope:
  - 새 분석 script: `analysis/fragmap_spectral_discriminator/src/unsteered_contact_recovery.py`
  - 새 report: `analysis/fragmap_spectral_discriminator/reports/unsteered_recovery_20260527.md`
  - 새 CSV: `analysis/fragmap_spectral_discriminator/reports/unsteered_recovery.csv`
- forbidden change scope:
  - 새 SLURM / generation 재실행
  - `src/boltz_extension/*` 미접촉
  - DC50 report/status framing 정정 (별도 편집)
  - held-out crystal / confidence calibration (별도 probe)
  - 새 AB variant / constraint
- external constraints:
  - zero-compute, local CPU (gemmi, numpy), ~10 min
  - 9NFR ref + 기존 125 PDB만 (read-only)

## Non-Goals

- DC50 report/status "overfit-negative" framing 정정 (별도 간단 편집)
- Held-out crystal pose 정확도 (새 target, 별도 SLURM)
- Confidence calibration (iptm/pae vs 정확도, 별도 probe)
- Generation 재실행 / 새 constraint
- Stage 2 go/no-go 결정

## Done When

1. **9NFR full contact set 추출**: ref VAV1 residues within 5Å (보조 4Å) of ligand heavy atoms → gen numbering 변환. 총 개수 보고.
2. **STEERED/UN-STEERED 분할**: steered = gen {14-19, 32-41}. un-steered = 나머지 GT contact. 각 그룹 크기 보고. (un-steered가 0이면 "구조적으로 순환 불가피" 결론 + 분석 종료)
3. **셀당 recovery**: 125 PDB 각각에서 steered-GT recall, un-steered-GT recall 계산.
4. **그룹 비교**: cohort 전체 steered recall mean/median vs un-steered recall mean/median. 차이 + 분포.
5. **판정 (사전 규칙)**:
   - un-steered recall ≈ steered recall (격차 작음, 예: <0.15) → **비순환 증거**: 모델이 제약 안 한 contact도 독립 recover
   - un-steered recall ≪ steered recall (격차 큼) → **순환 시사**: 제약한 residue만 맞춤, F1은 강제된 값
   - un-steered set 너무 작음(<3 residue) → 통계력 부족, inconclusive
6. **Report + CSV**, 판정 + caveat (단일 crystal 전제, un-steered 개수) 명시.
7. `.agent/status/fragmap.md` §Open 갱신.

## Implementation Steps

1. **9NFR ligand chain 식별 + full VAV1 contact 추출**
   - ref CIF에서 ligand chain (B/C 아닌 것) 정확 식별 — decompose.py 버그(빈 set) 재작성
   - VAV1(C) residues within 5Å/4Å of ligand → ref numbering → gen(−781)
   verify: contact set 크기 > 0, GT_5A({15,16,18,19,39})가 5Å set의 부분집합인지 sanity
2. **steered/un-steered 분할**
   - steered = {14..19, 32..41} (gen). un-steered = full − steered
   verify: 두 그룹 크기 출력, un-steered ≥ 3 확인 (아니면 inconclusive 플래그)
3. **125 PDB recovery 계산**
   - 각 PDB: gen VAV1 contact(5Å) ∩ steered-GT / |steered-GT|, ∩ un-steered-GT / |un-steered-GT|
   verify: CSV 125 rows, recall ∈ [0,1]
4. **그룹 비교 + 판정**
   - steered vs un-steered recall 분포, 격차, Wilcoxon (보조)
   verify: report에 mean/median 양 그룹 + 판정 + caveat
5. **Status 갱신**
   verify: handoff clean

## Change Discipline

- simplest adequate approach: 단일 분석 스크립트, 기존 PDB read-only
- new abstractions: 없음 (gemmi/numpy 재사용)
- unrelated code touched: 없음
- request-to-diff trace: 사용자 "DC50-null은 정상 아니냐 + 다른 신호 탐색" → DC50 framing 정정 + un-steered recovery가 진짜 overfit 테스트 → 본 contract

## Verification

- `python unsteered_contact_recovery.py` exit 0
- 9NFR contact set 크기 > 0, steered/un-steered 분할 크기 출력
- CSV 125 rows, recall 컬럼 ∈ [0,1]
- report에 steered vs un-steered recall + 판정(비순환/순환/inconclusive) + caveat 명시

## Risks

- un-steered GT contact가 거의 없을 위험: GT가 전부 steered pocket 안이면 분할 불가 → 그 경우 "9NFR contact가 구조적으로 steered 영역에 집중 = 순환 회피 불가, F1 지표의 한계" 라는 결론 자체가 정보 (inconclusive 아님)
- 단일 crystal 전제: 9NFR 포즈가 정답이라는 가정 잔존. un-steered recovery는 그 가정 하 비순환 신호 — held-out crystal이 더 강하나 별도 scope
- ligand chain 식별: 9NFR ref의 chain 구조 확인 필요 (decompose.py에서 실패한 부분) → Step 1에서 정확 식별 우선

## Rollback

- revert: script + report + CSV 삭제. 기존 데이터 무변경 (read-only)
- containment: 새 file 별도 path

## Triggers Matched (WORKFLOW.md §2)

- ❌ SLURM submission (zero-compute)
- ❌ ranking semantics 변경 (진단, 결정 안 함)
- ✅ shared storage write (analysis/)
- 4+ files: 아님 (script + CSV + report + status = ~3-4)
- ❌ FragMap scoring mode 변경

## Progress Log

- 2026-05-27: contract drafted via /brainstorm (status: pending)
  - 동기: DC50 scan이 overfit 질문 못 닫음 (생성은 affinity predictor 아님 — 사용자 지적). 진짜 테스트 = pose correctness via un-steered contact recovery
  - Q1 success: steered vs un-steered recovery 비교
  - Q2 out of scope: DC50 framing 정정(별도), held-out crystal, confidence calibration, generation 재실행 — 전부 분리
  - 핵심: 채점 GT가 steered pocket과 겹치는 순환을 분할로 직접 테스트
- 2026-05-27: EXECUTED (zero-compute). PRIMARY: 9NFR VAV1-ligand contacts (5Å {15,16,18,19,39}, 4Å {15,16,19}) ALL inside steered pocket → 0 un-steered ligand contacts → ligand contact-F1 STRUCTURALLY CIRCULAR (no non-circular pose-correctness evidence). SECONDARY: PPI un-steered residues {13,49,50,51} placement recall 0.908 vs steered 0.695 (gap −0.213) → VAV1 rigid-body placement leans NON-circular (n=4 low power, rigid-body partial-circularity caveat). Verdict: AB places VAV1 body reliably; contact-F1 headline is circular — ligand pose correctness needs held-out crystal/orthogonal data. Report: unsteered_recovery_20260527.md. status: done.
