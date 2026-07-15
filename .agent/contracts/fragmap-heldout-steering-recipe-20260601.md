---
status: done
slice: fragmap
topic: heldout-steering-recipe
date: 2026-06-01
owner: claude
approved_by: user (2026-06-01, "승인" via /brainstorm → 3 fork 권고안 채택)
parent_contract: .agent/contracts/fragmap-heldout-placement-validation-20260601.md
feeds: .agent/plans/fragmap-heldout-placement-stageB-20260601.md (replaces/satisfies its Tasks 1-2)
triggers_matched:
  - "4개 파일 이상 (STAGEB_RECIPE.md + 타깃별 generation config ≤4 + 검증 스크립트)"
  - "local↔shared 동시 (production config/src 정독 + held-out config 파생, gated SLURM 생성에 공급)"
  - "gated SLURM 제출(부모 Stage B)의 선행 기반 — recipe 없이는 생성 불가"
result: "DONE = BOUNCE (zero-GPU, FKSFold 07cdf2a, plan 5/5). 9D0W steering 메커니즘 복원 결과 NOT-MAPPABLE: 9D0W 'AB'는 inter-chain CRBN↔target crystal CA-CA pair([A,105]↔[B,7] 등)이고 wrongAB는 VAV1-index 직접 transplant(opposite-face fold 아님) — overfit_validation.md SLURM 5398(0.913/0.857/0.826 출처)에서 인용 검증. 핵심 충돌(STAGEB_RECIPE §3): 9D0W 비교가능성 = inter-chain CRBN↔target steering = DockQ가 채점하는 바로 그 인터페이스 → 순환; 부모의 비순환 single-chain 설계는 9D0W-비교불가. 동결 condition matrix로는 둘 다 성립 불가 → fork 3 발동 = 부모 contract /brainstorm 재spec. ★부산물(durable): CRBN 앵커 4/4 재유도(W400→356/321/331/345; production 355 무효 확인, verify_heldout_anchor.py) — 어느 재spec 옵션이든 재사용. 다음=부모 held-out contract 재spec(옵션 3개: ①비교가능성 포기·비순환 유지 ②9D0W 메커니즘·비순환 endpoint 신설 ③lane 폐기)."
decisions:
  - 성격= ZERO-COMPUTE 설계-해결 + 검증. production code/ranking/에너지수식 미접촉(config·문서만). 점수 없음(생성 전). 부모 held-out contract가 동결한 condition matrix를 *어떻게 구현*할지 확정하는 것이지 의미론을 바꾸는 게 아님.
  - 배경 (확인된 결함)= ① target-side 메커니즘 미해결: glueprint config `target_key_residues:[15,16,18,19,37,39]`는 VAV1 전용 → CDK2/mTOR/NEK7/G3BP2에서 무의미; 조건 인코딩 노브가 둘(Boltz 입력-YAML pocket 제약 vs glueprint term). ② CRBN 앵커 무효: production `anchor_patch[351,355,357]`+`w400_residue_index=355`가 4 held-out YAML 전부에서 깨짐(pos355=G/L/P/S, W 아님; 9NGT/9OS2는 gap으로 단순 offset도 W400 못 맞춤). AMENDMENT-1(author→seq-pos) 함정의 CRBN 버전, 더 심함.
  - **fork 1 (동결, 사용자 2026-06-01)= 9D0W 선례 매칭 우선.** 9D0W Phase-9 report들(`analysis/fragmap_spectral_discriminator/reports/*9d0w*`, `docs/platform_state_and_next_plan_20260529.md`)을 먼저 정독해 그 run이 nativeAB/wrongAB/baseline을 *어떤 노브로* steering했는지 복원 → 동일 메커니즘 채택(0.913/0.857/0.826과 직접 비교가능). 복원 불가일 때만 fallback.
  - **fork 2 (동결)= CRBN 앵커 재유도만.** W400·anchor_patch·CRBN pocket 위치를 각 held-out construct에서 **residue-walk(gap-aware, fix_pocket_numbering.py 패턴)**로 재유도 → 각 construct의 실제 1-based 위치. held-out YAML의 현 chain-A-pocket-free 형태 유지(CRBN-side pocket 제약 *추가 안 함*). 최소 변경, 조건 의미론 불변.
  - **fork 3 (동결)= 실패 시 부모 contract로 bounce.** 깨끗한 매핑이 없거나 9D0W 비교가능성 복원 불가면 STOP → 부모 held-out contract를 /brainstorm으로 재spec(동결 condition matrix가 held-out에서 안 살아남을 수 있음). 즉흥 설계 금지.
  - 산출물= `analysis/heldout_placement_20260601/STAGEB_RECIPE.md`(메커니즘+조건별 정확한 field/flag+CRBN 앵커 재유도 표+9D0W 비교가능성 진술 or bounce 결정) + 타깃별 generation config(≤4, `configs/oracle_generation_heldout_<ID>.yaml`) + 검증 스크립트(CRBN 앵커 4/4 pass 출력).
  - 검증 핵심= fix_pocket_numbering.py와 동형의 cross-check: 재유도한 W400 위치가 각 held-out chain-A 서열에서 실제 'W'에 떨어지고 anchor_patch가 in-range+기대 잔기인지 4/4 pass; target-side 메커니즘이 조건별 정확한 값으로 박제; 9D0W 비교가능성 명시.
  - 한계= (a) 9D0W run 원본 아티팩트는 report .md로만 남음(shared 원본은 kim-blocked 가능) → 메커니즘 복원은 문서 근거 기반; (b) 비교가능성은 메커니즘-동형까지이며 타깃 화학종은 다름; (c) 이 contract는 recipe 정확성만 확정 — placement 일반화 verdict는 부모 Stage B DockQ 소관.
---

# Held-out steering recipe (Stage-B Task 1-2의 spec'd 버전)

## Purpose

부모 held-out contract는 condition matrix(nativeAB/wrongAB/baseline)는 동결했지만
**held-out 타깃에서 그 조건을 어떻게 steering하는지**는 미정이다. 정독 결과 두 결함이
확인됐다 — target-side glueprint term이 VAV1 전용이고, CRBN 앵커 인덱스가 4개 held-out
construct 전부에서 깨졌다(production 355=W가 held-out에선 G/L/P/S). 이 contract는 zero-compute로
**9D0W-비교가능한 steering recipe를 박제·검증**해 부모 Stage B 생성이 동결된 condition
의미론과 선례에 충실하게 만든다. 깨끗한 매핑이 없으면 부모를 재spec.

## Current State

- 부모 contract: `.agent/contracts/fragmap-heldout-placement-validation-20260601.md`(approved, Stage A done + AMENDMENT 1).
- Stage B plan: `.agent/plans/fragmap-heldout-placement-stageB-20260601.md`(pending) — 본 contract가 그 Task 1-2를 대체/충족.
- 생성 하네스: `workflow/slurm_glueprint_gd_pilot_3x3_20260507.sh` + `analysis/pli_objective_pilot_20260601/PINS.md`.
- production config: `configs/vav1_pipeline/oracle_generation.yaml`(glueprint 블록: CRBN-side anchor_patch[351,355,357]/pocket[305..355] = VAV1 numbering; target_key_residues = VAV1 전용).
- 확정된 규약: Boltz pocket contacts = 1-based seq position(AMENDMENT 1, W400→355 증명). 동일 규약이 CRBN-side에도 적용됨.
- 패턴: `analysis/heldout_placement_20260601/fix_pocket_numbering.py`(residue-walk + resname cross-check).
- 9D0W 선례 흔적: `analysis/fragmap_spectral_discriminator/reports/`(unsteered_recovery / overfit / phase10_closeout 등), `docs/platform_state_and_next_plan_20260529.md`, `docs/measurement_foundation_design_20260601.md`.

## Constraints

- allowed: 9D0W report 정독 + held-out construct residue-walk 매핑 + `STAGEB_RECIPE.md` + 타깃별 generation config 파생 + 검증 스크립트를 repo에 git-track.
- forbidden: production ranking/weights 변경; GlueprintPotential 에너지 수식 변경(config 값만); **SLURM 제출**(부모 Stage B 게이트); 동결 condition matrix/PROVE-KILL 의미론 변경; held-out YAML에 CRBN-side pocket 제약 추가(fork 2 = 앵커 재유도만); threshold 사후 변경.
- external: no-GT 규칙 무관(설계 작업); 비교가능성은 메커니즘-동형 범위로 한정 보고.

## Out of scope

- Stage B 생성(SLURM) 자체 — 부모 contract의 gated milestone.
- DockQ verdict / PROVE-KILL 판정.
- wrongAB/baseline 입력 YAML 빌드(Stage B plan Task 3-4; recipe 확정 후).
- VAV1 활성/DC50.
- production VAV1 파이프라인 수정.

## Success criteria

1. `STAGEB_RECIPE.md` 존재 + 다음 명시: (a) 9D0W에서 복원한 target-side 메커니즘 + 조건별(nativeAB/wrongAB/baseline) 정확히 바뀌는 field/flag와 4 타깃 값; (b) per-target CRBN 앵커(W400 위치/anchor_patch/CRBN pocket) residue-walk 재유도 표; (c) 9D0W 비교가능성 진술(또는 bounce 결정).
2. 검증 스크립트가 4/4 타깃에서 **CRBN 앵커 pass** 출력(재유도 W400이 chain-A 서열의 실제 'W'에 떨어지고 anchor_patch in-range+기대 잔기) — fix_pocket_numbering.py의 resname cross-check와 동형.
3. 타깃별 config(≤4) parse + glueprint 블록 존재 + CRBN 앵커 필드 = 재유도 위치(보존 필드는 source와 diff상 의도된 변경만).
4. 결정 게이트 기록: **PROCEED**(깨끗한 매핑 + 9D0W-비교가능) 또는 **BOUNCE**(부모 /brainstorm로 라우팅) 중 하나를 명시.

- 검증 커맨드(예): `python3 analysis/heldout_placement_20260601/verify_heldout_anchor.py` → `CRBN anchor pass 4/4`; `grep -qE '9D0W|comparab|PROCEED|BOUNCE' analysis/heldout_placement_20260601/STAGEB_RECIPE.md`.

## Resource budget

- zero-compute (정독 + residue-walk 매핑 + config 파생 + 검증). GPU 0, SLURM 0.

## Approval

- requested: 2026-06-01
- approved by: user (2026-06-01, "승인")

## Rollback plan

- 진단/설정 전용 — production 미접촉. 산출물(recipe/config/스크립트) git revert로 복구. 생성·점수 없음.

## Done When

- 위 success criteria 1-4 충족 + 결정 게이트가 PROCEED 또는 BOUNCE로 확정.
- PROCEED면 Stage B plan Task 3부터 재개(입력 YAML 빌드). BOUNCE면 부모 contract /brainstorm.

## Verification

- STAGEB_RECIPE.md의 조건별 field/flag 표 + CRBN 앵커 재유도 표(4/4 pass) + 9D0W 비교가능성 진술/근거 인용.
- per-target config parse + glueprint 블록 + 앵커 필드 일치.
- 결정 게이트 한 줄(PROCEED/BOUNCE).

## Progress Log

- 2026-06-01: spec 초안 (brainstorm; 2번 CRBN 앵커 결함 확인 — 4/4 YAML pos355≠W). fork 3개 동결: ①9D0W 매칭 우선 ②CRBN 앵커 재유도만 ③실패 시 부모 bounce. 승인 대기.
- 2026-06-01: 승인 → write-plan(5 task) → execute-plan. Task 1·2 병렬 위임(독립). **결과 = BOUNCE** (FKSFold 07cdf2a): Task 1 NOT-MAPPABLE(9D0W AB = inter-chain crystal pair, 인용 검증), Task 2 CRBN 앵커 4/4 재유도(durable), Task 3 §3 순환-vs-비교가능성 충돌 문서화 → 결정 BOUNCE, Task 4 skip. code-review: 인용 실재 확인 + 앵커 스크립트 독립 재현. 다음 = 부모 held-out contract /brainstorm 재spec. plan status: done.
