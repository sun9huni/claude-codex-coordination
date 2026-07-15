---
status: proposed
slice: aigen-fold-core
topic: full9uum-context-cofold
date: 2026-06-25
owner: (unassigned — PROPOSAL authored by vav1-ubq session for aigen-fold-core owner to adopt)
approved_by: (pending owner adoption + GPU gate)
requested: 2026-06-25
cross_slice:
  - "PROPOSED by vav1-ubq (glue-competence/zone work). EXECUTION belongs to aigen-fold-core (engine/generation). Needs that owner to adopt + a SLURM/GPU gate. vav1-ubq provides the competence filter as the scorer."
triggers_matched:
  - "SLURM/GPU submission — large-assembly cofold generation (heavy)"
  - "엔진 코드 — Boltz/FKSFold context/template cofold path (aigen-fold-core 소관)"
---

# Full-9UUM-Context Cofold — generate VAV1+glue ternary INSIDE the active CRL4 (PROPOSAL)

## Purpose

현재 ternary 포즈는 **CRBN+glue+VAV1 삼원만** 생성되고 9UUM은 *사후 중첩*으로 붙는다(placement가
어셈블리에 의해 제약되지 않음). 이 제안: **VAV1+glue를 활성 CRL4(9UUM: CRBN-DDB1-CUL4-E2~Ub)
맥락 안에서 cofold** → placement가 어셈블리에 의해 *내재적으로* 제약되고 zone 기하가 사후가 아닌
생성-내적. 가설: 회전 모드(orient p30–p75 실패)가 줄고, orient=0 near-native가 유지/강화된다.

근거(vav1-ubq): steered orient=0는 이미 near-native(다중시드 2.34Å 수렴, MRT6160 ~4Å). 단 placement는
사후-중첩이고 교란 배향은 회전 FAIL. 활성 어셈블리 맥락이 placement를 더 조이는지 테스트할 가치.

## Current State

- 9UUM ref `analysis/crl_integrative/refs/9UUM.cif`(활성 어셈블리). competence 필터
  `glue_competence.py`(채점 준비됨, vav1-ubq). 현 생성 = md_injection_productive(삼원만, 사후 9UUM).
- 엔진: FKSFold-Boltz(platform-versioning-r20260417). 대형-context cofold/templating 지원 여부 **선검증 필요**.

## Assumptions And Questions

- **[질문/선검증]** 엔진이 9UUM-크기 어셈블리를 context/template로 받는 cofold를 지원하나? 안 되면
  scope 축소(CRBN+E2~Ub 인접부만) 또는 (b)의 제한-MD로 대체.
- **[가정]** 9NFR은 여전히 정답지 아님(MRT-23227≠MRT6160) → 평가는 competence 필터(PASS율·회전감소)지
  9NFR-RMSD 최소화 아님(over-fit 금지).

## Constraints

- **GPU(무거움)**, SLURM 게이트, 엔진 코드 = aigen-fold-core 소관(#12/WIP 조율).
- STRUCTURE-only; 9NFR-refit 금지; potency 아님.
- vav1-ubq는 **scorer만 제공**(glue_competence), 엔진 미접촉.

## Non-Goals

- potency/효율; 9NFR을 정답지로 한 over-fit; vav1-ubq 슬라이스 코드.

## Done When

1. **엔진 지원 선검증**: 9UUM(또는 CRBN+E2~Ub 인접부) context cofold가 가능한지 smoke(1셀).
2. **in-context 생성**: VAV1+glue + 9UUM context + 인터페이스 스티어링, multi-seed/orient.
3. **competence 채점**: glue_competence로 in-context 포즈 PASS율 + 회전(p-셀) 실패율 측정.
4. **대조**: 사후-중첩(현재) vs in-context — placement 조임(회전 감소)·orient=0 오프셋 변화 정량.

## Implementation Steps

(상세=/write-plan, aigen-fold-core가 채택 시) 엔진 context-cofold 경로 확인/배선 → smoke → SLURM
multi-seed 생성 → vav1-ubq competence 채점 → 대조 doc.

## Change Discipline

엔진 코드는 aigen-fold-core 소관(flag-gated, #12/WIP 미접촉). 생성 출력 /mnt(빈 브랜치).

## Verification

competence 필터 PASS율(in-context vs 사후) + 회전-모드 실패율 + orient=0 RMSD-to-9NFR Δ.

## Risks

- **R1 엔진 미지원** → scope 축소 또는 (b) 대체.
- **R2 대형 cofold 비용/수렴** → SLURM 게이트, smoke 선행.
- **R3 over-fit 유혹** → 평가는 competence지 9NFR-RMSD 아님.

## Rollback

엔진 변경은 flag-gated/별도 checkpoint; 생성 출력 삭제로 무해.

## Preflight verdict (zero-GPU, workflow wf_8e8ccf35-636, 4 agents — 2026-06-25)

**Done#1 (엔진 지원 선검증) ANSWERED**:
- **literal full-9UUM-as-FIXED-context = needs_engine_change.** diffusionv2_extend.py:354 모든 원자를
  noise서 초기화 + :363-371 매 step 전체-텐서 random rotation/recenter → 고정 스캐폴드 못 살아남음.
  per-atom freeze/seed 없음(유일 freeze 프리미티브 blind_freeze_non_target_gd는 W400 guidance 배율일 뿐).
  9UUM은 설계상 rigid external ref(Kabsch-carry), 생성 텐서에 안 들어감. config로 unlock 불가;
  path-2(~4 edit: YAML fixed-entity schema + per-atom is_fixed mask + sample-loop overwrite/exclude +
  potential gating) 필요. **token 폭증 회피하려면 CRBN+E2~Ub subset 먼저(저위험).**
- **★그러나 실질 목표(어셈블리-제약 placement)는 이미 구현됨 = `CRLClosurePotential`**
  (crl_closure_potential.py): 매 step 9UUM CRBN+E2~Ub를 live CRBN에 Kabsch-carry + cone-reach +
  Tri-Trp clamp를 diffusion 시점 내재 주입(9UUM 원자 추가 0, 3-chain 비용 그대로, gradient→VAV1+CRBN).
  **commit+smoke 통과**(ed1a2e0 "1-step e2e smoke 4/4"). = preflight의 "subset middle path"이자
  본 (c)의 실질 답.
- **★수렴**: 이 CRLClosurePotential = assembly-closure 작업(vav1-ubq서 시작→aigen-fold-core). aigen-fold-core
  baton에 **staged T10**(run_closure_paired.sh, 16 cells OFF/ON, 4축 scorer) = **⛔ GPU go 대기**.
  → **(c) ≈ aigen-fold-core T10**. 새 엔진 작업 불요(steering path), GPU 승인만 필요.
- **GPU 비용**: steering path = 현 캠페인과 동일(3-chain ~420 token + 작은 per-step Kabsch). path-2 엔진변경은
  GPU보다 엔지니어링/정합 리스크가 비용.

**개정 권고**: 이 contract를 **"steering path = aigen-fold-core T10 실행"**으로 좁힘(literal full-fixed-context는
path-2로 *deferred*, steering 불충분 입증 시만). vav1-ubq는 T10 산출을 glue_competence로 채점.

## Progress Log

- 2026-06-25: PROPOSAL 작성(status: proposed). vav1-ubq 세션이 (c)로 설계.
- 2026-06-25: **preflight DONE**(zero-GPU, wf_8e8ccf35-636). 판정=needs_engine_change(literal) but
  steering path(CRLClosurePotential) 이미 구현+smoke = **aigen-fold-core staged T10**. → (c) 실행 = T10
  GPU go. path-2(fixed-chain, CRBN+E2~Ub subset)는 deferred.
- 2026-06-25: ★**(c) 실질실행 = aigen-fold-core가 이미 완료.** 사용자 "승인"(T10 GPU go) 시점에 확인하니
  aigen-fold-core는 **LIVE 소유**(session 0e1a393f, heartbeat 09:52Z)이고 **T10b job 8321 = COMPLETED**
  (7m40s, host-10-0-3-100; CRL 미발화 버그 d5a727c 수정 후 재돌림, OFF arm 보존+ON arm 재제출). →
  **vav1-ubq(나)는 제출 안 함**(contested-live 슬라이스 중복 GPU 충돌 회피 = diagnose-before-scale가 막음).
  aigen-fold-core owner가 score_closure_paired.py 4축 + branch verdict(PASS→T16/FAIL→T11 IK) 채점 예정.
  **vav1-ubq 기여 = (c) 완결**: preflight(엔진변경 불요·steering path) + glue_competence/zone scorer를
  *독립 cross-check*로 제공 가능. status=proposed 유지(literal path-2만 미실행).
- 2026-06-25: **★(c) cross-check DONE**(vav1-ubq, closure_crosscheck.py, READ-ONLY on job 8321 out/{off,on}).
  우리 placement/competence 렌즈로 8 MRT6160 시드 OFF vs ON 채점: **placement FLAT/orthogonal** — mean degron
  2.62→2.50/3, mean SH3c RMSD-to-9NFR 5.8→5.8Å, PASS 6/8→7/8(노이즈). 즉 CRLClosurePotential은 placement를
  **개선도 손상도 안 함**(OFF도 이미 steered near-native; closure는 *촉매 near-attack* 항이라 placement 차원
  아님). **핵심 보완: closure 스티어링이 binding placement를 망가뜨리지 않고 촉매 기하 달성**(net 중립, 일부 시드만
  placement↔cone-reach trade). "closure 도움?"의 진짜 판정 = aigen-fold-core near-attack 4축(그쪽 primary).
  노트=analysis/crl_integrative/closure_crosscheck_results_20260625.md.
