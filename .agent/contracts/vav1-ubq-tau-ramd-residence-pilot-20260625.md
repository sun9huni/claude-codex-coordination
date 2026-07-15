---
status: done
slice: vav1-ubq
topic: tau-ramd-residence-pilot
date: 2026-06-25
approved_by: user (2026-06-25)
requested: 2026-06-25
triggers_matched:
  - "SLURM/GPU submission (τ-RAMD egress runs, heavy)"
  - "shared-storage writes (/mnt outputs)"
  - "4+ files (Stage-0 selector + τ-RAMD driver/launcher + scorer + report)"
  - "possible engine/tooling addition (RAMD random-force not yet in our OpenMM stack)"
references:
  - analysis/crl_integrative/residence_time_determinant_deepresearch_20260625.md
  - analysis/crl_integrative/project_diagnosis_and_plan_20260625.md (§3.5 정정)
---

# τ-RAMD Ternary Residence-Time Pilot — congeneric subset of the 143 vs DC50

## Purpose / Hypothesis

검증된 determinant는 **삼원 residence time(koff)**이다(Roy-Ciulli SPR ↔ 분해). 이 pilot은 그걸 *습식 SPR
없이* **계산으로 모사**(τ-RAMD)해, **143-set의 한 congeneric 서브-시리즈에서 예측 residence 순위가 실측
DC50을 (거칠게라도) 가르는지** 본다. 가설: *"τ-RAMD egress 순위가 congeneric 서브셋의 강/약 DC50 tier를
분리한다."* CRBN-글루 삼원에 kinetics를 적용한 *문헌 최초* 시도(딥리서치 wf_69cbd59a-534 confirm).

## Scope

- **Stage-0 (zero-GPU)**: 143에서 *congeneric 서브-시리즈* 식별 — 같은 scaffold + **보존된 결합모드** +
  DC50 dynamic range(강/중/약). 이것이 전체를 게이트한다.
- **Stage-1 (GPU)**: 그 서브셋 각 삼원(CRBN–glue–VAV1-SH3c)에서 **τ-RAMD egress**(VAV1을 받개에서 밀기),
  multi-replica, force-magnitude 보정 → 상대 residence 순위.
- **Stage-2 (zero-GPU 분석)**: *사전등록된* tier-분리 판정(아래 Done When).
- 2-stage 성공기준(사용자 결정): 분별력(dynamic range) 먼저 → tier 상관.

## Out of Scope

- **전체 교차-scaffold 143**(문헌·우리 multivariate가 예측하는 null — 의도적 배제).
- **절대 koff**(상대 순위만). **prospective DC50 *예측***(거친 순위지 예측 아님 — 천장은 세포 confounder).
- **습식 SPR**(검증된 금표준이나 실험팀 자원 — *별도* 컨트랙트/핸드오프).
- **신규 글루 설계**, **near-attack(촉매-기하) metric**(다른 축 — eLife 선례 있으나 별건),
  **엔진/생성 코드 변경**, **포즈 재생성**.

## Success Criteria (2-stage, pre-registered)

- **Stage-0 PASS**: scaffold·결합모드·DC50 range를 만족하는 서브셋(목표 N≈10–12, 최소 N≈8, DC50 span
  ≥~1.5 log, 강/중/약 포함)을 *식별·표로 박제*. **없으면 STOP**(pilot 불가, 문서화 — "143에 적격
  congeneric 서브셋 부재"). 검증: `congeneric_subset.tsv`(compound·scaffold·DC50·binding-mode 근거).
- **Stage-1 분별력 게이트**: 화합물별 egress 시간 ± 오차. **dynamic range 있어야**(예: 서브셋 egress
  중앙값들의 spread가 단일-화합물 replica 분산보다 유의하게 큼; 또는 max/min ≥ ~2×). **all-too-fast/무분별
  → 얕은-계면 실패모드 확정, STOP+문서화**.
- **Stage-2 tier 게이트(★사전등록, Stage-1 결과 보기 *전* 동결)**: 강 tier(DC50<X) 중앙 residence >
  약 tier(DC50>Y) 중앙 residence, *예상 방향*. Spearman ρ(예측 residence, logDC50) 보고하되 **게이트는
  tier-분리**(방향 + 비중첩/AUC). PASS=분리 / FAIL=무분리(→ residence-mimic 글루 부적합, SPR로 deferral).

## Resource Budget

- Stage-0: zero-GPU, ~반나절.
- Stage-1: **GPU ~150–200 GPU-hr 상한**(medium 서브셋 ~10–12 × ~20 replica × force 2점). 기존 143 삼원
  구조 재사용(있으면); 없으면 서브셋만 graft 빌드. 인프라=un-containerize+kim batch+free-GPU
  ([[reference-slurm-free-gpu-selection]]).
- ★**툴링 의존성**: RAMD random-force가 현 OpenMM 스택(crl_md_run.py)에 *없음* → OpenMM custom force로
  구현(또는 NAMD/GROMACS-RAMD 도입). 구현/검증 비용 = Stage-1 선행(smoke).

## Approval

- requested: 2026-06-25
- approved_by: pending (SLURM/GPU 게이트 — 이 컨트랙트가 그 게이트)

## Rollback

- τ-RAMD 출력 = /mnt 빈 브랜치 → 삭제로 무해. SLURM 잡 취소 가능.
- 엔진/커밋 코드 변경 없음(RAMD force는 flag-gated 별도 모듈/스크립트). Stage-0 산출은 문서(tsv).
- 어느 게이트서든 STOP=정직한 음성으로 문서화(낭비 GPU 없음 — Stage-0/분별력 게이트가 조기 차단).

## Risks

- **R1 (Stage-0)**: 143에 적격 congeneric 서브셋 *부재* → pilot 불가. (가장 가능성 있는 조기 종료.)
- **R2 (Stage-1)**: 얕은 glue 계면 → too-fast egress·무분별(딥리서치 명시 실패모드). 분별력 게이트가 차단.
- **R3**: τ-RAMD force-magnitude·어느 단백 밀기(VAV1 vs glue) 민감 — 문헌상 per-system 튜닝 필요(순위는
  force에 robust하나 binary보다 정확도 낮음).
- **R4 (천장)**: 통과해도 *거친 순위*(Weiss-class nM/μM)지 prospective 예측 아님 — 세포 confounder
  (E3/E2·재합성·투과성·hook·MW)가 상한. over-claim 금지.
- **R5**: 시작 삼원 구조 = 우리 생성/9NFR-앵커 포즈(자체 불확실성) — τ-RAMD 결과가 그 포즈 품질에 의존.
- **R6**: 단일 PROTAC 선례(JACS Au R=0.92)는 n=7·오차범위 안·koff↔koff(DC50 아님) — 우리 prior moderate-low.

## Verification (Done When)

Stage-0 tsv 존재 + (PASS/STOP 판정) → Stage-1 egress + 분별력 게이트(PASS/STOP) → Stage-2 사전등록 tier
판정(PASS/FAIL) → 결과 리포트(`tau_ramd_residence_pilot_results_*.md`, fks 미러). 어느 단계 STOP이든
*문서화된 음성*이 deliverable.

## Change Discipline

RAMD force = flag-gated 별도 모듈(엔진 미접촉, aigen-fold-core WIP 조율 불요 — vav1-ubq 독립). 출력 /mnt.
사전등록(Stage-2 tier 정의)은 Stage-1 결과 전 동결.

## Progress Log

- 2026-06-25: /brainstorm 완료. 성공기준=2-stage(분별력→tier), 예산=GPU ~150–200hr(Stage-0 선행),
  SPR=별도. status: pending(승인 대기). 근거=residence_time_determinant_deepresearch_20260625.md.
- 2026-06-25: 승인 → plan 실행. **STOP @ GATE-A (Stage-0 PASS=없음). GPU 0 소비.** status: done.

## Notes (closure 2026-06-25)

**판정: STOP @ GATE-A** — pilot 불가(Risk R1 실현: 143에 적격 congeneric 서브셋 부재). plan
`.agent/plans/vav1-ubq-tau-ramd-residence-pilot-20260625.md` 참조(T1 done · T2 STOP · T3–T10 skipped ·
T11 report · T12 handoff).

- **T1(PASS-1차, `56f276e`)**: generic Bemis-Murcko scaffold + DC50-span으로 5개 후보 클러스터
  (S001 n=32 … S005 n=8). chemistry만으론 feasible.
- **T2(★GATE-A STOP, `bd36323`)**: *생성 삼원 포즈*의 결합모드 보존 검사 — glue **core**는 CRBN 포켓에
  일관 도킹(ligand MCS RMSD 대부분 <1–3.5Å)이나 **VAV1-SH3c degron은 medoid 대비 0→49.5Å 흩어짐**
  (보존≤2Å: 1–2/n, 7–25%). 더 결정적: 같은 화합물 두 시드(314/99) SH3c 불일치 **median 14.6Å, 2/44만
  <2Å, 17/44가 >20Å**. 시작 placement가 노이즈 → egress 순위 = residence 아닌 포즈-생성 분산. GATE-B
  도달 불요.
- **근본원인**: `seed_pilot_20260415`는 **interface 스티어링(orient=0/9NFR-앵커) 없는 자유 삼원 생성**
  → VAV1 flop. (우리 박제: unsteered 23Å off vs steered orient=0 ~4Å near-native.)
- **재확인**: structure↔DC50 null(0/36 FDR)의 메커니즘 한 층 — placement가 노이즈면 placement-의존
  점수는 DC50과 상관 불가.
- **Unblock(별도 scope·별도 컨트랙트)**: (1) 서브셋을 스티어링/앵커로 *재생성*해 수렴된 near-native
  placement 선확보 후 τ-RAMD(엔진/생성=aigen-fold-core 조율, GPU), 또는 (2) 습식 SPR(실험팀).
- **천장 caveat 유지(R4/R6)**: 통과했어도 거친 순위지 prospective 예측 아님.
- 산출: `analysis/crl_integrative/tau_ramd/{stage0_scaffold_cluster.py,stage0_clusters.tsv,
  stage0_binding_mode.py,congeneric_subset.tsv}` + 리포트 `…/tau_ramd_residence_pilot_results_20260625.md`
  (+ fks 미러). **GPU/SLURM 미사용** — 2-stage 게이트가 ~150–200 GPU-hr을 zero-compute에서 차단.
