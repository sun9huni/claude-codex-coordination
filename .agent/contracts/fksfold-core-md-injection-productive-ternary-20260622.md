---
status: done
slice: aigen-fold-core
topic: md-injection-productive-ternary
date: 2026-06-22
owner: claude
approved_by: user (2026-06-22, "승인")
requested: 2026-06-22
verdict: "FAIL (method-negative, robust) — #12 binding-interface injection does NOT improve productive VAV1 ternary generation (0/13 improve, meanΔ-0.0096, K810-emergent 0/13; holds under rigid AND corrected flexible metric). BUT 'generation can't make productive geometry' is FALSE: rigid metric was artifact, ~40% productive-achievable under a flexible CRL arm; #12 just isn't the lever. True near-attack(≤3.5Å) is a rare dynamic state → productive verdict belongs to MD layer (vav1-ubq 8098). target lysine K810 = best geometric hypothesis (dominant-reachable 63%, no MS). Report: analysis/crl_integrative/md_injection_productive_ternary_results_20260622.md"
cross_slice:
  - "vav1-ubq (read-only): productive-geometry discriminator(4축) + MD prior + 실제 degrader 패널 소비"
triggers_matched:
  - "SLURM/GPU submission — paired #12 on/off Boltz generation + MD relaxation + 물리 discriminator 채점"
  - "shared-storage writes — /mnt 워크스페이스 생성 출력·MD"
  - "4+ files / 신규 코드 — 페어드 런처 + emergent-geometry/stability 채점 + (필요 시) #12 엔진 src wiring"
supersedes:
  - "fksfold-core-md-injection-placement-rescue (OOD DockQ rescue endpoint = 목표와 다름, 폐기)"
  - "fksfold-core-md-injection-vav1-productive-separation (active/inactive 활성 판별 endpoint = 목표 아님, 폐기)"
---

# MD-injection productive-ternary — "#12 MD-주입이 *productive* 삼원복합체를 올바르게 예측하게 하나" (물리, no crystal, 활성판별 아님)

## Purpose

선행 plan `md-interface-injection-surface`(done)는 #12 MD-reference potential이 **발화**함만 보였다(링크 1).
이 컨트랙트의 질문은 **"#12 주입이 *productive* VAV1 삼원복합체를 *올바르게 예측*하게 하나"** 다.

★**"올바름"의 정의(사용자 확정):** crystal 대비 DockQ가 *아니고*, active/inactive *판별*도 *아니다*. **productive
ubiquitination 기하** — 기질 라이신이 E2~Ub 전달에 맞게 놓였나(near-attack 도달·clash-free·register·삼원유지,
vav1-ubq 판별기 4축) = *기능적으로* 올바른 ternary. 물리로만 판정, 외부 crystal GT 없음.

★**활성 데이터의 역할 = 필터, 판별 아님:** 활성 degrader는 *실제로 productive ternary를 이루는* 진짜 분자다(그래서
작동한다). 그 진짜 분자들에서 "#12가 올바른 productive ternary를 예측하게 하나"를 본다. **활성 순위/판별은 안 한다**
(그 레인은 KILL됨).

근본 동기: VAV1엔 crystal이 없어 productive ternary를 직접 검증 못 한다. baseline 엔진은 productive 기하를
잘 못 만든다(static graft 스크린: 닿음+clash-free 동시 불가 → productive≈0). **#12(MD-유래 productive 계면
prior)가 그 갭을 메우나** — 이게 crystal-free VAV1 placement의 핵심 베팅.

## Current State

- **#12 potential** `MDReferenceRestraintPotential`: 원자쌍거리(#2)+사이드체인(#3)+glue(#5) flat-bottom
  restraint, default-off flag. 발화 입증. wiring 4파일 미커밋(WIP 얽힘) → overlay-mount staged 소비 가능.
- **vav1-ubq 자산(읽기 전용)**: productive-geometry discriminator(`crl_confirm_glue.py` topology-aware,
  4축 = near-attack·clash·register·삼원유지), MD prior(`crl_frame...nearattack.pdb` 류 productive 프레임),
  실제 degrader 패널(`configs/vav1_pipeline/normtest_metadata.csv`, 144 활성 degrader = 필터용).
- **baseline 음성(=헤드룸)**: static graft 스크린(`glue8-productive-screen`)은 productive≈0(닿음+clash-free
  동시 불가). → baseline 엔진이 productive 기하를 못 만든다 = 개선 여지 있음.
- **9NFR**: VAV1 crystal 있으나 (a) binding pose(productive 기하 아님), (b) 엔진이 이미 DockQ~0.84(헤드룸 無),
  (c) MD prior가 9NFR-유래(순환) → **올바름의 reference 아님**(사용자: productive 기하로 판정). 보조 sanity로만 가능.

## Assumptions And Questions

- assumptions:
  - 페어드(같은 seed·config, 차이는 #12 on/off뿐)가 교란 제거.
  - 실제 degrader엔 *올바른* productive ternary가 존재(작동하므로) → 회복 대상이 있다.
- open questions (→ /write-plan 사전등록 freeze):
  - **테스트 degrader 집합**: 컨트롤(MRT6160) + 실제 degrader 패널 부분집합 N(필터: 진짜 active, MW/logP 다양).
  - **#12 주입 분해**: anti-circularity 위해 어느 항까지 주입하고 어느 기하를 *emergent*로 둘지(아래 가드).
  - 판별기 4축 productive 컷·stability(relax-survival/multi-seed) 정의.
  - 선결: baseline productive≈0가 이 generation 셋업에서도 재현되나(vav1-ubq job 8098/스크린 교차확인).

## Constraints

- allowed change scope: `analysis/crl_integrative/` 신규(페어드 런처·emergent/stability 채점·사전등록 잠금);
  SLURM 런처(paired Boltz gen + MD relax + 채점); /mnt 출력; (필요 시) #12 wiring 분리 커밋(아니면 overlay).
- forbidden change scope: vav1-ubq MD/discriminator/baton 편집(읽기 전용); #12 default 동작 변경; crystal을
  reference/주입에 사용(올바름은 productive 기하로만).
- external constraints: GPU(paired gen + relax + 채점); boltz-predict=ubuntu docker 또는 un-containerize.

## Non-Goals

- **활성/효능 판별·순위** — 목표 아님(KILL된 레인). 활성 데이터는 *진짜 degrader 선택 필터*로만.
- **crystal/DockQ 올바름** — 사용자 확정: productive 기하로 판정(crystal 대비 아님). 9NFR은 보조 sanity 한정.
- **#12 weight 최적화** — 1차 고정 default.
- **신규 글루 g1–g6 적용** — 별도 독립 task(vav1-ubq workstream).

## Done When

**선결(precondition):**
- baseline(#12-off) 엔진이 이 셋업에서 productive 기하를 *못* 만든다(productive yield≈0/저조) — 헤드룸 확인.
  안 그러면(이미 productive) 개선 여지 없음 → 재설계.

**Primary endpoint(사전등록):**
- 사전등록 잠금(degrader 집합·seed·#12 주입항·productive 컷·emergent 정의·stability 정의·margin)이
  treatment *전* 커밋.
- 실제 degrader에서 **페어드** (#12 off / on, 그 외 동일) 생성 + discriminator 채점 완주.
- **PASS** = #12-on이 #12-off 대비 **productive-기하 올바름(yield/quality)을 유의하게 올림** (사전등록 margin)
  **AND 아래 anti-circularity 가드 2종 통과**.

**★ anti-circularity 가드 (필수 — 활성 라벨 없이 순환성 차단):**
- **(G1) emergent 촉매기하**: #12로 **CRBN↔VAV1 *binding* 계면만**(#2/#3) 주입하고 **촉매 배향(라이신→Ub
  near-attack zone)은 주입하지 않는다**. → near-attack productive 기하가 *주입 안 했는데 emergent하게* 나오면
  올바른 예측(엔진이 부분 힌트로 촉매기하를 스스로 회복). 라이신/촉매기하까지 주입하면 = 답 심기 = 무효.
- **(G2) stability/self-consistency**: #12-on으로 생성한 productive ternary가 **#12를 끈 MD relaxation을
  견디고(snap-back 안 함) + multi-seed에서 재현**되어야 한다. 켤 때만 productive하고 끄면 무너지면 = forced
  artifact = FAIL.
- (선택, 비활성판별) 음성 sanity: glue/계면이 무의미한 decoy 입력엔 productive가 *안* 나와야(방법론 통제이지
  활성 순위 주장 아님). 사용자 승인 시 포함.

- 리포트: `analysis/crl_integrative/md_injection_productive_ternary_<date>.md` — 페어드 productive yield/quality
  표 + G1(emergent) 증빙 + G2(stability) 증빙 + PASS/FAIL.
- 검증 커맨드: 리포트 + 사전등록 잠금 git 이력(treatment 커밋보다 앞섬) + 페어드 채점 CSV.

## Implementation Steps

1. **선결 + 사전등록**(low-GPU): baseline productive≈0 재확인(스크린/job 8098) → degrader 집합·#12 주입항(G1:
   binding 계면만)·productive 컷·G2 stability 정의·margin freeze, 잠금 커밋.
   verify: 잠금 파일 + baseline productive yield 기록(≈0).
2. **페어드 생성 런처**: degrader별 #12 off/on(binding 계면만 주입, 촉매기하 미주입) Boltz generation.
   #12=커밋 또는 overlay. (컨트롤 smoke 먼저.)
   verify: 페어드 PDB 쌍 + #12 발화 로그(on active) + 주입에 촉매기하 미포함 확인.
3. **G1 emergent + 채점**: discriminator로 near-attack productive 기하가 emergent하게 나오나(주입 안 한 축) →
   productive yield/quality #12 on vs off.
   verify: 채점 CSV + emergent 축 분리 기록.
4. **G2 stability**: #12-off MD relax + multi-seed 재현 → snap-back/비재현이면 flag.
   verify: relax-survival + multi-seed 일치율.
5. **판정 + 리포트 + handoff**: PASS/FAIL·G1·G2·선결 증빙 문서화, baton 갱신.
   verify: 리포트 + /handoff.

## Change Discipline

- simplest adequate approach: #12 potential + vav1-ubq discriminator·MD prior 재사용. 신규=페어드 런처·
  emergent/stability 채점·사전등록.
- new abstractions introduced: binding-계면-only #12 페이로드(촉매기하 제외, G1용).
- unrelated code touched: 없음 목표(#12 wiring은 분리 가능 시만, 아니면 overlay).
- request-to-diff trace: 사용자 "활성 판별 아니라 productive 삼원복합체 제대로 예측하나" → productive 기하
  올바름 + emergent/stability anti-circularity.

## Verification

- task-specific command:
  - `python analysis/crl_integrative/<aggregate>.py` → 페어드 productive yield/quality + G1/G2 CSV
  - 리포트 `md_injection_productive_ternary_<date>.md` 존재 + PASS/FAIL
  - 사전등록 잠금 git 이력이 treatment 커밋보다 앞섬
- manual check: #12 발화 로그(on/off) + 주입에 촉매기하 미포함 + relax-survival

## Risks

- ★**순환성(THE 리스크)**: productive 주입→productive 측정 = 자명. 방어 = G1(촉매기하 emergent, 주입 안 함)
  + G2(stability, #12-off relax 생존). 두 가드 못 넘으면 "주입이 답을 심은 것"으로 무효 처리.
- **헤드룸**: baseline이 이미 productive면 개선 여지 0 → 선결 게이트로 차단(static screen은 ≈0).
- **reference 타당성**: "올바름"이 외부 GT 아닌 *물리 self-consistency*(productive 기하 정의)에 의존 → 그 정의가
  실제 ubiquitination을 대표한다는 가정. 한계로 명시(crystal 무존).
- regression: #12 default-off → 프로덕션 무변; 페어드 off가 baseline 회귀 감지.
- cross-slice: vav1-ubq 자산 읽기 전용; 슬라이스 소관(엔진#12=aigen-fold-core vs VAV1 과학=vav1-ubq) 경계 →
  필요 시 재배정 협의.

## Rollback

- revert: analysis/리포트 = git revert/삭제; #12 wiring 커밋 시 그 커밋만(flag default-off라 프로덕션 무변).
- containment: SLURM=scancel; 생성·MD 출력=/mnt 삭제(vav1-ubq 산출 읽기 전용, 공유 무변).

## Progress Log

- 2026-06-22 11:xx: /brainstorm 다회 정정 수렴. 사용자 최종 확정 — 목표=**productive 삼원복합체 올바른 예측**
  (crystal 대비 아님, 활성 판별 아님). 활성 데이터=진짜 degrader 선택 *필터*. endpoint=productive 기하 올바름
  (#12 on/off 페어드), 순환성 차단=G1 emergent 촉매기하 + G2 stability(활성 라벨 불요). placement-rescue·
  productive-separation 초안 폐기·supersede. status=pending, 승인 대기.
