---
status: active
slice: aigen-fold-core
topic: pocketonly-panel-control
date: 2026-06-18
owner: claude
approved_by: user (2026-06-18, "다른 개선된 주요 구조도 측정해보자")
triggers_matched:
  - "SLURM/GPU evaluation run"
  - "multi-target benchmark criteria"
---

# Pocket-only panel control — (steer-OFF + pocket-ON) across improved OOD targets

## 동기
4-cell factorial(job 7688)이 **(steer-OFF + pocket-ON)** = pure Boltz2 + pocket constraint 하나만
을 **9H59·9DWW 2개에서만** 실측(0.567/0.580 ≈ full AIGEN → steering 기여 ≈0). 나머지 *개선된 주요
OOD 구조*는 이 셀이 미측정 → "AIGEN의 Boltz2+pocket 대비 value-add"가 패널 전체로 미확정. 이 칸을
채우면 "성능 개선 레버 = steering인가 pocket인가"가 결정적으로 닫힌다.

설정 검증 완료(소스): `boltz2_baseline` 분기 = COMMON_ARGS + `--num_particles 1`만 = steering·w400
conditioning·biophysical·interface_GD **전부 미전달**(러너 slurm_crystalfree_router_20260615.sh:102-143).
입력 YAML = WITH-pocket `{PID}.yaml`(constraints 블록 = pocket 하나, anchor/NPZ 없음).

## Scope
- arm: `condition=boltz2_baseline` + WITH-pocket `{PID}.yaml`, num_particles 1, steering/conditioning 전무.
- 대상: **9OTY(CK1α)·9Q33(PRDM1)·9OS2(G3BP2⚠)·9Q03(BCL6)** × 8 seed(42/16/123/7/99/256/314/512) = 32 cell.
  (9H59·9DWW는 7688에서 done — auto-skip.)
- 채점: 기존 score_heldout_dockq.py로 DockQ → baseline/pocket-only/AIGEN 3열 비교표.

## Out of scope
- steering 튜닝·새 pocket 잔기·Layer B 없음.
- Panel A co-success(이미 잘 됨)·CDK2 9NYR(YAML이 12-panel stage라 별도 staging 필요) 제외.
- prospective 주장 없음(pocket = crystal-derived = retrospective).

## Success criteria
- 4개 타깃 pocket-only median/best DockQ 실측 → **steering 한계기여(AIGEN − pocket-only) 패널 정량**.
- 결정규칙: pocket-only ≈ AIGEN(±0.1) on ≥3/4 → "steering 무용, 레버=pocket" 패널 확정;
  일부서 pocket-only ≪ AIGEN → 그 타깃은 steering 시너지 실재(재조사).
- 검증 커맨드: metrics_pocketctrl_panel.tsv + 비교표(baseline|pocket-only|AIGEN).

## Resource budget
32 cell, num_particles 1(steering/resampling 없음=경량), qos=batch(gpu≤4), ≲1 GPU-hr aggregate.
러너/입력 기존 자산 재사용(신규 코드 0). 산출 dir = crystalfree_router_20260615/outputs/{PID}_pocketctrl_*.

## Rollback
scancel job; 출력은 workspace(삭제 가능), repo 쓰기 없음. manifest는 stage에 신규 파일만 추가.
