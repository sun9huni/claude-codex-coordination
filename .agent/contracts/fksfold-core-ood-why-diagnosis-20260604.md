---
status: done
slice: fksfold-core
topic: ood-why-diagnosis
date: 2026-06-04
owner: claude
approved_by: user (2026-06-04, "승인")
parent_contract: .agent/contracts/fksfold-core-ood-rescue-confirm-20260602.md
triggers_matched:
  - "4개 파일 이상 (분석 스크립트 + WHY_ANALYSIS.md + 구조 측정 output)"
  - "local-only 변경 (분석 전용, production 미접촉)"
---

# OOD steering-rescue: WHY 진단 (Track A, zero-GPU)

## Purpose

OOD-rescue CONFIRM(2026-06-02) 이후, steering이 일부 OOD 타깃(9DWW)에서
강하게 구제하고 다른 타깃(9NFQ, 9DUR)에서는 전혀 구제하지 못하는 이유를
기존 데이터·구조 파일만으로 진단한다. GPU 없이 falsifiable 가설 목록을
작성하고 각각을 검증 → Track B(steering 강화 pilot) 진입 여부·타깃·파라미터
방향을 결정한다.

## Current State

- OOD rescue 120-cell DockQ: `analysis/heldout_placement_20260601/ood_rescue_20260602/ood_rescue_dockq.tsv`
- 결과 요약: 9DWW 0.683 8/8 ✅ / 9OS2 0.063 2/8 ◐ / 9NFQ 0.039 0/8 ✗ / 9DUR 0.016 0/8 ✗
- CIF 파일: `examples/heldout/{9DWW,9OS2,9NFQ,9DUR}.cif` (chain 구조 확인됨)
  - 9DWW: CRBN(C,345) + adaptor?(D,783) + PDE6D target(P,134) — 3-chain
  - 9OS2: ?(A,790) + CRBN(B,371) + target(C,124) + ?(D,124) — 4-chain
  - 9NFQ: ?(A,804) + CRBN(B,368) + NEK7(C,283) — 3-chain
  - 9DUR: CRBN(B,367) + ENL(C,139) — 2-chain (PROTAC, linker 없음)
- nativeAB YAML: `examples/heldout/{9DWW,9OS2,9NFQ,9DUR}.yaml` (pocket contacts 포함)
- 이전 분석 스크립트: `reanalyze_existing.py`, `run_ood_scoring.py`

## Hypotheses (사전 등록, 검증 순서대로)

**H1 — PROTAC modality mismatch (9DUR)**
9DUR는 heterobifunctional PROTAC. 현재 steering은 MGD single-arm geometry를
가정(CRBN pocket + target pocket 동시 steering). PROTAC linker가 두 포켓을
공간적으로 분리해 동일 constraint가 구조적으로 불가능 → steering이 오히려 방해.
검증: CIF에서 CRBN-target 거리 측정 + 9DUR DockQ 패턴(nativeAB < baseline) 확인.
→ 9DUR는 이 steering paradigm 자체의 out-of-scope로 분류 예정.

**H2 — Pocket geometry: 노출도(accessibility)**
9DWW PDE6D는 표면 노출 lipid/prenyl-binding pocket(얕음). 9NFQ NEK7는 kinase
ATP-binding cleft(깊음, buried). 얕은 pocket일수록 diffusion guidance gradient가
효과적으로 complex를 당길 수 있음.
검증: nativeAB YAML의 pocket_contacts 잔기들을 CIF에서 조회 → 잔기들의 평균
solvent-accessible surface(근사: chain surface 위치) 비교.

**H3 — Target chain 복잡도 / 비표준 crystal architecture**
9OS2는 4-chain (extra chain A=790aa). 이 chain이 GT crystal에 존재하지만
generation input에는 없을 경우, scoring이 맞지 않거나 contact geometry가 다름.
검증: 9OS2 YAML과 CIF chain 대응 확인; 누락 chain이 있으면 partial rescue의
설명이 됨.

**H4 — CRBN anchor re-derivation 품질**
per-target anchor 재유도(`verify_heldout_anchor.py` 결과)에서 타깃별 anchor
DockQ(CRBN-side)가 다를 수 있음. anchor가 약한 타깃에선 steering signal이 노이즈.
검증: `verify_heldout_anchor.py` 출력 재확인 + 생성 시 anchor residue iRMSD 비교.

## Scope

- **allowed**: 기존 TSV·CIF·YAML·스크립트 분석; 신규 분석 스크립트(`.agent/scratch/` 또는 `analysis/` 아래); `WHY_ANALYSIS.md` 작성.
- **forbidden**: steering 코드 변경; production config 변경; SLURM 제출; 새 generation 없음.
- **out of scope**: Track B(강화 pilot) — 이 contract 완료 후 별도 contract.

## Success Criteria

1. **H1~H4 각각에 대한 falsifiable 판정**: `CONFIRMED / REFUTED / INCONCLUSIVE` + 근거 수치.
2. **9DUR 분류 결론**: PROTAC modality mismatch 확인 시 "현재 steering paradigm 적용 불가" 명시.
3. **Track B go/no-go 권고**: 어떤 타깃에 어떤 파라미터 방향을 시도할 가치가 있는지 한 문장.
4. 검증: `grep -qiE 'CONFIRMED|REFUTED|INCONCLUSIVE' analysis/.../WHY_ANALYSIS.md`

## Resource Budget

- zero-GPU. 순수 Python/bash 분석. 수십 분 내 완료 예상.

## Rollback

- production/steering 미접촉. 분석 스크립트·report만 git-track. 필요 시 revert.

## Done When

- `WHY_ANALYSIS.md`: H1~H4 판정표 + 타깃별 pocket geometry 수치 + Track B 권고.
- 검증 커맨드 통과.
