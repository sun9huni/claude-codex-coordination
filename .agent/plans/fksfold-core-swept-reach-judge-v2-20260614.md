---
contract: .agent/contracts/fksfold-core-swept-reach-judge-v2-20260614.md
slice: vav1-ubq
status: done
approved_by: user (2026-06-14 "approved"); REVISION-2 re-approved (2026-06-14 "approved")
revision: 2 (2026-06-14) — nesting framing 정정(full ≤ rot+recep 비보장 → 부분순서 lattice); 새 Task 4(amendment 문서 헤더 정정) 삽입; old Task 4-9 → 5-10 재번호; Task 7 검증을 보장 링크만 assert로 수정. Tasks 1-3 done 보존.
total_tasks: 10
estimated_total_min: 39
---

# Plan — swept-reach judge v2 (4-bound lattice + RING-Zn pivot) + baseline-vs-patched Task 5

> 직전 심층분석 7발견 중 게이트 영향분(§2 confirmed 7Å 수용체 닫힘 누락, §3 pivot 비물리성)을
> judge에 보정. **순서가 핵심**: 원본 동결 judge(ac5aa68)로 **먼저** 채점(감사 baseline) →
> reach_envelope 동결 amendment → 코드 패치 → 재채점 → Δ. 7Å은 신규 임계 아닌 *confirmed-but-omitted*
> 보정이라 baseline-first가 post-hoc tuning 의심을 구조적으로 차단.
>
> **REVISION-2 (2026-06-14):** 원래 "4 nested bounds: full ≤ rot+recep ≤ rot ≤ rigid"로 썼으나
> `full ≤ rot+recep`은 **보장되지 않음**(반례: lysine Cα가 Sγ엔 가깝고 RING Zn엔 먼 경우 full > rot+recep).
> 올바른 구조 = **부분순서(lattice)**:
> ```
>              rigid
>                |
>             rotamer
>             /      \
>   rotamer+receptor  full      (둘 다 ≤ rotamer; 서로는 비교불가)
>    (확정 7Å)      (미확보 E2 full-sphere)
> ```
> rot+recep과 full은 rotamer의 **독립적 두 완화**(receptor=기질 lysine 이동, E2-sweep=촉매 Sγ 이동).
> **verdict 로직은 불변·정확** — 체인이 아니라 *신뢰도 우선순위* HARD→SEMI→SOFT→FAIL(확정 모션 경로를
> 미확보 모션 경로보다 먼저 평가). 수치 ordering과 무관하게 우선순위가 well-defined.
>
> 실행 env: `PYMOL_PY = /home/ubuntu/miniconda3/envs/pymol/bin/python` (pymol+gemmi+numpy).
> 입력셋: `SCAN = /mnt/data/users/ubuntu/workspace/mrt6160_orientation_scan_20260609/outputs`
>   = 59 pose (2Con_0×4, p30×4, p45×16, p60×16, p75×16, unsteered×3). Zn은 overlay chain X에 보존됨(확인).
> ⚠️ 본 plan이 durable 기록(baton 미접촉). 상위 plan(swept-reach-judge-20260612) Task 5는 본 Task 1+8로
>   대체 실행; 그 plan의 Task 6-9(Tier2/surface/report)는 survivors 게이트 뒤 downstream 유지.

## Phase A — baseline (원본 동결 judge, 감사 기준선)

## Task 1: 원본 judge(ac5aa68)로 59 pose 채점 → baseline.csv
- **Status**: done (commit 0cc787d) — 59/59 SOFT(0 HARD; best_rotamer 바닥 22.1Å; centroid r_lever 34.3Å→best_full~0). 판별력 0 확인.
- **Prereq tasks**: none
- **Files touched**: `analysis/productive_pose/swept_reach_baseline.csv`
- **Verification**: `wc -l` → 60 lines; `grep -c ERR` → 0

## Phase B — 동결 amendment (pre-reg 감사성)

## Task 2: reach_envelope.md에 날짜표시 amendment 절 추가 (7Å 수용체 닫힘)
- **Status**: done (commit dc6873b) — R_recep 7Å + PMC2741574 + pose-derived:NO + 게이트 + pivot 노트. ⚠️ "nested chain" 헤더 오류 → Task 4에서 정정.
- **Prereq tasks**: 1

## Phase C — judge v2 코어 패치 (swept_reach.py, 순차 diff) + 문서 정정

## Task 3: pivot centroid → RING Zn 교체
- **Status**: done (commit 831e0e3) — pivot=RING Zn(X4002), R_lever 27.7Å(vs centroid 34.3). code-review APPROVE_WITH_NITS.
- **Prereq tasks**: 1

## Task 4: reach_envelope.md amendment nesting 헤더 정정 (chain → lattice)
- **Status**: done (commit 4364e86) — 부분순서 lattice + confidence-priority로 정정, 게이트 bullets 보존.
- **Prereq tasks**: 2
- **Files touched**: `analysis/productive_pose/reach_envelope.md`
- **Change shape**: Task 2 amendment의 `### Revised gate (4 nested bounds: full ≤ rotamer+receptor ≤
  rotamer ≤ rigid)` 헤더의 **틀린 체인 주장**을 부분순서로 정정 → "4 bounds, partial order:
  `rotamer+receptor ≤ rotamer ≤ rigid` AND `full ≤ rotamer ≤ rigid`; rotamer+receptor ⊥ full
  (rotamer의 독립적 두 완화 — receptor=기질 이동, E2-sweep=촉매원자 이동; 상호 비교불가)". 그 아래
  게이트 설명 4줄(HARD/SEMI/SOFT/FAIL)은 **이미 정확**하므로 보존하되, "verdict = 신뢰도 우선순위
  (수치 체인 아님)" 한 줄 명시. 수치·임계·출처 불변.
- **Verification**: `sed -n '/### Revised gate/,/Audit note/p' analysis/productive_pose/reach_envelope.md | grep -E "partial order|⊥|independent|우선순위"` → 정정된 부분순서 표현 존재 **AND** `grep -c "nested bounds: \`full ≤ rotamer+receptor" analysis/productive_pose/reach_envelope.md` → 0 (틀린 체인 문구 제거됨)
- **Estimated time**: 3 min
- **Rollback (if this task only)**: 헤더를 직전 문구로 되돌림

## Task 5: 4번째 bound(rotamer+receptor) + 4분류 verdict + docstring 부분순서
- **Status**: done (commit c11d5ac) — R_RECEP 7Å + rot_recep bound + SEMI tier + 부분순서 docstring + batch cols-list. code-review APPROVE. completed_seed42 SOFT, nesting 5/5.
- **Prereq tasks**: 3, 4
- **Files touched**: `analysis/productive_pose/swept_reach.py`
- **Change shape**: `R_RECEP = 7.0` 상수(출처 PMC2741574 주석). `score_swept` rows에
  `rotamer_receptor = max(0, d(Cα,Sγ) − L_ROT − R_RECEP)` 추가 + `_best("rotamer_receptor")`.
  verdict 4분류(**신뢰도 우선순위**): **HARD**(best_rotamer≤R_REACH) / **SEMI**(rotamer>R_REACH &
  rotamer_receptor≤R_REACH) / **SOFT**(full≤R_REACH) / **FAIL**(else). `_print_single` 표·CSV 헤더에
  rotamer_receptor 열 추가. **docstring nesting 주석을 부분순서(lattice)로 갱신** — 기존
  "세 nested bound(full ≤ rotamer ≤ rigid)" → 4-bound 부분순서(`rot+recep ≤ rot ≤ rigid` AND
  `full ≤ rot ≤ rigid`; rot+recep ⊥ full) + verdict=우선순위 설명. rigid 산출경로 **불변**(⊥ steering).
- **Verification**: `$PYMOL_PY analysis/productive_pose/swept_reach.py --pose analysis/productive_pose/completed_seed42.pdb` → 각 lysine에서 **보장 링크** `rotamer_receptor ≤ rotamer ≤ rigid` AND `full ≤ rotamer ≤ rigid` 성립(full vs rot+recep는 비교 안 함), FROZEN 헤더에 R_recep=7.0, VERDICT ∈ {HARD,SEMI,SOFT,FAIL}
- **Estimated time**: 5 min
- **Rollback (if this task only)**: 4번째-bound hunk 되돌림

## Task 6: _best None-가드 + 회색지대/strict-16 보고 열
- **Status**: done (commit 52a6cb9) — _best 모듈레벨 None-safe + _zone 추가, zone 열 wired. None-가드 3-key 테스트 (20.0,3) 무예외, zone '>18'. code-review APPROVE.
- **Prereq tasks**: 5
- **Files touched**: `analysis/productive_pose/swept_reach.py`
- **Change shape**: §7 `_best` None-비교 TypeError 가드(None 키를 min 전에 제외 또는 inf sentinel).
  §6 회색지대: best_rotamer 기준 zone 분류(`≤16 strict / 16–18 ceiling / >18`) per-pose 산출 →
  `_print_single`에 strict-16 readout + CSV에 `zone` 열 추가.
- **Verification**: `python3 -c "import importlib.util as u; s=u.spec_from_file_location('sr','analysis/productive_pose/swept_reach.py'); m=u.module_from_spec(s); s.loader.exec_module(m); print(m._best({1:{'rotamer':None},2:{'rotamer':20.0}}, 'rotamer'))"` → **예외 없이** `(20.0, 2)` (None-가드; gemmi/pymol import 불필요한 순수 함수 테스트) ; `$PYMOL_PY analysis/productive_pose/swept_reach.py --pose analysis/productive_pose/completed_seed42.pdb | grep -iE "strict|zone"` → zone/strict 출력
- **Estimated time**: 4 min
- **Rollback (if this task only)**: 해당 hunk 되돌림

## Phase D — 무결성 검증 (orthogonality gate)

## Task 7: rigid 재현(⊥) + 보장 nesting 링크 다중-pose 검증
- **Status**: done (read-only PASS) — rigid 정확 재현(completed_seed42 = m1_existing_poses.csv seed42 행 36.2/36.9/46.6/53.1/64.2). 보장 링크 10/10 성립(completed_seed42 + raw 2Con_p45_seed42). full<rot+recep 양쪽(보고). raw-build 경로 정상.
- **Prereq tasks**: 6
- **Files touched**: 없음(read-only 검증)
- **Change shape**: 패치 후 swept_reach를 (a) 완성 overlay `completed_seed42.pdb`와 (b) raw-build scan
  pose 1개(예: `$SCAN/2Con_p45_seed42/...model_0.pdb`)에 실행 → rigid 열이 `m1_existing_poses.csv`의
  completed_seed42 값(36.2/36.9/46.6/53.1/64.2)과 **정확 일치**(패치가 rigid 경로 미오염=⊥ 보존) +
  두 pose 모두 **보장 nesting 링크** `rotamer_receptor ≤ rotamer ≤ rigid` AND `full ≤ rotamer ≤ rigid`
  성립을 확인(값 비교). full vs rotamer_receptor 순서는 **assert 아님 — 보고만**(부분순서이므로
  geometry-dependent; 두 pose에서 어느 쪽이 작은지 기록).
- **Verification**: `$PYMOL_PY analysis/productive_pose/swept_reach.py --pose analysis/productive_pose/completed_seed42.pdb` rigid 열 == m1_existing_poses.csv 행(diff 0) **AND** 두 pose에서 보장 링크 부등식 성립 → PASS 1줄 + full-vs-rot+recep 순서 1줄 보고
- **Estimated time**: 3 min
- **Rollback (if this task only)**: n/a (읽기전용)

## Phase E — patched 채점 + 종합

## Task 8: judge v2로 59 pose 재채점 → swept_reach.csv
- **Status**: done (commit 19bfb42) — 9 SEMI / 50 SOFT / 0 HARD / 0 FAIL. zone 전부 >18(rotamer-only 게이트 미통과). min rot+recep 15.1(p60_seed123). max best_full 14.7(STOP 없음).
- **Prereq tasks**: 7
- **Files touched**: `analysis/productive_pose/swept_reach.csv` (신규 출력)
- **Change shape**: 패치된 judge로 `--batch SCAN`(Task 1과 **동일 입력셋 59 pose**) → swept_reach.csv.
  신규 열(rotamer_receptor, zone) 포함.
- **Verification**: `$PYMOL_PY analysis/productive_pose/swept_reach.py --batch $SCAN > analysis/productive_pose/swept_reach.csv && wc -l analysis/productive_pose/swept_reach.csv` → **60 lines**; `head -1 analysis/productive_pose/swept_reach.csv | grep -E "rotamer_receptor.*zone"` → 신규 열 존재; `grep -c ERR` → 0(또는 사유)
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `rm analysis/productive_pose/swept_reach.csv`

## Task 9: swept_reach_verdict.md — Δ vs baseline + 게이트 + anchor 4범인
- **Status**: pending · **Prereq tasks**: 1, 8
- **Files touched**: `analysis/productive_pose/swept_reach_verdict.md`
- **Change shape**: baseline.csv vs swept_reach.csv 조인 → (1) Δ표: verdict 바뀐 pose 수 + 어느 tier가
  뒤집었나(7Å semi-hard vs pivot); (2) orientation 버킷별(2Con_0/p30/p45/p60/p75/unsteered) 요약;
  (3) 회색지대 3분할 카운트(≤16/16–18/>18, best_rotamer); (4) **게이트**: HARD/SEMI/SOFT survivors 목록
  또는 STOP; (5) MRT6160 anchor 정합 — survivors=0이면 red flag + 4범인(overlay graft / Boltz pose /
  미모델 모션 / static-graft 한계) 중 유력 지목(7Å 넣고도 0이면 'judge 빡빡' 약화→구조/모델 의심);
  (6) 한계(cross-cullin graft, +2Å 단위, VAV1 SH3 재배향·full-length 미모델, **부분순서 bound의 의미**).
- **Verification**: `cat analysis/productive_pose/swept_reach_verdict.md` → Δ vs baseline + survivors/STOP + 3분할 + anchor 4범인 + 한계 절 모두 존재
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm analysis/productive_pose/swept_reach_verdict.md`

## Phase F — commit + handoff

## Task 10: surgical commit + 슬라이스 baton 갱신 + plan/contract 마감 + handoff
- **Status**: done — analysis 산출물 9 commit(0cc787d…fccbdb4) 증분 완료; contract/plan done; baton v3; handoff.sh + status.sh index.
- **Prereq tasks**: 9
- **Files touched**: git commit(swept_reach.py, reach_envelope.md, swept_reach.csv,
  swept_reach_verdict.md — baseline.csv는 Task 1에서 이미 commit), `.agent/status/vav1-ubq.md`,
  본 plan + contract Progress Log
- **Change shape**: 신규/개정 analysis 파일만 surgical commit(타 dirty entry 미접촉). baton에 결과 +
  다음 액션(Tier-2 게이트 상태 = survivors 수에 의존) 기록. 본 plan task들 done 마킹.
  `./scripts/handoff.sh claude vav1-ubq` + `./scripts/status.sh index`.
- **Verification**: `git show --stat HEAD | head -20` → 의도한 analysis 파일만 포함(타 슬라이스 파일 없음);
  `git status --short analysis/productive_pose/` → 커밋 후 clean; CURRENT.md 재생성됨
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git revert HEAD`(커밋 단위)
