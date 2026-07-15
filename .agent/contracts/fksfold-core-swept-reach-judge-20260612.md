# fksfold-core-swept-reach-judge — productive 판정 (2-tier: geometric screen → 물리 confirm)

- **Status**: approved
- **Approval**: requested 2026-06-12 · approved by: user (2026-06-12 "진행", 2-tier 개정 "진행")
- **Slice**: fksfold-core (MRT6160 productive-orientation 워크스트림)
- **상위 계약**: `fksfold-core-mrt6160-productive-orientation-20260609`(PRE-REG AMENDMENT 실행 후속).
  ⚠️ fksfold-core slice baton은 타 세션(89d90310) 점유 → 본 contract/plan이 durable 기록.

## Purpose

rigid-overlay M1이 ~24Å **바닥**(밀집 48 pose 스캔). 진짜 질문 — **"CRL/E2~Ub 유연성 하에서 SH3
lysine이 E2 활성부위에 도달 가능하고, 그 기하가 에너지적으로 접근 가능한가"** — 을 **2-tier**로 판정:
geometric swept-reach는 *필요조건(상한)*일 뿐이므로 1차 스크린으로만, productive 확정은 물리 confirm으로.

## 2-tier 구조 (설계 잠금)

- **Tier 1 — zero-GPU geometric screen (싸고 빠름, 48 pose 전체):** completed overlay에서 E2~Ub 촉매
  Cys를 RBX1-anchored 경첩 arc로 sweep **AND SH3-5 lysine 측쇄 rotamer도 sweep**(양쪽 유연성) →
  **M1_swept = min over (E2 sweep × lysine rotamer) of d(Nζ, E2 Cys)**. rigid M1 나란히(바닥 뚫었나).
  **게이트:** full sweep으로도 *어느 pose도* 기하적으로 안 닿으면(M1_swept ≫ envelope) **STOP**
  (방향이 답 아님; geometric이 상한이라 물리도 못 구함). 닿는 후보 추림 + rank.
- **Tier 2 — GPU 물리 confirm (Tier 1 survivors만):** flexible docking / 짧은 MD로 productive 기하
  (lysine↔E2 near-attack)가 **에너지적으로 접근 가능·populated**한지 확인 → 진짜 productive 판정.
- **envelope 파라미터 = deep-research(문헌) + cryo-EM(2HYE/6TTU) 1차원리 교차검증.** near-attack 임계·
  경첩각·rotamer 범위는 출처 있는 값만(fabricate 금지; soft면 상대-rank로 강등).
- **기능 anchor:** MRT6160 = 알려진 active VAV1 degrader → 예측 productive 판정이 *활성과 정합*해야.
  productive 0개면 overlay/방법 red flag. (DC50 수치 locating 포함; 못 찾으면 정성 active로.)

## 입력 (보유)

- 48 scan pose (`outputs/2Con_{0,p30,p45,p60,p75,...}_seed*` + unsteered), completed overlay 빌더
  `complete_structure.py`, M1 scorer, `smoke_m1.py`. 2HYE RBX1 + 6TTU E2~Ub(Cys D85) 기하.
- MRT6160 활성: 정성 active(Monte Rosa VAV1 degrader); DC50 수치는 locating 대상.

## Scope

- envelope 파라미터 교차검증 확보(deep-research + cryo-EM) + 문서화.
- **Tier 1** geometric swept-reach judge(E2 sweep × lysine rotamer, 48 pose 전체) + 게이트 + rank.
- **Tier 2** GPU 물리 confirm(survivors: flexible docking/짧은 MD) → productive 확정.
- 기능 anchor(MRT6160 active 정합 체크). 선택 구조 swept-volume surface.

## Out of scope

- **장기 production MD / full 자유에너지** (Tier 2는 *짧은* confirm). 새 GPU *생성*/방향 스캔 재실행.
- distal lysine(배제 유지). M-RELATIVITY committor/양자. rigid M1 자체 변경(상대 ranker 유지). 엔진 변경.

## Success criteria

1. **envelope 문서화 + 교차검증**: `cat reach_envelope.md` → 경첩각·sweep반경·near-attack·rotamer 범위
   + 문헌/cryo-EM 출처 + 일치/괴리. fabricate 0.
2. **Tier 1 judge + 게이트**: `python swept_reach.py --pose <completed>` → M1_swept(E2×rotamer) + rigid 대비
   + PRODUCTIVE-candidate/NOT. 48 pose 전체 표(`swept_reach_verdict.md`) + 게이트 판정(survivors 또는 STOP).
3. **Tier 2 confirm**(survivors 있을 시): `squeue` 제출 → flexible docking/MD 결과 → near-attack 기하의
   에너지적 접근성 판정 → **productive orientation 확정**. (survivors 0이면 Tier 2 SKIP + STOP 결론 문서화.)
4. **anchor + surface**: MRT6160 active 정합 체크 결과 명시 + 선택 구조 swept-volume(도달 cone + overlap).

## Triggers matched

- **Tier 1**: deep-research(web) + 4+ files + /mnt 쓰기. **zero-GPU.**
- **Tier 2**: **SLURM/GPU 제출**(flexible docking/짧은 MD) — 본 계약이 그 sbatch를 authorize. Tier 1
  게이트 통과 + 사용자 go 후에만.

## Resource budget

- **Tier 1 = zero-GPU** + deep-research 1패스(기존 pose 재사용). **Tier 2 = GPU/SLURM**, survivors만
  (몇 후보 × 짧은 MD/docking) — GPU 풍부하나 게이트 뒤에서만(diagnose-before-scale).

## Constraints

- **HARD: Tier 1 게이트** — geometric screen survivors 없으면 Tier 2 GPU 금지(STOP). envelope 파라미터
  출처 필수(soft면 절대판정 대신 상대-rank). rigid M1 vs M1_swept 나란히. SH3-5 only.
- 신규 파일만 surgical commit. fksfold-core slice baton 미접촉.

## Rollback

- Tier 1: 신규 스크립트/리포트/출력 삭제. Tier 2: 생성/MD 출력 디렉토리 삭제(production·엔진·타 세션 미변경).

## Progress Log

- 2026-06-12: /brainstorm → 2-tier 개정(사용자 "zero-GPU 단독은 부적절, 구조 검토"). zero-GPU geometric은
  *필요조건 스크린*(Tier 1)으로만, productive 확정은 *GPU 물리 confirm*(Tier 2, survivors). 추가: 후보
  pre-filter 제거(48 전체) · lysine rotamer도 sweep · soft-envelope 상대-rank · MRT6160 active 기능 anchor.
