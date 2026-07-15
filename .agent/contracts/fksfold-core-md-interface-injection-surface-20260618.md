---
status: done
slice: aigen-fold-core
topic: md-interface-injection-surface
date: 2026-06-18
owner: claude
approved_by: user (2026-06-18, "승인")
triggers_matched:
  - "SLURM/GPU evaluation run (채널별 1-cell smoke 발화 검증 — np1 단발 다수)"
---

# MD-interface injection surface — 유비퀴틴 MD best pose의 CRBN↔VAV1 계면을 *엔진이 먹는 데이터*로 전수 추출·발화검증

## 동기 / Purpose
사용자 아이디어: 유비퀴틴화 MD best pose의 CRBN–MRT6160–VAV1 productive 계면을 AIGEN-Fold의
conditioning/steering 파라미터에 주입 = 결정구조 없는 VAV1용 *물리(MD)-유래* 구조 prior. 이 컨트랙트의
질문은 **"같은 자리냐(순환성)"가 아니라 "이 계면을 엔진이 실제로 *먹는 데이터*로 만들 수 있나"** 다.
**"받는다 ≠ 쓴다"**(biophysical_hybrid가 gate≈0로 물리항 죽고, w400이 잔기 비면 silent no-op이던 전례)이므로,
각 채널을 *추출 → 인코딩 → 1셀 smoke 발화확인*까지 닫는다.

★**과학적 동기(핵심):** 우리 측정(commit 5b76800)에서 MRT-ternary vs 9UUM CRBN 포켓 = **backbone 보존
(1.4Å)인데 Y355 plastic(4.66Å)·glue 6Å/35° 차이**. 즉 활성 포켓의 정보는 *backbone/잔기 identity가 아니라
사이드체인·glue 포즈*에 있다 → **잔기-수준 pocket contact(#1)은 그 알맹이를 놓친다.** 활성-포켓 채널
(#2 원자접촉·#3 사이드체인·#5 glue 포즈·#4 template)이 우선이다.

## Scope (이번 컨트랙트가 하는 것)
vav1-ubq CRL integrative MD(`crl_integrative_md_metad/`, job 7207)의 **best pose(생산기하 near-attack
프레임)** 에서 — **읽기 전용** — CRBN↔VAV1 계면을 아래 **12채널 전수**(선언적 #1–11 + 수식/potential #12)로
추출하고, 각 채널을 엔진 스키마로 인코딩한 뒤 1셀 smoke로 *발화*를 확인한다.

★**scope 확장(2026-06-18, 사용자 "플랜 개정"):** T3 API 감사 결과 선언적 입력으론 #2(원자 contact)·#5(glue
포즈) 미지원·#3(사이드체인) template-CB 경유만. 그러나 *guidance 층은 좌표에 대한 수식*이므로 그 payload를
**#12 = MD-reference restraint potential**(flat-bottom 항)로 주입 가능 → #2·#3·#5는 "미지원 SKIP"이 아니라
"#12 경유"로 재분류. #12는 **엔진 src에 신규 potential 1개**(default-off flag) 추가 = 본 컨트랙트의 "신규 코드"
경계가 analysis/ 스크립트에서 *엔진 src 1 potential*까지 확장됨.

입력단(conditioning):
- **#1 잔기 접촉쌍** → `pocket: contacts [[B,res]]` (contact_conditioning). [최저 해상도]
- **#2 중요 상호 *원자*쌍 + 거리** → `contact: token1/token2 + max_distance` (원자 수준). ★활성
- **#3 CRBN 활성 포켓 사이드체인**(Y355·tri-Trp W380/386/400·H378) → 원자 restraint/rotamer 고정. ★핵심 변화
- **#4 CRBN 활성형 통째** → structural **template**(CIF) 입력. (backbone만 → #3와 병용)
- **#5 glue(MRT6160) 결합 포즈** → ligand template/contact 앵커. ★(glue가 포켓 모양의 일부)
- **#6 w400 패치** → w400_conditioning(additive). [#1의 특수case]

steering단(objective/guidance):
- **#7 면별 interface 잔기** → key_residues_A / target_key_residues. (OOD 경로 비활성 → 켜야)
- **#8 특정 i–j 원자 거리** → w_dist 항. (죽은 레버 w_dist_eff=0 → 살리면 원자 상호작용 직접 주입)
- **#9 정전기 쌍** → w_elec. [미약]
- **#10 계면 충돌/부피** → interface_gd physical potential(현 ligand_volume+clash, 확장).
- **#11 계면 density/포켓 shape** → NPZ map(fragmap/SILCS steering). [수식 경로-A, 코드無·config만]

수식/potential단(#2·#3·#5의 payload 주입):
- **#12 MD-reference restraint potential** → 엔진 src 신규 potential(flat-bottom). 원자쌍 거리 restraint
  Σ[max(0,|rᵢ−rⱼ|−d^MD_ij−δ)]²(#2) + 사이드체인 원자 위치 restraint(#3, CRBN-frame) + glue 원자 위치
  restraint(#5)을 interface_gd 루프에 wire. iPTM 미분 안 함 = 비순환(리포트 P2). **default-off flag**.

## Out of scope (인접하나 이번엔 안 함)
- **주입이 VAV1 예측을 *개선*하나** 측정 — 별개 후속(이건 "데이터로 쓸 수 있나"의 선결만).
- **순환성/"Boltz와 같은 자리냐"** 판정 — 사용자 지시로 제외(하류 검증의 몫).
- VAV1 예측의 **정확성 주장**(GT 없음).
- vav1-ubq baton·MD 산출 **편집**(읽기 전용; best pose 프레임도 그쪽 지정분 사용).
- 채널 **튜닝/최적화**(어느 weight가 최선인지) — 발화 확인까지만.

## Success criteria (Done When)
산출 = (a) **주입면 인벤토리 표** — 11채널 × {엔진 API 지원? / MD pose서 추출됨? / 스키마 인코딩됨? / 1셀
smoke *발화* PASS·FAIL(로그 근거)} ; (b) 추출된 **주입 가능 데이터 산출물**(contacts·atom-contacts·
sidechain restraints·CRBN/​glue template CIF·key_residues·w_dist 거리표·NPZ 등 실제 파일) ; (c) 활성-포켓
채널(#2·#3·#4·#5)의 발화 PASS 여부 명시.
- 리포트: `analysis/heldout_placement_20260601/reports_crystalfree_router/md_injection_surface_20260618.md`.
- 발화 판정 = smoke 로그에 해당 constraint/steering이 active로 찍히고 silent no-op 아님(fragmap SMOKE 게이트
  방식 준용). API 미지원 채널은 "미지원"으로 정직 표기(추정 금지).
- 검증 커맨드: 위 리포트 + 채널별 산출물 존재 + 인벤토리 표의 발화열 채워짐.

## Resource budget
- **추출/인코딩 = zero-compute**(MD pose·구조 읽기 + gemmi 접촉/거리/정렬; CIF·YAML 생성).
- **smoke 발화 검증 = 소량 SLURM**: 채널당 1셀, np1, sampling_steps 소(예 10), diffusion 1 → "발화하나"만
  확인(품질 무관). 총 ≲1 GPU-hr. 엔진 API 지원 여부 확인 포함(atom `contact`·`template`·w_dist 활성화).
- 신규 코드 = 추출 스크립트 + 리포트(repo `analysis/`) **+ #12 엔진 src potential 1개**(`src/boltz_extension/steering/`,
  default-off flag, /code-review 경유); smoke 입력은 workspace(삭제 가능).

## Rollback
- 분석/추출 산출은 repo/scratch → `git revert`/삭제(외부 상태 무변).
- smoke SLURM은 `scancel` + workspace 출력 dir 삭제(/mnt 공유 쓰기 없음).

## Risks / 주의
- **silent no-op**: "받는다≠쓴다" — 이 게이트의 존재 이유. 발화 로그 없으면 FAIL 처리.
- **API 미지원 가능성**: 우리 Boltz 빌드가 atom-level `contact`·`template`·w_dist를 실제 지원/활성하는지 미확인
  → smoke로 확인, 미지원은 정직 표기(채널 일부는 "추출은 되나 주입 불가"로 끝날 수 있음).
- **construct/넘버링 reconcile**: MD CRBN(truncated build, W355=full W400 offset 45) vs Boltz 입력 시퀀스
  잔기번호 불일치 → 추출 전 매핑. glue/사이드체인 원자명도 정합 확인.
- **best pose 정의**: 단일 near-attack 프레임 1차 사용; MD 궤적상 계면 안정성은 부수 확인(흔들리면 "그 계면"
  ill-defined).
- **cross-slice**: MD 산출 vav1-ubq 소유 → 읽기 전용, baton 미수정.
- **#12 엔진 src 편집 리스크**: 신규 potential이 기존 generation 동작을 바꾸면 안 됨 → **default-off flag**(미지정 시 경로 미진입), /code-review로 surgical 확인. rollback = src `git revert` + flag off(프로덕션 동작 무변).

## Notes (done 2026-06-18)
plan v2 T1–T16 완료. **결론: MD best-pose 계면 = 주입가능 데이터로 입증 + #12 MD-reference potential 풀파이프라인 발화 검증**(job 7963 COMPLETED: indices 219 atom_pairs/101 frame CA CRBN-aligned/89 pos, first call E=298554 grad_ok=True, model_0.pdb 산출). 커밋 1a0ec1f(API감사)·8c5cdd7(추출+인코딩)·0da83d9+04abc6a(#12 potential+inference-mode fix)·8faa751(spec+리포트). 리포트 `reports_crystalfree_router/md_injection_surface_20260618.md`. ★smoke가 단위테스트 미검출 통합버그 2건(world-frame fallback·inference-tensor backward) 적발. **미해결**: (a)#12 wiring 4파일 미커밋(pre-existing glueprint/inference WIP+ruff 얽힘, 기능은 staged 사본으로 입증), (b)"주입이 placement를 개선하나"=별도 후속 컨트랙트(out of scope), (c)glue pos restraints 원자명 재매핑 필요.
