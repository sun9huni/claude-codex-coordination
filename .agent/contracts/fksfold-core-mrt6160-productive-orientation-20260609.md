# fksfold-core-mrt6160-productive-orientation — MRT6160 productive 방향 파이프라인

- **Status**: approved
- **Approval**: requested 2026-06-09 · approved by: user (2026-06-09 "승인")
- **Slice**: fksfold-core
- **독립성**: 이 계약은 **독립 워크스트림**이다. M-RELATIVITY(committor q(x)·TPT·W₃·QPE,
  슬라이스 `m-relativity`, 다른 agent)와 **무관** — 그쪽 산출물·개념(committor/양자/kinetics)을 쓰지도
  넘기지도 않는다. (이전 `fksfold-core-productive-pose-protocol-20260608`은 M-RELATIVITY Phase 0로
  conflate된 프레임이었고 done으로 종결됨. 그 lever-arm 결과만 **입력 근거**로 인용한다.)

## Purpose

MRT6160의 **productive ubiquitination 방향(orientation)**을 다음 3단계로 산출한다:

1. **방향 스캔** = 기존 MRT6160 multi-seed pose(1차 arm) **+** 2C(forced-template 회전-target
   steering)로 방향 grid를 따라 강제한 **2차 생성**(GPU).
2. **기능 지표 M1로 선택** = 완전복합체 overlay 위에서 측정한 **best SH3-lysine Nζ → E2 촉매 Cys 거리
   (graded)** 가 가장 productive한 방향을 MRT6160의 productive orientation으로 고른다. **SH3 lysine 5개
   (K788/804/810/814/815)만**, distal lysine 배제(아래 근거).
3. **그 구조 surface 분석** = 선택된 productive 구조의 surface 산출물(정의 = 사용자 게이트, 아래 §Surface).

## 입력 (전부 실측 확인 2026-06-09)

- **1A config** (생성 기반): `…/FKSFold-Boltz_Advancement_shared/examples/9nfr/9nfr_mrt6160_vav1_14_19.yaml`
  (SHARED 마운트; 로컬 트리엔 없음 → fragmap prep 선례처럼 stage-copy 필요). Chain A=CRBN(pocket
  305–355, glutarimide anchor 포함), B=VAV1-SH3(pocket 14–19), C=MRT6160. **FragMap target_occupancy**는
  별도 conditioning config(`configs/vav1_pipeline/fragmap_conditioning_target_t1_r10*.yaml`)로 런타임 주입
  (λ=20 / npart=8 production 레시피).
- **완전구조 입력**: full-length VAV1 = `analysis/productive_pose/refs/AF-P15498-F1.pdb`(AF DB v6, mean
  pLDDT 86.4). CRL4 scaffold = PDB **2HYE**(DDB1–CUL4A–RBX1; 원안 3LRQ는 TRIM37 오기였음, 2026-06-09 정정)
  + E2\~Ub = PDB **6TTU**(CRL1–UBE2D2~Ub, 촉매 CYS D85). CRL1→CRL4는 공유 RBX1 RING으로 graft.
- **보정 앵커**: `best_structures/9NFR_reference.cif`(DDB1+CRBN+VAV1-SH3, 결정 리간드 mrt23227/CCD A1BYX).
- **방향 스캔 1차 arm**: 기존 MRT6160 multi-seed pose(`outputs/mrt6160_100seeds*`, `mrt6160_multi_seed*`).
- **근거(인용)**: `analysis/productive_pose/PHASE0_RESULTS.md` — lever-arm 진단. distal lysine(레버암
  30–100Å)은 docking 오차를 수십 Å로 증폭 → **현 docking 정확도에서 무의미 → distal 배제, SH3-5만**.
  SH3도 docking >~30° 오차면 신호 삼킴 → **2C로 방향을 조이는 것이 이 파이프라인의 핵심 이유**.
- **링커 lysine 배제(메커니즘 정합성 검증 2026-06-09)**: degradation 메커니즘은 ubiquitination 표적을
  "SH3 fold lysine **또는** SH3 직전 링커 lysine"으로 명시함. 실측 매핑 결과 C-SH3 인접 노출 lysine =
  K766/K770(링커, full VAV1) + K782(경계) + K788/804/810/814/815(SH3 fold). **M1은 SH3 fold 5개만 사용** —
  링커 K766/K770은 노출돼 있으나 SH3 pivot에서 **34.8/47.0Å(distal급 레버암)** + flexible(pLDDT 60/—) →
  rigid-overlay 단일 거리로는 신뢰성 없음(distal 배제와 동일 논리). 단 생물학적으로는 유효 표적일 수 있어,
  **링커 lysine의 도달성은 Stage 4 swept-volume에서 정성적으로 포착**(단일 거리 대신 부피). M1 5개는 전부
  근접(10.6–17.5Å) + 고신뢰(pLDDT 80–93) + 노출 = 신뢰성 있는 유일한 집합. 생성 construct(chain B =
  full VAV1 782–842)도 링커를 안 포함 — 의도된 경계.

## 2C 엔진 작업 (실측 기반 — config-only 아님)

- **존재**: `TemplateReferencePotential`(potentials.py:586) + 레지스트리(group `"template"`).
- **갭(확인)**: 그것이 읽는 `template_cb[template_force]` / `template_force_threshold`(potentials.py:595,
  588–626)의 **생산자가 src 전체에 0개** → 지금 켜도 no-op. `template_cb` 생산자도 로컬 editable 트리에
  없음(baked/별도).
- **경로(결정)**: fragmap steering 선례와 동일하게 **`boltz_extension` steering 레이어(mounted/editable)에서
  feats를 주입** — baked core featurizer 미접촉. steering-config 블록에서 (회전 full-complex template CIF +
  "chain B를 template 방향으로 X Å 안에 force") → `template_cb`/`template_force`(bool mask)/
  `template_force_threshold`를 생성해 `TemplateReferencePotential`이 읽기 전에 feats에 넣고, guidance group
  `template`을 활성화. **ADDITIVE** — 기존 interface/fragmap steering 미변경.
- **검증(필수, GATE)**: 풀 스캔 전 1-seed smoke로 forced-restraint가 실제로 chain B를 target 방향으로 당기는지
  (로그의 template 활성 + unsteered 대비 측정 가능한 Δorientation) 확인. (diagnose-before-scale)

## Scope

- engine: `boltz_extension` steering 레이어에 2C forced-template feat 주입 + guidance 활성화(additive).
- overlay: full-length VAV1 + CRL4A–RBX1–E2\~Ub 완전복합체 통합 overlay 스크립트(앵커 RMSD<2Å).
- metric: M1 graded scorer(SH3-5 lysine→E2 Cys, orthogonal: steered residue 미사용) + 기존 multi-seed
  소급 적용.
- data: E2\~Ub / CRL frame 다운로드 + 가장 적합한 것 선정.
- generation: 1A config + 2C steering으로 **방향-grid 2차 생성 (SLURM/GPU)**.
- select: 생성 pose를 M1로 채점 → productive orientation 선택.
- surface: 선택 구조 surface 분석(산출물 정의 = §Surface 게이트).

## Out of scope

- **M-RELATIVITY committor / TPT / 양자(R·Q·W₃·QPE) / kinetics = 다른 agent. 미접촉.**
- **distal lysine**(레버암상 배제) · DC50/활성 순위 예측 · PROTAC.
- 기존 production baseline/interface/fragmap steering 의미 변경(2C는 additive 신규 경로일 뿐).
- FragMap `ternary_r*_maps.npz` 재freeze(HARD RULE 유지).

## Surface 산출물 (Decision 4 — 동결 2026-06-09)

**= E2\~Ub 도달성 cone/swept-volume.** 선택된 productive 구조의 완전복합체 overlay 위에서, SH3-5 lysine
Nζ가 E2 촉매 Cys Sγ를 향해 도달 가능한 **부피/원뿔(swept-volume)** 을 산출한다 — M1(스칼라 거리)의 공간적
확장으로, productive 방향의 *기능적 의미*(ubiquitin transfer 기하 도달성)를 surface로 시각화. 도달 가능
fraction + E2 active site와의 overlap을 정량. (다른 후보 — lysine SASA / interface 보존 / 정전기·소수성 —
는 채택하지 않음.)

## Triggers matched

- **SLURM GPU 제출**(Stage 3 방향-grid 2차 생성) → **이 계약이 그 sbatch를 authorize**.
- engine(steering) 코드 변경(boltz_extension) + 외부 다운로드(RCSB/AlphaFold) + /mnt 쓰기 + 4+ files.

## Success criteria

1. **overlay 재현**: full VAV1→pose SH3(chain B) + CRL–E2\~Ub→pose CRBN(chain A), 9NFR 앵커 RMSD<2Å.
   `python complete_structure.py --pose <one>` → 완성 PDB + RMSD 로그 + E2 촉매 Cys 좌표 존재.
2. **M1 동작 + 소급**: `python m1_score.py` → 기존 multi-seed pose별 M1 값 + 9NFR/mrt23227 crystal NULL band.
   orthogonality 단언(steered residue 미참조).
3. **2C 활성 검증(GATE)**: 1-seed smoke 로그에 forced-template 활성 + unsteered 대비 Δorientation 측정.
4. **방향 스캔 생성**: 1A+2C로 방향-grid 생성 완료(SLURM), pose별 M1 점수 + **선택된 productive orientation**.
5. **surface**: 선택 구조의 **E2\~Ub 도달성 cone/swept-volume** + 도달 fraction + E2 active site overlap.

## Resource budget

- Stage 0–2(overlay·E2·M1 소급·2C 코드) = **zero/minimal GPU**. 2C smoke = 1-seed 최소 GPU.
- Stage 3(방향-grid 2차 생성) = **GPU/SLURM** — GPU는 풍부하니 방향 grid×seed를 넉넉히(diagnose 후 generous).
- 2C smoke(GATE) 통과 전 풀 GPU 스캔 금지.

## Constraints

- **HARD: pre-registration** — M1 정의 + 방향 grid + 선택 규칙 + NULL band를 **생성 전 동결**(사후 튜닝 차단).
  PREREGISTRATION 완료 시 **사용자 체크포인트**(일시정지·검토).
- **HARD: 2C ADDITIVE** — 기존 steering 의미 미변경. smoke GATE 통과 전 풀 스캔 금지.
- **HARD: SH3-5 only** — distal lysine 배제(lever-arm 근거).
- 외부 다운로드는 출처·버전 기록(refs/README).
- fksfold-core 트리는 다수 dirty entry → **신규 파일만 surgical commit**(기존 dirty entry 미접촉).

## Rollback

- Stage 0–2: 신규 스크립트/refs 삭제 + 2C feat 주입 revert(additive라 기존 경로 무영향).
- Stage 3: 생성 출력 디렉토리 삭제(production 모델/baseline 미변경).
- 다른 agent/슬라이스 산출물 미접촉.

## Progress Log

- 2026-06-09: 기존 Phase-0(M-RELATIVITY conflate) 프레임에서 **독립 productive-방향 파이프라인**으로 재작성.
  설계 잠금(사용자): 1A config / 2C forced-template orientation steering / M1·SH3-5 / E2 다운로드-선정 /
  완전복합체 overlay / surface=미정 게이트 / GPU(zero-GPU 아님). 자산·배선 실측 확인 후 작성.
- 2026-06-12: Tasks 1–7 done(엔진 2C 배선 commit) + Task 8 smoke GATE 통과. **2C 메커니즘 검증**
  (target=0 4seed 125°→~23°). 인프라 4버그 수정. 밀집 스캔(p45/p60/p75×16seed): rigid-M1 ~24–26Å
  **바닥** — 방향만으론 못 뚫음. **AMENDMENT(PI 사인오프): M1=상대 ranker, productive judge=swept-volume
  도달성(Stage4 앞당김).** ▶NEXT: swept-volume judge 구현(상위 후보 θ_obs54/73/78). 상세 = plan 상단
  SESSION HANDOFF. ⚠️ fksfold-core slice baton은 타 세션(89d90310) 점유 → 본 contract/plan이 durable 기록.
