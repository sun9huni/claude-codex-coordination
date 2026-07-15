---
contract: .agent/contracts/vav1-ubq-tau-ramd-residence-pilot-20260625.md
slice: vav1-ubq
status: done
total_tasks: 12
estimated_total_min: 78
outcome: STOP@GATE-A (T2) — pilot infeasible on 143-set as-generated; GPU 0. T3–T10 skipped per STOP path. Report=analysis/crl_integrative/tau_ramd_residence_pilot_results_20260625.md
---

# Plan — τ-RAMD Ternary Residence-Time Pilot

**Ordering principle (시간 낭비 방지)**: 두 *조기 STOP 게이트*를 큰 GPU 지출 *앞에* 둔다 —
GATE-A(T2, zero-GPU: congeneric 서브셋 없으면 STOP, GPU 0) · GATE-B(T6, 저-replica: egress 무분별이면
STOP, full run 안 함). 사전등록(T7)은 full run(T8) *전*. 각 STOP = 문서화된 음성.

작업 디렉토리: `analysis/crl_integrative/tau_ramd/` (스크립트), 출력 `/mnt/kfs2/data/users/ubuntu/tau_ramd_20260625/`.

---

## Task 1: locate compound SMILES/structures + scaffold-cluster the 143
- **Status**: done (56f276e — 143/143 SMILES mapped, 45 clusters, 5 candidates; ★generic scaffold coarse → S003 n=12 cleanest mid-size)
- **Prereq tasks**: none
- **Files touched**: `analysis/crl_integrative/tau_ramd/stage0_scaffold_cluster.py`, output `…/tau_ramd/stage0_clusters.tsv`
- **Change shape**: 143 compound IDs(per_compound_decomposed.csv)에 SMILES/구조를 조인(소스 탐색: configs/vav1_pipeline/, 빌드 ligand, InChIKey). RDKit Bemis-Murcko scaffold로 클러스터 → 클러스터별 N + logDC50 span 표.
- **Verification**: `python …/stage0_scaffold_cluster.py` → `stage0_clusters.tsv`에 scaffold별 (N, DC50 min/max/span); ≥8 화합물 & span ≥1.5 log인 후보 클러스터를 *명시 표시* (없으면 "none" 행).
- **Estimated time**: 8 min
- **Rollback (this task only)**: rm stage0_clusters.tsv (읽기-전용 분석, 무해)

## Task 2: ★GATE-A — confirm CONSERVED BINDING MODE → write congeneric_subset.tsv (or STOP)
- **Status**: done (bd36323 — **STOP**: 4 후보 클러스터 모두 보존 서브셋 없음. SH3c degron RMSD-to-medoid median 6.9–22Å·max 45–49.5Å·보존≤2Å 1–2/n(7–25%); intra-compound seed median 14.6Å·2/44만 <2Å. glue core는 일관 도킹(MCS RMSD 대부분 <1–3.5Å)이나 degron 흩어짐. → 플랜의 "STOP=없음→T11 직행" 경로)
- **Prereq tasks**: 1
- **Files touched**: `analysis/crl_integrative/tau_ramd/stage0_binding_mode.py`, output `…/tau_ramd/congeneric_subset.tsv`
- **Change shape**: 후보 클러스터 화합물들의 *생성/9NFR-앵커 삼원 포즈*를 CRBN-정렬 후 glue-core RMSD + degron 배향 비교 → 결합모드 보존 여부. 보존되는 최대 서브셋(N≥8, 강/중/약 포함) 확정.
- **Verification**: `python …/stage0_binding_mode.py` → `congeneric_subset.tsv`(compound·scaffold·logDC50·core_RMSD·binding-mode tier). **PASS=적격 서브셋 존재** / **STOP=없음**(→ 플랜 종료, 음성 문서화, T11로 직행). core RMSD 게이트 명시(예: ≤2Å).
- **Estimated time**: 10 min
- **Rollback (this task only)**: rm congeneric_subset.tsv

## Task 3: implement RAMD random-force in OpenMM + CPU smoke
- **Status**: skipped (GATE-A STOP — moot; no congeneric subset to run)
- **Prereq tasks**: none
- **Files touched**: `analysis/crl_integrative/tau_ramd/ramd_force.py`
- **Change shape**: OpenMM CustomCentroidBondForce/외력으로 *pulled 그룹(VAV1)* COM에 일정-크기 무작위방향 힘 + Δt마다 진행도 평가해 재방향(표준 RAMD). flag/param화(force 크기, 재방향 stride, egress 기준 거리).
- **Verification**: `python -m pytest …/test_ramd_force.py -k smoke` 또는 1-system 짧은 CPU 런 → VAV1 COM이 힘 방향으로 가속+egress 거리 도달 로그. (엔진 미접촉, 별도 모듈.)
- **Estimated time**: 10 min
- **Rollback (this task only)**: rm ramd_force.py (flag-gated 별도 모듈, 기존 코드 무영향)

## Task 4: build/collect MD-ready ternary systems for the subset
- **Status**: skipped (GATE-A STOP — moot)
- **Prereq tasks**: 2
- **Files touched**: `analysis/crl_integrative/tau_ramd/build_subset_systems.py`, output `…/tau_ramd/systems/<cmpd>/{prmtop,inpcrd}`
- **Change shape**: 서브셋 각 화합물 삼원을 MD-ready로 — 기존 143 삼원 구조 재사용(있으면) 또는 glue-MD 빌드 파이프라인(graft+parmed, ff19SB/GAFF2) 재활용. 용매/이온 최소(egress용 충분 박스).
- **Verification**: 각 `<cmpd>/`에 prmtop+inpcrd; t0 sanity(degron 접촉 존재·clash<gate) 1줄 로그/시스템.
- **Estimated time**: 8 min (감독; 빌드 자체는 백그라운드)
- **Rollback (this task only)**: rm -r …/tau_ramd/systems (/mnt, 무해)

## Task 5: force-magnitude calibration (2 magnitudes × 2–3 systems) — SLURM smoke
- **Status**: skipped (GATE-A STOP — moot; no GPU submitted)
- **Prereq tasks**: 3, 4
- **Files touched**: `analysis/crl_integrative/tau_ramd/tau_ramd_run.py`, `…/tau_ramd/slurm_calib.sh`
- **Change shape**: 강/약 DC50 2–3 시스템에 τ-RAMD 2 force 크기 × 소수 replica. ⛔SLURM 게이트(컨트랙트 승인됨; execute-plan이 제출 전 확인).
- **Verification**: egress 시간 로그 — 선택 force서 egress가 *즉시도 영원도 아님*(bounded). 채택 force 1–2점 기록 `calib.txt`.
- **Estimated time**: 6 min (제출+판독; 런은 짧음)
- **Rollback (this task only)**: scancel; rm /mnt calib 출력

## Task 6: ★GATE-B — low-replica egress on FULL subset → discrimination check (or STOP)
- **Status**: skipped (never reached — GATE-A STOP upstream)
- **Prereq tasks**: 5
- **Files touched**: `…/tau_ramd/slurm_lowrep.sh`, output `…/tau_ramd/lowrep_egress.tsv`
- **Change shape**: 채택 force로 *전 서브셋* 저-replica(~5) egress. ⛔SLURM 게이트.
- **Verification**: `lowrep_egress.tsv`(compound·egress 시간들). **분별력 게이트**: 서브셋 egress 중앙값 spread > replica 분산(또는 max/min ≥~2×) → **PASS** / 무분별(all-too-fast) → **STOP**(얕은-계면 실패 문서화, T11). 게이트 수식 명시.
- **Estimated time**: 6 min (제출+spread 판정)
- **Rollback (this task only)**: scancel; rm lowrep 출력

## Task 7: ★pre-register Stage-2 tier criterion (BEFORE full run / seeing ranking)
- **Status**: skipped (never reached — GATE-A STOP upstream)
- **Prereq tasks**: 6
- **Files touched**: `analysis/crl_integrative/tau_ramd/stage2_preregistration.md`
- **Change shape**: 강 tier(logDC50<X)·약 tier(>Y) 경계, 예상 방향(강 residence>약), 게이트 지표(tier 중앙 분리 + 비중첩/AUC; Spearman ρ는 *보고*) 동결. X/Y는 서브셋 DC50 분포로 정함(ranking 보기 전).
- **Verification**: 파일 존재 + timestamp; T8 출력 *전* 작성됨(git/파일 mtime로 확인).
- **Estimated time**: 5 min
- **Rollback (this task only)**: rm stage2_preregistration.md

## Task 8: full τ-RAMD egress — subset × ~20 replicas × chosen force(s)
- **Status**: skipped (never reached — GATE-A STOP upstream; no GPU submitted)
- **Prereq tasks**: 6, 7
- **Files touched**: `…/tau_ramd/slurm_full.sh`, output `…/tau_ramd/full_egress/`
- **Change shape**: 전 서브셋 full-replica egress(저-replica T6 재사용 가능). ⛔SLURM 게이트, ~150–200 GPU-hr 상한.
- **Verification**: 화합물별 egress 시간 분포(≥~20) + 완료 카운트; `full_egress/<cmpd>/egress_times.txt`.
- **Estimated time**: 6 min (제출+감시; 런은 수시간)
- **Rollback (this task only)**: scancel; rm full_egress (/mnt)

## Task 9: compute relative residence ranking + bootstrap CIs
- **Status**: skipped (never reached — GATE-A STOP upstream)
- **Prereq tasks**: 8
- **Files touched**: `analysis/crl_integrative/tau_ramd/residence_rank.py`, output `…/tau_ramd/residence.tsv`
- **Change shape**: 화합물별 mean egress → 상대 residence(τ); bootstrap CI; DC50 join.
- **Verification**: `python …/residence_rank.py` → `residence.tsv`(compound·tau·CI·logDC50), 정렬.
- **Estimated time**: 5 min
- **Rollback (this task only)**: rm residence.tsv

## Task 10: apply pre-registered tier gate (PASS/FAIL)
- **Status**: skipped (never reached — GATE-A STOP upstream)
- **Prereq tasks**: 7, 9
- **Files touched**: `analysis/crl_integrative/tau_ramd/stage2_gate.py`, output `…/tau_ramd/stage2_verdict.txt`
- **Change shape**: T7 동결 기준을 residence.tsv에 적용 — tier 분리 + Spearman ρ. PASS=예상방향 분리 / FAIL=무분리.
- **Verification**: `python …/stage2_gate.py` → `stage2_verdict.txt`(tier 중앙값·분리·ρ·PASS/FAIL); T7 기준과 대조.
- **Estimated time**: 5 min
- **Rollback (this task only)**: rm stage2_verdict.txt

## Task 11: result report (verdict + honest ceiling) + fks mirror
- **Status**: done — `analysis/crl_integrative/tau_ramd_residence_pilot_results_20260625.md` (+ fks 미러). 판정=STOP@GATE-A·수치·★천장 caveat·structure↔DC50 null 재확인·unblock path(스티어링 재생성 선결 또는 SPR)·residence_time deepresearch 링크.
- **Prereq tasks**: 10 (또는 GATE-A/B STOP 시 그 지점에서 직행)
- **Files touched**: `analysis/crl_integrative/tau_ramd_residence_pilot_results_20260625.md` (+ fks 미러)
- **Change shape**: 판정(PASS / STOP@GATE-A / STOP@GATE-B / FAIL@tier)·수치·★천장 caveat(거친 순위지 prospective 예측 아님; n·prior). residence_time deepresearch와 링크.
- **Verification**: 리포트 존재 + `cp` fks 미러 확인.
- **Estimated time**: 8 min
- **Rollback (this task only)**: rm 리포트(+fks 사본)

## Task 12: update vav1-ubq baton + handoff
- **Status**: pending
- **Prereq tasks**: 11
- **Files touched**: `.agent/status/vav1-ubq.md`
- **Change shape**: 결과 1줄 요약 + 컨트랙트/플랜 done 표기. `./scripts/handoff.sh claude vav1-ubq` + `status.sh index`.
- **Verification**: status frontmatter 갱신 + Stop 훅 통과(handoff 스냅샷).
- **Estimated time**: 3 min
- **Rollback (this task only)**: git checkout .agent/status/vav1-ubq.md
