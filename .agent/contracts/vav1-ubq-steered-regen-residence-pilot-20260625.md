---
status: done
slice: vav1-ubq
topic: steered-regen-residence-pilot
date: 2026-06-25
approved_by: user (2026-06-25, "최적의 세팅으로 진행" — settings 확정 후 승인; staged GPU 게이트는 execute-plan이 단계별 확인)
requested: 2026-06-25
triggers_matched:
  - "SLURM/GPU submission (steered 재생성 + τ-RAMD egress, staged)"
  - "shared-storage writes (/mnt 출력)"
  - "4+ files (재생성 런처 + 수렴 채점 + RAMD force 모듈 + τ-RAMD 드라이버/스코어 + 리포트)"
  - "engine-adjacent (기존 flag-gated interface-steering 사용 — aigen-fold-core 엔진 영역 인접, overlay-mount로 소비·미커밋)"
references:
  - analysis/crl_integrative/tau_ramd_residence_pilot_results_20260625.md (선행 STOP@GATE-A, 이 컨트랙트의 직접 동기)
  - analysis/crl_integrative/residence_time_determinant_deepresearch_20260625.md (determinant 근거)
  - analysis/crl_integrative/glue_competence_results_20260623.md (orient=0 λ=16 → MRT6160 near-native 박제, degron 3/3 채점기)
  - analysis/crl_integrative/tau_ramd/stage0_clusters.tsv (S003 멤버·DC50)
---

# Steered-Regeneration → τ-RAMD Residence Pilot (option 1) — S003 congeneric subset

## Purpose / Hypothesis

선행 τ-RAMD pilot은 **GATE-A에서 STOP**했다: 143-set의 *unsteered* 생성 포즈(seed_pilot_20260415)는
VAV1-SH3c degron placement가 노이즈(같은 화합물 두 시드조차 median 14.6Å 불일치)라 residence 측정의
시작 구조로 부적합했다. 이 컨트랙트는 그 **한 가지 막힌 전제를 푼다**: 가설 = *"interface 스티어링
(orient=0 + 9NFR-앵커, λ=16)으로 S003 congeneric 서브셋을 *재생성*하면, 각 화합물이 시드-수렴된
near-native VAV1 placement를 얻어 τ-RAMD residence 모사가 가능해진다."*

**★중요한 reframe(설계를 가름)**: 우리는 화합물 간 *동일* 포즈를 원하지 않는다. 2026-06-25 박제가
glue별 offset은 *체계적*(MRT-23227 ≠ MRT6160)임을 보였다 — 이는 노이즈가 아니라 진짜 SAR이다.
따라서 steered 재생성의 목표는 **각 화합물을 *자기 고유의* near-native 모드로 시드-수렴**시키는 것이다.
residence ranking은 "모두 같은 자리"가 아니라 "각자 물리적으로 올바른 결합상태"를 요구한다.

**Diagnose-first**: orient=0 near-native 안정화는 현재 **N=1(타깃 글루 MRT6160)** 증거뿐이다. 따라서
*비-타깃 congeneric 화합물*에도 일반화되는지를 **소량 GPU로 먼저 검증**(Stage-0)하고, PASS여야만
전체 서브셋 + RAMD 툴링 + τ-RAMD에 GPU를 쓴다.

## Settings (finalized 2026-06-25 — evidence-based, zero-compute 검토)

- **probe 화합물 (4)**: `VAV1_101 · VAV1_126 · VAV1_132 · VAV1_125`. 선정 기준 = ① 클러스터 logDC50
  *최소*(VAV1_101 = 1.091, strong) & *최대*(VAV1_125 = 3.185, weak) 포함 → full span 2.09 커버,
  ② 내부 2점(VAV1_126 = 2.105 mid, VAV1_132 = 2.677 weak-mid), ③ **전부 best-of-seed
  crbn_target_iptm ≥ 0.78**(깨끗한 삼원 시작; iptm = 0.889/0.781/0.895/0.875). **저-iptm 멤버
  제외**(VAV1_105 = 0.345, VAV1_138 = 0.261 — 생성 품질이 교란되지 않게).
- **λ (interface-steering 강도)**: orient=0 **고정**. Stage-0가 **λ ∈ {8, 16} 브래킷** 스윕
  (16 = MRT6160 near-native 박제값[degron 3/3, ~4Å, 다중시드]; 8 = 계면 압력 절반 — over-fit/glue별
  차이 보존 검사). **Stage-1 채택 = 수렴+near-native를 만족하는 *최저* λ**(Occam: 최소 forcing =
  최소 over-fit). {8,16}이 애매하면 λ=12 1점 추가. (★카이랄 축의 λ 권고와 무관 — 여기는 placement 축.)
- **force 보정 범위 (τ-RAMD, Stage-3)**: 미는 대상 = **VAV1-SH3c COM**(받개서 egress). force 크기는
  τ-RAMD 본질상 *경험적 보정 필수*(문헌도 system별 튜닝). 초기 브래킷 = **{14, 19} kcal/mol/Å**
  (τ-RAMD canonical 14[Kokh 2018] 기준 + 단백질-도메인 drag 보정 상향 1점); 강/약 probe 시스템에
  스캔 → **bounded egress**(중앙값 ~0.1–2 ns, <50 ps[기전 파괴]도 timeout 초과도 아님)를 주는 크기
  채택; 둘 다 무경계면 브래킷 ±factor 확장. 재방향 stride = canonical(진행도 < ~0.2Å면 force 재방향).

## Scope (staged)

- **Stage-0 (소량 GPU — 첫 게이트)**: 위 probe 4개를 orient=0 + 9NFR-앵커 + interface 스티어링
  **λ∈{8,16} 브래킷** × multi-seed(~5)로 재생성 → 화합물별 ① 시드-수렴(pairwise SH3c Cα RMSD)
  ② near-native(degron-recovery, glue_competence) 채점. **게이트**. (셀 수 ≈ 4 probe × 2 λ × 5 seed = 40.)
- **Stage-1 (GPU, Stage-0 PASS 게이트)**: S003 전체(n=12) steered multi-seed 재생성 → 화합물별
  수렴 medoid 포즈 셋 확정(수렴+near-native 통과 멤버, 강/중/약 span 유지).
- **Stage-2 (구현 + CPU smoke)**: RAMD random-force를 OpenMM custom force로 구현(선행 plan의 미구현
  T3) — flag-gated 별도 모듈(엔진 미접촉).
- **Stage-3 (GPU, Stage-1+2 게이트)**: 수렴 S003 셋에 τ-RAMD egress(VAV1을 받개서 밀기), force-magnitude
  보정 + multi-replica → 상대 residence 순위.
- **Stage-4 (zero-GPU)**: *사전등록된* tier 분리 판정 + Spearman ρ(예측 residence, logDC50).

## Out of Scope

- 전체 교차-scaffold 143(예측 null — 의도적 배제). 절대 koff. prospective DC50 *예측*(거친 순위만).
- 습식 SPR(검증 금표준이나 실험팀 자원 — 별도 핸드오프).
- 신규 글루 설계, near-attack(촉매-기하) metric, 카이랄(별건).
- **엔진/생성 *코드* 변경**: 기존 flag-gated interface-steering을 overlay-mount로 *사용*만 한다.
  aigen-fold-core의 boltz_extension/diffusionv2 WIP 미접촉·미커밋(owner 조율, 선례 = glue_competence/
  chirality 세션).

## Success Criteria (staged, pre-registered)

- **Stage-0 PASS**: probe 화합물의 *과반*이 ① 시드-수렴(pairwise SH3c RMSD ≤ ~3Å) AND ② near-native
  (glue_competence degron-recovery PASS, SH3c-to-9NFR ≤ ~7Å). 검증: `stage0_regen_convergence.tsv`
  (compound·seed_pairwise_RMSD·degron_PASS·SH3c_to_9NFR). **FAIL=STOP**(문서화 음성: "steering이
  타깃 글루에만 일반화 — 비-타깃 congeneric 미수렴"). ★게이트는 화합물-간 *동일성*을 요구하지 않음
  (glue별 차이 보존이 정상).
- **Stage-1**: 수렴+near-native 통과 멤버 ≥8, logDC50 span ≥ ~1.5(강/중/약). 검증:
  `converged_subset.tsv`. (<8이면 STOP — 서브셋 부족.)
- **Stage-3 분별력 게이트**: 화합물별 egress 시간 ± 오차. dynamic range 있어야(서브셋 egress 중앙값
  spread > 단일-화합물 replica 분산; 또는 max/min ≥ ~2×). all-too-fast/무분별 → **STOP**(얕은-계면
  실패모드, 문서화).
- **Stage-4 tier 게이트(★Stage-3 결과 보기 전 동결)**: 강 tier(logDC50<X) 중앙 residence > 약
  tier(>Y), *예상 방향*. Spearman ρ 보고하되 게이트는 tier-분리(방향 + 비중첩/AUC). PASS=분리 /
  FAIL=무분리(→ residence-mimic 부적합, SPR deferral).

## Resource Budget (staged)

- **Stage-0**: 소량 GPU(probe 4 × λ 2 × seed ~5 ≈ **40 생성 셀**; 생성 빠름) — 추정 ~10~30 GPU-hr.
- **Stage-1**: S003 전체(12 × ~5 seed ≈ 60 셀) 생성 GPU.
- **Stage-2**: 구현 + CPU smoke(GPU 0).
- **Stage-3**: **τ-RAMD ~150~200 GPU-hr 상한**(수렴 ~8~12 × ~20 replica × force 2점).
- 인프라 = un-containerize + kim `--qos=batch` + free-GPU([[reference-slurm-free-gpu-selection]]),
  출력 /mnt 빈 브랜치(kfs2). SMILES = data/VAV1_Analy...lts_Part_1.csv(S003 12 매핑됨).

## Approval

- requested: 2026-06-25
- approved_by: pending. **단계별 GPU 게이트**: Stage-0(소량)이 *첫* 승인 지점 → PASS면 Stage-1 →
  Stage-2(구현) → Stage-3(대량) 각각 직전 단계 PASS 뒤. execute-plan이 각 SLURM 제출 전 확인.

## Rollback

- 모든 GPU 출력 = /mnt 빈 브랜치 → 삭제로 무해. SLURM 잡 취소 가능.
- 엔진/커밋 코드 변경 없음(스티어링은 기존 flag-gated; RAMD force는 flag-gated 별도 모듈).
- 어느 게이트서든 STOP = 정직한 음성으로 문서화. Stage-0/분별력 게이트가 대량 GPU를 조기 차단.

## Risks

- **R1 (Stage-0, 가장 가능성 있는 조기 종료)**: steering이 비-타깃 congeneric 화합물을 수렴시키지
  못함(N=1 = MRT6160만 검증). → option 1 종료, 문서화.
- **R2 (★over-fit 긴장, 설계 핵심)**: 9NFR-앵커는 *MRT-23227의 모드*다. S003 화합물을 9NFR로 *세게*
  당기면 그들의 고유 모드를 지우는 over-fit(우리가 경계해온 바). 완화 = 스티어링이 near-native
  *basin*만 제공하고 glue별 settling을 허용; Stage-0 게이트는 수렴+near-native만 요구(동일성 아님).
  앵커 강도(λ)가 too-hard면 Stage-0서 "전부 동일 포즈 붕괴"로 드러남 → λ 재조정 or STOP.
- **R3**: τ-RAMD force-magnitude·밀기 대상(VAV1 vs glue) 민감(per-system 튜닝); 순위는 robust하나
  binary보다 정확도 낮음.
- **R4 (천장)**: 통과해도 *거친 순위*(Weiss-class)지 prospective 예측 아님 — 세포 confounder가 상한.
  over-claim 금지. CRBN-글루 kinetics는 문헌상 미검증(우리 prior moderate-low).
- **R5**: 시작 삼원 = steered 생성 포즈(자체 불확실성) — τ-RAMD가 그 품질에 의존.
- **R6**: S003 한 클러스터 내 SAR이라 N·DC50 span 제한 — tier 분리 검정력 한계(사전등록으로 방어).

## Verification (Done When)

Stage-0 수렴 tsv + 게이트(PASS/STOP) → Stage-1 converged_subset.tsv(≥8) → Stage-2 RAMD smoke →
Stage-3 egress + 분별력 게이트(PASS/STOP) → Stage-4 사전등록 tier 판정(PASS/FAIL) → 결과 리포트
(`steered_regen_residence_pilot_results_*.md`, fks 미러). 어느 단계 STOP이든 *문서화된 음성*이 deliverable.

## Change Discipline

스티어링 = 기존 flag-gated(overlay-mount 소비, 미커밋·aigen-fold-core 조율 불요). RAMD force =
flag-gated 별도 모듈(엔진 미접촉). 사전등록(Stage-4 tier 정의)은 Stage-3 결과 전 동결.

## Progress Log

- 2026-06-25: /brainstorm. 선행 STOP@GATE-A(unsteered 노이즈)를 푸는 option 1. 사용자 결정 =
  **Diagnose-first(Stage-0 수렴 게이트 먼저)** + **S003(n=12)** 서브셋.
- 2026-06-25: 세팅 확정(evidence-based, zero-compute) — probe={101,126,132,125}(span 2.09, iptm≥0.78),
  λ∈{8,16} 브래킷(orient=0), force {14,19} kcal/mol/Å 경험적 보정(VAV1-SH3c COM push). 사용자
  "최적의 세팅으로 진행" → **status: approved**. 다음 = /write-plan(단계별 task 분해); Stage-0 GPU는
  execute-plan SLURM 게이트서 제출 직전 확인.
