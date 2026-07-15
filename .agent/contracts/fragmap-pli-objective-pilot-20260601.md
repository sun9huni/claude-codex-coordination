---
status: done
slice: fragmap
topic: pli-objective-pilot
date: 2026-06-01
owner: claude
approved_by: user (2026-06-01, "approved" via /brain → write-plan). NOTE: SLURM 제출은 별개 2차 게이트 — 각 sbatch 전 별도 "go" 필요.
result: "T1a KILL-by-diagnostic (zero-GPU; SLURM NEVER submitted, 사용자 결정 2026-06-01 'T1 닫고 T2/D3로'). Pre-submit baseline 진단이 premise를 깸: AB-corrected 포즈 5/5가 이미 near-native PLI (LDDT-PLI 0.878–0.931, ligand-RMSD <0.8Å, 전부 PASS vs 9NFR A1BYX 코어) → steering headroom 0. '99.8% PLI 실패'(무늬 1)는 blind/pre-AB 아티팩트였고 AB가 코어-PLI를 이미 풂. ★ near-native 포즈(placement 3.16Å + LDDT-PLI 0.92 + RMSD<0.8Å)인데 활성 null = category 문제 포즈 레벨 확인, GPU 0. 한계: 공유코어만 측정(per-analog 주변부는 held-out 구조 없이 비순환 측정 불가). diagnose-before-scaling이 ~1–2 GPU-hr 낭비 회피. 보고서 analysis/pli_objective_pilot_20260601/T1A_RESULTS.md. config oracle_gen_t1a_ligand_isolated.yaml + PINS.md는 향후 부활용 보존. 다음 = T2/D3 held-out 구조(유일한 비순환 경로). T1b 미진입."
triggers_matched:
  - "SLURM workflow script 신규 제출 (T1a + T1b 생성 런)"
  - "4개 파일 이상 (config + 가능한 stale-cache 소수정 + eval 스크립트 + report)"
  - "local↔shared 동시 (FK superset loader를 SLURM src/로 핀)"
program: .agent/plans/fragmap-leverage-program-20260601.md (T1)
result: "PENDING — pre-registered, staged T1a→T1b. PROVE/KILL 동결 (결과 보기 전, 사후 변경 금지)."
decisions:
  - 성격= PRE-REGISTERED, STAGED (diagnose-before-scaling). T1a 저비용 POC가 게이트; 통과해야만 T1b. 점수 보기 전 PROVE/KILL 동결.
  - 가설(무늬 1)= 6개월간 진짜 병목(LDDT-PLI 99.8% 실패, mixed_dominant_ligand_pose 409/413)을 **생성 목적함수로 만든 적 없음**. PLI/ligand-contact를 steering 목적으로 밀면 (T1a) 포즈 PLI가 오르는가, (T1b) 그게 out-of-scaffold 활성 순위를 끄는가? "구조→활성 실패 = 해상도 문제 vs category 문제"의 유일한 직접 반증.
  - 메커니즘 (정독 후 결정, 2026-06-01)= **(c) 기존 GlueprintPotential ligand-contact term 재사용 + 수정**. 근거(서브에이전트 정독): `potentials.py` GlueprintPotential `_ligand_face_energy`는 ligand 원자를 target VAV1 key-residue 접촉으로 끌고(exposure-gated) autograd-정확; potentials.py는 3 copy MD5 동일; GlueMap v1은 **DC50 ranking으로만** 평가됐고 **PLI로는 한 번도** 평가 안 됨(platform_state §L69) → T1 가설 미실행. 수정: ligand term 분리(`w_anchor=0, w_leak=0`)로 confound 제거 + `gd_weight` boost(norm-ratio라 0.3~1.5) + per-compound 인덱스 재빌드(`_glueprint_pot_cached` stale-cache 리스크) + SLURM src/ 핀.
  - PROVE/KILL — **T1a (POC 게이트, 사전 동결):**
    - 측정= 5 cpd × 3 seed, baseline(glueprint off) vs ligand-term-isolated(on). 지표= **LDDT-PLI 및 ligand-RMSD vs 9NFR crystal ligand pose** (contact-F1 to steered residues는 순환이라 금지; LDDT-PLI는 접촉 기하라 residue 근접만으론 보장 안 됨 = 덜 순환). 9NFR 참조 결합은 명시(held-out crystal은 T2/D3까지 부재).
    - PROVE = ligand-term-on이 LDDT-PLI를 올리거나 ligand-RMSD를 낮춤: median ΔLDDT-PLI ≥ +0.05 AND/OR median Δligand-RMSD ≤ −0.5 Å, 5 cpd 중 ≥3에서 같은 방향. → 병목(PLI)을 steering으로 움직일 수 있음 → T1b 진입 정당.
    - KILL = PLI 불변(위 미달). → steering이 중간변수조차 못 움직임 → **T1b 미실행, 저비용 종료.** "PLI는 현 steering으로 도달 불가" 기록.
  - PROVE/KILL — **T1b (활성, T1a PROVE 시에만, 사전 동결):**
    - 측정= 145-cpd 생성(ligand-term on) → DC50 보유분(n≈84~139)에 **T0 가드레일 전체 적용**: scaffold-blocked OOF Spearman(활성) + permutation null + MW/logP-partial + descriptors-only + power_preflight + proxy-audit 체크리스트.
    - PROVE = scaffold-blocked OOF가 permutation band 초과(p<0.05) AND MW/logP-partial 생존 AND descriptors-only 미재현. → **"category 문제" 반증** — PLI-최적 포즈가 활성을 예측 → 실제 PLI-목적 효과로 escalate(별도 대형 contract).
    - KILL = 활성 순위 여전히 null. → **"category 문제" 생성-목적 레벨 확정**(PLI는 올렸으나 활성 불응) = 가장 강한 음성 결과 → PLI를 활성 용도로 추적 종료; T2를 구조 검증(D3)으로 재조준.
  - 예측= 무늬 3·5상 T1b KILL 우세. 그래도 *옳은 변수 공략*이라 falsification 가치. T1a부터 KILL일 수도(그럼 더 저렴).
  - 게이트(정직)= 진짜 비순환 PLI 타당성은 held-out crystal(D3/T2) 필요. T1a는 9NFR-참조 feasibility(부분 결합); T1b 활성 순위는 DC50가 steering과 독립이라 활성 질문엔 비순환. 둘 다 한계 명시.
---

# PLI-as-objective pilot (T1) — staged confirm/kill of "PLI 병목을 생성 목적으로"

## Purpose

deep-insights 무늬 1: 진짜 병목(LDDT-PLI/ligand-pose fidelity)은 *생성 목적함수*로 한 번도
공략된 적 없다. 기존 GlueprintPotential ligand-contact term(GlueMap v1, DC50로만 평가됨)을
분리·부스트해 (T1a) PLI를 올릴 수 있는지, 그렇다면 (T1b) out-of-scaffold 활성 순위가 따라
오르는지 사전등록·단계화로 검증. "구조→활성 실패 = 해상도 vs category" 직접 반증.

## Current State

- 메커니즘 존재: `src/boltz_extension/steering/potentials.py` `GlueprintPotential` (3 copy MD5 동일);
  loader `interface_steering_utils.py` `_load_glueprint_config_from_biophysical_yaml` (FK copy=superset, gd_floor 포함).
- 활성화 config 존재: `configs/vav1_pipeline/oracle_generation_gluemap_strong.yaml`(gd_weight 0.3),
  `.../ablation_variants/oracle_gen_glueprint_boost.yaml`(gd_weight 1.5).
- SLURM src/ 3 copy(shared / FK repo / fragmap_surface_pilot mount) → **핀 필요**.
- T0 가드레일(`analysis/foundation/activity_eval_gates.py` + `docs/proxy_audit_preflight.md`) 사용 가능.
- 9NFR crystal ligand pose 참조 가용; held-out crystal 부재(T2/D3).

## Constraints

- allowed: 신규 config(ligand-term isolated, gd_weight boost) + per-compound 인덱스 재빌드 소수정(필요 시) + eval/report 스크립트를 repo에 git-track; T1a 출력은 scratch/out 디렉토리.
- forbidden: production ranking/weights 변경(진단, ranking-default 불변); GlueprintPotential 에너지 수식 변경(설정만); threshold 사후 변경; **승인 없는 SLURM 제출**.
- external: no-GT→activity-validator; per-compound metric(top-K 금지); 결과는 검출한계 bound.

## Non-Goals

- 실제 PLI-목적 production 효과 (T1b PROVE 시 별도 대형 contract).
- held-out crystal 확보(D3/T2).
- ranking 교체.

## Done When

- **T1a**: 5 cpd × 3 seed baseline vs ligand-isolated, LDDT-PLI + ligand-RMSD vs 9NFR 보고, PROVE/KILL 판정. KILL이면 종료.
- **T1b (T1a PROVE 시)**: 145-cpd 생성 + T0 가드레일 전체로 scaffold-blocked 활성 순위 + permutation/partial/descriptors/power_preflight + proxy-audit 통과, PROVE/KILL 판정(bound 형태).
- 스크립트·config·eval·report git-track; SLURM src/ 핀 기록.

## Approval Gates (STOP)

- **SLURM 제출(T1a, 그리고 T1b 별도)** = WORKFLOW §3 정지 게이트. 본 contract 승인 후에도 **각 제출 전 정확한 resource request와 함께 별도 "go" 필요**.
- T1a→T1b 전이 = T1a PROVE 판정 + 사용자 확인.

## Resource Budget

- T1a: ~1–2 GPU-hr (5 cpd × 3 seed). T1b: ~8 GPU-hr (145 cpd × seed). 코드 변경 최소(설정 위주 + stale-cache 소수정 가능).

## Rollback

- 진단 전용 — production ranking 미접촉. 출력은 scratch/out; 폐기로 복구. 코드 소수정 시 git revert.

## Verification

- T1a: baseline vs on의 ΔLDDT-PLI / Δligand-RMSD 표 + 사전등록 threshold 대비 판정.
- T1b: T0 가드레일 출력(OOF ρ, perm p, MW-partial, descriptors-only, power_preflight) + proxy-audit 체크리스트 통과.

## Progress Log

- 2026-06-01: spec 초안 (brainstorm, glueprint 정독 후 메커니즘 (c) 확정). 승인 대기.
