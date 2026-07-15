---
contract: .agent/contracts/vav1-ubq-ternary-refine-minimization-20260625.md
slice: vav1-ubq
status: done
total_tasks: 4
estimated_total_min: 70
---

# Plan — VAV1 Ternary Refine (post-hoc constrained minimization, NO-overfit)

공통: env `/home/ubuntu/miniconda3/bin/python` (gemmi/numpy/scipy; OpenMM for min). 신규
스크립트 dir=`analysis/crl_integrative/` (`refine_` 접두사). 입력=MRT6160 orient=0 seeds
(/mnt/.../md_injection_productive_20260622/out/on/MRT6160/seed*_0/...model_0.pdb). refs: 9UUM,
9nfr_in_9uum.pdb, closure_spec.json. 채점=glue_competence.py(assemble+score). minimize 인프라
재사용: crl_md_prep.py/minimize_all.py(MRT6160 params는 seed314/crl_glue_md서 존재) 또는 OpenMM+
pdbfixer 폴백. **★NO-overfit 가드: 최소화 후 SH3c RMSD-to-9NFR이 collapse(>1.5Å 감소)하면 FAIL.**

---

## Task 1: consensus medoid 포즈 선정

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `analysis/crl_integrative/refine_consensus.py` (new), 출력 `/mnt/kfs2/.../vav1_zone_patch_20260623/refine/consensus_medoid.pdb`
- **Change shape**: MRT6160 orient=0 시드(123/1234/2024/271/314_0) 포즈를 9UUM 프레임으로 변환(zone_render_pose 로직),
  SH3c CA pairwise RMSD 행렬 → **medoid**(다른 시드 평균 RMSD 최소 = 가장 central, 실제 포즈라 평균-아티팩트 없음) 선정.
  medoid 포즈(CRBN+glue+VAV1, 9UUM 프레임)를 복사 저장 + 선정근거(각 시드 mean-to-others).
- **Verification**: `python refine_consensus.py` → medoid 시드 + 각 시드 mean-RMSD-to-others 표 + consensus_medoid.pdb 저장.
- **Estimated time**: 12 min
- **Rollback**: rm refine_consensus.py + 출력

## Task 2: 최소화-ready 시스템 빌드 (CRBN+glue+VAV1)

- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: `analysis/crl_integrative/refine_build.py` (new), 출력 `/mnt/.../refine/system.{prmtop,inpcrd}` 또는 OpenMM system
- **Change shape**: medoid 삼원(CRBN+MRT6160+VAV1)을 최소화 시스템으로. **1차**: crl_md_prep 재사용(MRT6160 param 존재)으로
  prmtop/inpcrd. **폴백(친화도 낮을 시)**: OpenMM+pdbfixer로 단백질(amber14) + glue는 **frozen rigid**(param 회피) —
  계면 완화엔 충분. 9UUM 코어는 최소화에 미포함(계면=CRBN+glue+VAV1만; 9UUM은 T4 채점 프레임).
- **Verification**: `python refine_build.py` → 시스템 빌드 성공(원자수·전하 sane) + t0 에너지 평가 finite(폭발 없음).
- **Estimated time**: 20 min
- **Rollback**: rm refine_build.py + 출력

## Task 3: 제한 최소화

- **Status**: pending
- **Prereq tasks**: 2
- **Files touched**: `analysis/crl_integrative/refine_minimize.py` (new), 출력 `/mnt/.../refine/minimized.pdb`
- **Change shape**: OpenMM 최소화 — **CRBN 백본 position-restraint**(기준 프레임 고정) + **degron 접촉 soft
  restraint**(R796/D797/S799↔pocket, 약한 거리 bias) + VAV1 SH3c·곁사슬·계면 relax + (glue: param 시 자유,
  폴백 시 frozen). 단계적(steepest→L-BFGS), 수렴까지. 최소화 전/후 좌표 저장.
- **Verification**: `python refine_minimize.py` → 에너지 하강·수렴 + minimized.pdb 저장 + 좌표 이동량(RMSD before→after) 출력(폭발 아님).
- **Estimated time**: 18 min
- **Rollback**: rm refine_minimize.py + 출력

## Task 4: before/after 채점 + NO-overfit 가드 + 리포트

- **Status**: pending
- **Prereq tasks**: 3
- **Files touched**: `analysis/crl_integrative/refine_results_20260625.md` (new), `.agent/status/vav1-ubq.md`, contract Progress Log
- **Change shape**: medoid(before) vs minimized(after) 둘 다 **glue_competence로 채점**(9UUM 조립: degron 기능기 거리·
  zone 라이신·clash) + **SH3c RMSD-to-9NFR**(before/after) + intra-ligand/clash strain. ★**NO-overfit 어서트**:
  |RMSD_after − RMSD_before| 작아야(완화지 refit 아님); after RMSD가 >1.5Å collapse면 FAIL 명기. clean PDB 산출.
  리포트(before/after 표 + NO-overfit 판정 + STRUCTURE-only) + baton + 커밋(내 파일만).
- **Verification**: 리포트 before/after 표 + `NO-overfit: PASS/FAIL`; clash↓ & degron tighten 확인; `git log -1` 새 커밋; FKSFold 복사.
- **Estimated time**: 20 min
- **Rollback**: git revert 해당 커밋 (내 파일만)

---

## 실행 순서 (ultracode)
T1→T2→T3→T4 순차(각 게이트 검증). T4에서 before/after를 adversarial하게 본다(over-fit 신호 = RMSD collapse).
GPU 불요(OpenMM 최소화 CPU). glue param 마찰 시 폴백(frozen glue) 즉시 전환.
