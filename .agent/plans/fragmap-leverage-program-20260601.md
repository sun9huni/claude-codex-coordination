---
program: measurement-leverage (tapestry 5무늬 활용)
slice: fragmap
status: active
sequencing: T0 → T1 → T2 (사용자 승인 2026-06-01, appetite=데이터 확보까지 OK)
basis: docs/deep_insights_tapestry_20260601.md
---

# Measurement-Leverage Program — T0→T2 로드맵

5개 태피스트리 무늬를 **활용**하는 3-tier 프로그램. 무늬들이 대부분 진단적이므로
레버리지 = ① 가드레일(재발 방지) → ② 결론을 *반증*할 단 하나의 실험 → ③ 천장을
깨는 데이터. 순차 실행, tier마다 별도 contract + 진입/종료 게이트 + 의사결정 지점.

> **관통 의존성:** T0의 가드레일(`power_preflight`·proxy-audit·`mw_mediation_fraction`·
> `within_between_scaffold`)은 **T1·T2가 사용**한다. T0가 먼저인 이유 = T1/T2의 측정을
> 신뢰 가능하게 만드는 측정 기반이기 때문. (D5/measurement-hygiene의 실행체.)

## Phase 개요

<table header-row="true">
	<tr><td>Tier</td><td>내용</td><td>무늬</td><td>compute/gate</td><td>contract</td></tr>
	<tr><td>**T0**</td><td>Measurement Guardrails v1 (라이브러리 3함수 + proxy-audit 체크리스트 + Charter A 수정)</td><td>2·3·4·5 + 메타</td><td>zero / 게이트 없음</td><td>fragmap-measurement-guardrails-v1-20260601 (approved)</td></tr>
	<tr><td>**T1**</td><td>PLI-as-objective pilot — PLI를 *생성 목적*에 넣어 "category 문제" 직접 반증</td><td>1 (+3 검증)</td><td>zero-GPU (제출 안 함)</td><td>✅ DONE = **KILL-by-diagnostic** (contract baa6594)</td></tr>
	<tr><td>**T2**</td><td>다양 chemotype + 비순환 held-out 확보 (D2 external decoy + D3 held-out crystal·HDX)</td><td>5 (+4 일반화)</td><td>데이터/external / contract</td><td>▶ **NOW** — T1 KILL → D3(구조 비순환) 우선 브랜치 활성</td></tr>
</table>

---

## T0 — Measurement Guardrails v1  ▶ NOW

- **상태:** contract approved. 실행 계획 = [`fragmap-measurement-guardrails-v1-20260601.md`](fragmap-measurement-guardrails-v1-20260601.md) (이 폴더).
- **진입 게이트:** 없음 (zero-compute, ranking 불변).
- **종료 게이트 (T1 진입 조건):** smoke "SMOKE OK"(신규 3 assertion 포함) + 가드레일 merge(FKSFold) + Charter A 수정 + proxy-audit 체크리스트 링크.
- **의사결정 지점:** 없음 — 순수 실행.

## T1 — PLI-as-objective pilot  ✅ DONE = KILL-by-diagnostic (2026-06-01)

> **결과:** zero-GPU pre-submit 진단이 premise를 깸 — AB-corrected 포즈 5/5가 이미
> near-native PLI (LDDT-PLI 0.88–0.93, ligand-RMSD <0.8Å). headroom 0 → SLURM 미제출.
> "99.8% PLI 실패"는 blind/pre-AB 아티팩트, AB가 코어-PLI를 이미 풂. ★ near-native 포즈인데
> 활성 null = category 문제 포즈 레벨 확인(GPU 0). 한계: 공유코어만 측정, per-analog 주변부는
> held-out 구조(D3) 없이 비순환 측정 불가 → **T2/D3가 유일한 전진로.** 보고서:
> [`../../FKSFold-Boltz_Advancement/analysis/pli_objective_pilot_20260601/T1A_RESULTS.md`](../../FKSFold-Boltz_Advancement/analysis/pli_objective_pilot_20260601/T1A_RESULTS.md).
> config/PINS는 held-out 확보 시 *재구성 부활*용 보존.

### (원래 설계 — 기록용)

- **왜:** 무늬 1 = 6개월간 진짜 병목(LDDT-PLI 99.8% 실패, right/wrong-basin)을 **생성 목적함수로 한 번도** 안 건드림. 이것이 "구조→활성" 실패가 *해상도 문제*인지 *category 문제*인지 가르는 **유일한 직접 반증 실험**.
- **진입 게이트:** T0 종료 + **신규 contract**(SLURM trigger) + 결과 보기 전 PROVE/KILL 동결(사전등록, induced-fit 테스트와 동일 규율).
- **설계 (사전등록 초안):** PLI/contact-fidelity를 soft constraint/목적항으로 넣어 145-cpd 생성 1런 → 산출 포즈의 (a) PLI 개선 여부, (b) **scaffold-blocked out-of-scaffold 활성 순위**가 T0의 `power_preflight` 하에 permutation band 초과하는지. proxy-audit 통과 필수.
- **의사결정 지점 (사전등록):**
  - **PROVE** (PLI-최적 포즈가 out-of-scaffold 활성을 perm-유의하게 예측) → "category 문제" 반증 → 실제 PLI-목적 효과로 escalate (별도 대형 contract).
  - **KILL** (예측 실패 / underpowered) → category 결론을 *생성-목적 레벨*에서 확정 → 활성 목적 추적 종료, T2를 **구조 검증(D3)** 쪽으로 재조준.
- **예측:** 무늬 3(enclosure≠recognition)·5(검출바닥)상 **KILL 우세**. 그래도 *옳은 변수를 공략*하므로 가치 있음(falsification).
- **비용:** ~8 GPU-hr pilot.

## T2 — 다양 chemotype + 비순환 held-out 확보  ▶ T1 결과 후

- **왜:** 무늬 5 = 현 코호트(VAV1 단독·congeneric·n 35~195)는 남은 효과(|ρ|<0.3)에 **2~10× underpowered**; 무늬 4 = 비-MW 신호조차 within-series. 천장 돌파 유일 경로 = **다양 chemotype/타깃** + 비순환 held-out.
- **진입 게이트:** **T1 결과가 무엇을 확보할지 결정** —
  - T1 KILL → **D3(구조 비순환 검증)** 우선: non-9NFR crystal 또는 HDX/XL-MS로 placement 주장을 독립 확증(활성 라벨 추가는 무의미).
  - T1 PROVE → **powered 활성 패널** 우선: n≈350(T0 `power_preflight`) scaffold-다양 DC50 코호트.
- **하위 항목:** D2 external property-matched decoy(~50–100, VAV1 밖 chemotype) + D3 held-out(crystal/HDX·XL-MS).
- **의사결정 지점:** **target/assay 식별** — 적합한 비순환 타깃 없으면 *대기*(measurement_foundation D3 게이트 유지).
- **비용:** 데이터 확보(external) + contract. (appetite OK 확인됨.)

---

## 의존성 그래프

```
T0 (가드레일, zero) ──┬─▶ T1 (PLI pilot, ~8 GPU-hr)
   power_preflight    │      │
   proxy-audit        │      ├─ PROVE ─▶ T2: powered 활성 패널(n≈350)
   mw_mediation       │      └─ KILL  ─▶ T2: D3 구조 비순환 검증
   within_between ────┴──────────────────▶ (T1·T2 전부 T0 가드레일 사용)
```

## 프로그램 종료 기준 (success)

- T0: 5무늬가 강제 가드레일로 박제 — 프록시-타깃 실수 재발이 코드/리뷰에서 차단됨.
- T1: "category vs 해상도" 질문이 생성-목적 레벨에서 **판정**(PROVE/KILL 둘 다 가치).
- T2: placement 주장이 **비순환·powered**하게 확증되거나, 그 부재가 명시 기록.

> 한 번에 하나의 contract+plan. T1·T2 contract는 직전 tier 종료 게이트 통과 후 /brain으로 작성.
