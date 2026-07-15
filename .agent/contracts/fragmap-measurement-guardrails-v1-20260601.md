---
status: done
slice: fragmap
topic: measurement-guardrails-v1
date: 2026-06-01
owner: claude
approved_by: user (2026-06-01, "Approve T0" via /brain → write-plan; appetite=데이터 확보까지 OK, 순서 T0→T1→T2)
triggers_matched:
  - "4개 파일 이상 수정 (라이브러리 + checklist doc + Charter A 수정 + smoke 확장)"
result: "DONE (2026-06-01). 8 tasks, 6 FKSFold commits (5be5ad2 mw_mediation_fraction, 1fc7acf within_between_scaffold, 394d238 power_preflight/n_needed, 75512a3 smoke, c35cd68 proxy_audit_preflight.md, 2c2978c foundation-doc link, c106991 Charter A relabel). 5무늬가 강제 가드레일로 박제됨. smoke 'SMOKE OK' (mediation/within-between/n_needed assertions). Plan: .agent/plans/fragmap-measurement-guardrails-v1-20260601.md. 실행 중 정직한 fix 2건: (a) within_between smoke가 degenerate data로 between_rho=nan → 비-degenerate 재설계; (b) power_preflight(0.30,84)=False(n_needed=85)는 off-by-one spec 기대값 오류, 함수는 scan min_rho(84)=0.301과 정합. T1(PLI pilot)·T2(데이터)는 program roadmap .agent/plans/fragmap-leverage-program-20260601.md대로 후속 contract."
decisions:
  - 성격= deep-insights 태피스트리 5개 무늬를 *일회성 발견*에서 *강제 가드레일*로 박제. 메타-메타(프록시↔타깃 단층선)가 조용히 재발하지 못하게. zero-compute.
  - 근거= docs/deep_insights_tapestry_20260601.md. 무늬 2(MW-매개/confidence=기하) → mw_mediation_fraction + confidence 재라벨; 무늬 4(KILL=within-scaffold SAR) → within_between_scaffold 분해; 무늬 5(검출바닥 n≈350) → power_preflight; 무늬 1+메타 → proxy-audit pre-flight 체크리스트; 무늬 3 → Charter A enclosure scope.
  - T1(PLI-as-objective pilot)·T2(데이터 확보)는 **별도 contract** (이 spec에 묶지 않음, skill: adjacent features → adjacent contracts).
---

# Measurement Guardrails v1 (T0) — 태피스트리 5무늬를 강제 게이트로

## Purpose

deep-insights 2차 채굴이 찾은 5개 무늬는 대부분 진단적이다. 이 변경은 그 진단을
**향후 모든 활성 주장이 통과해야 하는 재사용 가드레일**로 전환한다 — 그래서 "측정
가능한 프록시(MW score·confidence·in-sample ρ)를 최적화하고 실제 타깃을 회피"하는
6개월의 실수가 코드/리뷰 레벨에서 조용히 재발하지 못하게 한다. zero-compute.

## Current State

- `analysis/foundation/activity_eval_gates.py` (D1, 438줄) — scaffold GroupKFold OOF +
  permutation null + partial_spearman + descriptors_only + detection_limit_text 보유.
  단 (a) MW-매개 분율, (b) within/between-scaffold 분해, (c) power pre-flight은 **없음** —
  세 가지 모두 태피스트리에서 결정적이었는데 라이브러리에 미수록.
- `docs/platform_charter_A_20260601.md` — confidence를 명시적으로 "기하 타당성≠활성"으로
  라벨하지 않음; "enclosure not specific-recognition"(무늬 3) scope 미기재.
- proxy-audit pre-flight 체크리스트 부재 → 신규 실험이 프록시-타깃 분리를 선언할 강제 절차 없음.

## Assumptions And Questions

- 가정: 기존 frozen 테스트(multivariate/dmax/induced-fit)는 *역사적 기록*으로 불변; 가드레일은
  **향후 적용**이고 과거 KILL을 재계산하지 않는다.
- open: n≈350 floor는 |ρ|=0.15·80%·α.05 기준(Fisher z) — 다른 target |ρ|는 함수가 계산.
- tradeoff: 가드레일은 신규 활성 주장의 진입장벽을 높임 = 의도된 효과(diagnose-before-scaling).

## Constraints

- allowed: `analysis/foundation/activity_eval_gates.py`에 3개 순수함수 + smoke 확장 추가;
  `docs/proxy_audit_preflight.md` 신규; `docs/platform_charter_A_20260601.md` 수정;
  `docs/measurement_foundation_design_20260601.md`에서 신규 체크리스트 링크.
- forbidden: production ranking(vav1_ensemble_rank.py / oracle_ranking.yaml) 변경(ranking-default 불변);
  frozen 테스트 스크립트 수정; SLURM/GPU; shared workspace 쓰기; 새 외부 의존성.
- external: no-GT→activity-validator 규칙; per-compound metric(top-K 금지) — 체크리스트가 이를 강제.

## Non-Goals

- T1 PLI-as-objective pilot 실행 (별도 contract, gated).
- T2 external decoy / 비순환 held-out 데이터 확보 (별도 contract, 데이터/external).
- 과거 활성 테스트 소급 재계산 (기존 KILL 유지).
- production ranking·weights 변경 (가드레일은 진단 도구, ranking-default 불변).

## Done When

- `activity_eval_gates.py`에 다음 3함수 + 확장 smoke:
  - `mw_mediation_fraction(score, y, mw, logp)` → {raw_rho, partial_rho, mediated_fraction=1−|partial|/|raw|}.
  - `within_between_scaffold(metric, y, scaffolds)` → {within_rho(SAR), between_rho(generalizable), n_groups}.
  - `power_preflight(target_rho, n)` / `n_needed(target_rho)` → 80%·α.05 충분 여부 + n≈350(|ρ|=0.15) floor.
- `_smoke()`가 신규 함수 검증: (a) MW-구동 합성 데이터 → mediated_fraction 높음; (b) within-only 심은 신호 → between_rho≈0; (c) n_needed(0.15)≈347.
- `docs/proxy_audit_preflight.md` 1페이지: 모든 신규 활성 실험이 [프록시 / 실제 타깃 / 둘이 안 갈라진다는 증거 / 3-게이트 통과 / inert-knob 점검] 선언. measurement_foundation doc에서 링크.
- Charter A에 confidence 재라벨(무늬 2) + enclosure-scope(무늬 3) 2줄 추가.

## Implementation Steps

1. activity_eval_gates.py에 3함수 추가 (기존 _spearman/partial_spearman 재사용, 새 의존성 0).
   verify: `python -m compileall analysis/foundation/`
2. _smoke() 확장 — 3개 합성 assertion.
   verify: `python3 analysis/foundation/activity_eval_gates.py` → "SMOKE OK"
3. docs/proxy_audit_preflight.md 작성 + measurement_foundation doc 링크.
   verify: `grep -q proxy_audit_preflight docs/measurement_foundation_design_20260601.md`
4. Charter A 2줄 수정 (confidence 재라벨 + enclosure scope).
   verify: `grep -qiE 'enclosure|기하 타당성' docs/platform_charter_A_20260601.md`
5. surgical commit (FKSFold) + 본 contract status=done (workspace) + baton/handoff/index.
   verify: 양쪽 repo clean, 지정 경로만 staged.

## Change Discipline

- simplest adequate approach: 기존 라이브러리에 순수함수 3개 + 문서 2개. 새 추상화·의존성 0.
- unrelated code touched: 없음 (frozen 스크립트·ranking 불변).

## Verification

- `python3 analysis/foundation/activity_eval_gates.py` (SMOKE OK, 신규 assertion 포함)
- `python -m compileall analysis/foundation/`
- 체크리스트·Charter 링크 grep (위 step 3·4).

## Risks

- regression risk: 0 (순수 추가, 기존 API 불변, 새 의존성 없음).
- integration risk: 낮음 — 향후 실험이 import해 사용; 기존 호출부 변경 없음.

## Rollback

- revert strategy: 순수 additive → FKSFold 커밋 1개 git revert로 전부 제거. SLURM/`/mnt`/DB/ranking 미접촉이라 git revert로 완전 복구.
- containment strategy: 불필요 (외부 상태 변화 없음).

## Progress Log

- 2026-06-01: spec 초안 (brainstorm). 승인 대기.
