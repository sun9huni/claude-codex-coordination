---
status: done
slice: vav1-ubq
topic: glue-design-competence-filter
date: 2026-06-23
owner: claude
approved_by: user (2026-06-23, "승인")
verdict: "DONE — glue_competence.py necessary-condition filter built+adversarially-hardened. 5-agent workflow found 3 holes + a 4th (user-caught ROTATED-mode false-pass) → ALL fixed: functional-atom degron (kills whole-residue false-pass), identity-fraction chain-ID, override guard, and SH3c-RMSD guard tightened 15→8Å (an 11.8Å rotated pose passed the loose guard but visibly didn't match; genuine matches cluster ≤7Å, clean gap to 11.8). PASS now = matches the experimental binding MODE. Validation 9NFR-PASS/seed42-FAIL holds; renumber/rename/CIF invariant; no false-fail. 14-pose sweep 5/14 PASS (all near-native ≤7Å), 3 failure mechanisms (degron-miss / SH3c gross-clash / SH3c rotated). ★corrected finding: near-native competent poses come from generation but only the chirality-ensemble glues (g6_R 4.3/g5_R/g1_S); the MRT6160 named-glue generations are rotated(11.8)/off(23-25) = NOT matches. STRUCTURE-only, zero-GPU."
requested: 2026-06-23
cross_slice:
  - "aigen-fold-core (분리): 삼원 *생성/posing*(엔진·docking·conformer 예측)은 OUT — 이 도구는 *주어진 포즈를 측정*만 한다. 엔진 코드 미접촉."
triggers_matched:
  - "신규 코드 — 임의 글루 삼원 입력 → 9UUM 중첩 → competence 채점 스크립트 (analysis/crl_integrative/, 워크스페이스 repo)"
  - "shared-storage writes — /mnt에 per-glue 채점 산출(소량)"
---

# VAV1 Glue Design — Competence Filter (necessary-condition, STRUCTURE-only)

## Purpose

신규 VAV1-degrader 글루 *설계*를 돕는 **구조적 competence 필터**. 제안된 글루의 삼원
포즈를 입력받아 → 활성기계(9UUM) 프레임에 posing(CRBN 중첩) → **① 기존 reference
포즈(9NFR)와의 유사도** + **② 라이신→Ub(zone) 거리** + **제약별 PASS/FAIL·왜-실패
피드백**을 낸다.

**ranker가 아니라 *필요조건 필터*다.** potency를 못 가린다는 6개월 결과(pose≠potency,
DC50/Dmax KILL, 협동 열역학도 무상관)를 그대로 받아들임: 이 도구는 *기하적으로 무능한
글루를 죽여* hit-rate를 올리지, 승자를 고르지 않는다. competent 후보 사이 fine potency
순위는 경험적(다운스트림 합성+test).

근거(이번 세션 vav1-ubq-ubiquitination-zone-patch-20260623): 9NFR이 실험 placement,
9UUM이 productive zone(IKZF3 캘리브 ≤21Å)을 고정. 생성 포즈(seed42)는 23Å 빗나
degron 미회복 → 그런 무능 포즈를 *걸러내는* 게 이 도구.

## Current State

- 부품 존재(이번 세션, commit 2fd2f77): `zone_superpose_crbn.py`(CRBN 서열-앵커 중첩,
  auto-offset), `zone_compare_generated.py`(임의 포즈 → 9UUM 중첩 + 유사도/접촉/라이신
  — seed42에 이미 동작, offset+45 자동검출), `zone_patch_readout.py`/`zone_body_reach.py`
  (라이신→apex zone), `contact_recovery.py`(degron 접촉 GT). frozen 기하 `closure_spec.json`
  (apex 143.540/80.855/132.198, IKZF3-calibrated zone ≤21Å). refs: 9NFR
  `best_structures/9NFR_reference.cif`, 9UUM `analysis/crl_integrative/refs/9UUM.cif`.
- 즉 이 contract = 흩어진 부품을 **"임의 글루 포즈 입력 → 단일 competence 리포트"** 한
  진입점으로 패키징 + 검증.

## Assumptions And Questions

- **[가정]** 입력은 *이미 posed된* 글루 삼원(CRBN+글루+VAV1, 임의 numbering). 생성은
  업스트림(템플릿/docking/엔진) — 이 도구 밖.
- **[가정]** CRBN은 서열-앵커로 9UUM에 중첩 가능(임의 numbering은 auto-offset로 reconcile;
  zone_compare_generated가 입증).
- **[질문→확정]** 검증 = active(MRT6160)는 게이트 통과(민감도), 무능 포즈(seed42)는 FAIL.
  inactive가 같이 통과해도 OK(필요조건). active/inactive *분리* 요구 아님(=potency, killed).

## Constraints

- **zero-GPU** (중첩=SVD, 거리/SASA, KDTree clash — 전부 CPU).
- **STRUCTURE-only** — 효능/DC50/순위 주장 금지.
- frozen 기하(closure_spec.json)·refs 재사용; 재유도 금지.
- 신규 스크립트 `analysis/crl_integrative/`; aigen-fold-core 엔진/생성 코드 미접촉.
- 대용량 산출은 `/mnt`(빈 브랜치), repo엔 스크립트+요약만.

## Non-Goals

- **삼원 생성/de novo posing** — 도구는 포즈를 *받는다*, 만들지 않음.
- **글루 포켓-내 conformer 예측** — Boltz 신뢰불가; QM/docking은 업스트림.
- **potency/효능/DC50 순위** — pose≠potency (KILL). 필터지 ranker 아님.
- **active vs inactive 분리** — 그건 potency. 이 도구는 필요조건 게이트(actives must pass).
- 엔진/생성 코드 (aigen-fold-core).

## Done When

1. **단일 진입점**: 임의 글루 삼원 PDB/CIF(CRBN·글루·VAV1 사슬) 입력 → CRBN 서열-앵커
   9UUM 중첩(auto-offset, RMSD 보고) → 단일 competence 리포트 출력.
2. **유사도(①)**: SH3c CA RMSD vs 9NFR reference + degron 접촉 회복(R796↔W400,
   D797↔H357, S799↔N351 거리 + n/3 회복) 보고.
3. **라이신 거리(②)**: VAV1 표면 라이신 Nζ→Ub apex 거리 → zone(≤21Å) 내 라이신 = patch
   보고.
4. **clash + 제약별 PASS/FAIL·왜-실패**: 글루/VAV1 vs 9UUM platform clash; 각 축(접촉
   회복·zone 라이신 ≥1·clash)에 PASS/FAIL + 실패 시 어느 제약·잔기인지.
5. **검증쌍**: MRT6160(active, 9NFR-anchored 포즈) → **PASS**(degron 3/3 회복 + 라이신
   zone 내); seed42(생성, 23Å off) → **FAIL**(degron 0–1/3, R796↔W400 7.5Å) = 무능
   포즈를 정확히 걸러냄. (필요조건이라 inactive C147은 PASS/FAIL 무관, 단 피드백 sensible.)
6. **STRUCTURE-only 가드**: 리포트에 "competence(필요조건)지 potency 아님" 명시.

## Implementation Steps

(상세 분해 = /write-plan; 개요)
- 부품 통합: `zone_compare_generated.py` 일반화 → 임의 입력 파일·사슬 인자화(현재
  seed42 하드코딩) + `zone_patch_readout`의 라이신 거리 + clash를 한 함수로.
- 단일 CLI `glue_competence.py --ternary <pdb> --crbn-chain .. --vav1-chain .. --lig ..`
  → JSON+표 리포트.
- 검증쌍(MRT6160/seed42) 실행 + 기대 PASS/FAIL 어서트.
- doc + baton.

## Change Discipline

- 기존 zone_*.py는 읽기/재사용; 신규 진입점만 추가. `git add` 내 파일만, never `-A`.
- frozen 기하·매핑은 closure_spec.json/closure_map.json에서 읽기(하드코딩 인덱스 금지).

## Verification

- `python glue_competence.py --ternary <9nfr-anchored MRT6160>` → degron 3/3, 라이신
  zone 내, 종합 PASS.
- `python glue_competence.py --ternary completed_seed42.pdb ...` → degron 0–1/3,
  R796↔W400≈7.5Å, 종합 FAIL.
- 두 어서트 통과 = 도구가 competent/incompetent를 정확히 가름.

## Risks

- **R1 필터가 inactive도 통과**(필요≠충분): *설계상 의도* — 문서에 명시, ranker 아님.
- **R2 입력 포즈 품질**: garbage 포즈 입력 → 도구가 충실히 FAIL 표시(그게 목적). 단
  numbering 다양성은 서열-앵커 auto-offset로 흡수.
- **R3 zone 임계(21Å) 민감도**: 다임계(17/21) 동시 보고로 노출.
- **R4 over-claim**: STRUCTURE-only 가드(Done#6).

## Rollback

- 신규 파일만 → 스크립트 삭제 + /mnt 산출 정리로 무해 롤백. 엔진/공유상태 미변경.

## Progress Log

- 2026-06-23: contract 작성(pending). /brainstorm Q1(성공기준=유사도+라이신거리),
  Q2(scope=측정만 IN, 생성 OUT) 확정. 부품은 zone-patch 세션(2fd2f77)서 존재 →
  단일 진입점 패키징+검증. 승인 대기.
