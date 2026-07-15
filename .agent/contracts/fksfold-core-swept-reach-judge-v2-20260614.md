# fksfold-core-swept-reach-judge-v2 — judge 개정(4단 bound + RING-Zn pivot) + baseline-vs-patched Task 5

- **Status**: done
- **Approval**: requested 2026-06-14 · approved by: user (2026-06-14 "승인"); REVISION-2 re-approved
- **Notes (delivered 2026-06-14)**: plan `.agent/plans/fksfold-core-swept-reach-judge-v2-20260614.md`
  (10 tasks, 9 commits 0cc787d…fccbdb4). judge v2 = 4-bound **lattice**(rotamer+receptor ⊥ full) +
  RING-Zn pivot + None-guard + zone. baseline(원본 judge) 59/59 SOFT → v2 **9 SEMI / 50 SOFT /
  0 HARD / 0 FAIL**; Δ 100% 확정 7Å 수용체 tier 귀속(pivot은 verdict 무변경, baseline-first로 감사).
  0 HARD = productive 기하는 곁사슬만으론 불가, 수용체 운동 필수. **게이트 = 9 SEMI survivor**
  (Tier-2 후보; 최우선 p60_seed123 rot+recep 15.1Å). MRT6160 active anchor 정합(survivors>0).
  REVISION-2: 초기 "nested chain" 서술 오류(full ≤ rot+recep 비보장)를 부분순서로 정정.
  결과 `swept_reach_verdict.md`. **Tier-2 GPU = 미실행(상위 contract 게이트: 사용자 go 필요).**
- **Slice**: vav1-ubq (legacy slug `fksfold-core-` 유지 — 본 슬라이스 소관, 엔진코드 repo 이동 없음)
- **상위 계약**: `fksfold-core-swept-reach-judge-20260612`(2-tier judge, approved). 본 계약은 그
  Tier-1 judge(Task 5)를 실행하기 전에 **judge 자체를 개정**하는 후속 — 동일 2-tier 구조·게이트 의미
  유지, 단 게이트에 들어가는 *bound 집합*을 직전 심층분석 결과로 보정.
  ⚠️ baton 미접촉(durable 기록 = 본 contract/plan).

## Purpose

직전 심층분석(2026-06-14)에서 현 `swept_reach.py`(ac5aa68) judge가 **확정된 유연성 한 종류를
누락**한 비일관성이 드러남: 게이트가 사실상 단일 경계 숫자(best lysine `d(Cα,Sγ)≤24.5Å`)로 환원되는데,
그 경계 바로 옆에 있어야 할 **confirmed 7–12Å 수용체(CRBN box) 닫힘**(PMC2741574, 3-0)이 빠져 있고,
반대로 **미확보** RING sweep엔 full-sphere 무료 이용권을 줬다. 그 결과 Task 5가 STOP을 내도
"judge가 너무 빡빡한 것 vs 실제 기하 불가"를 구분할 수 없고, MRT6160 active anchor와의 모순을
오독하게 된다. **judge를 보정해 verdict가 '진짜 도달 가능성'을 재게** 만드는 것이 목적.

## Current State

- `analysis/productive_pose/swept_reach.py`(ac5aa68): 3단 nested bound
  (`full ≤ rotamer ≤ rigid`). HARD = `best_rotamer ≤ 18`(= `d(Cα,Sγ)≤24.5`). pivot = RBX1 chain Cα
  **centroid**(빌드 테스트 R_lever 34Å). 단일-pose 검증만, 48 batch 미실행.
- `analysis/productive_pose/reach_envelope.md`: FROZEN 파라미터. **7–12Å 수용체 닫힘이 frozen 표에
  누락**(단, `reach_envelope_research.md` §(2)엔 confirmed 3-0으로 이미 기록됨 — 동결 전파 누락).
- rigid M1 floor ~24Å(dense 48-scan). rigid_M1은 `m1_score.score_m1` 재사용(steering ⊥ 유지).

### 심층분석 7개 발견 (게이트 영향 여부)
| # | 발견 | 게이트 영향 | 본 계약 처리 |
|---|---|---|---|
| §1 | verdict ≈ 단일 경계 `d(Cα,Sγ)≤24.5` (가능범위 18.5~29.5 정중앙) | — (구조적 사실) | 4단 bound로 해상도↑ |
| §2 | confirmed 7–12Å 수용체 닫힘 누락 vs 미확보 RING엔 full-sphere | **YES** | 4단 tier 추가(7Å 하한) |
| §3 | pivot=centroid(34Å) 비물리적 (RING ~14Å) | SOFT only | RING-Zn으로 교체 |
| §4 | 단위변환 +2Å 방향 맞음(보수적), 단 graft=transfer 전제 | — | 한계로 명시 |
| §5 | anchor 0 = 범인 4개(method/Boltz/모션부족/static 한계) | — | verdict.md에 4범인 명시 |
| §6 | 16Å "벤치마크됨" 0-3 기각 → 16–18 회색지대 | 보고 | 3분할 보고(≤16/16–18/>18) |
| §7 | `_best` None-비교 잠복 TypeError(single-pose) | 견고성 | 가드 추가 |

## Assumptions And Questions

- **가정**: 7Å은 *새 임계가 아니라* 이미 confirmed·동결문서에 있던 값의 전파 누락을 고치는 것 →
  pre-registration 안 깸. 7–12Å 중 **하한 7Å만** 보수적 사용. RING-Zn 좌표는 Task 2
  `reach_envelope_geom.py:rbx1_ring_zn`로 결정적 산출.
- **tradeoff**: 7Å을 semi-hard tier로 넣으면 임계가 `d(Cα,Sγ)≤31.5`로 이동(가능범위 전체 포함) →
  HARD/semi 통과 포즈 급증 가능. 이를 막기 위해 rotamer(순수 HARD)와 rotamer+receptor(semi-hard)를
  **분리** tier로 둬 "확정 곁사슬만으로" vs "확정 수용체 모션까지 동원" 도달을 구분.
- **결정된 fork(2026-06-14 사용자)**: ①7Å=semi-hard 4단 tier ②순서=baseline 먼저→패치→재실행
  ③pivot=RING Zn 교체.

## Scope

- **judge v2 (`swept_reach.py` 개정)**: 4단 nested bound
  `full ≤ rotamer+receptor ≤ rotamer ≤ rigid`. 신규 tier = `rotamer_receptor =
  max(0, d(Cα,Sγ) − L_rot − R_recep)`, `R_recep = 7.0Å`(PMC2741574 하한). pivot centroid→RING Zn.
  `_best` None-가드. rigid_M1 산출 **불변**.
- **reach_envelope.md amendment**: 날짜표시 "Amendment 2026-06-14" 절 추가 — 수용체 닫힘 7–12Å
  (confirmed, 출처) frozen 표에 편입 + "confirmed-but-omitted 보정, pose-derived 아님" 명시.
- **Task 5 baseline-vs-patched**: (a) **원본 동결 judge(ac5aa68)** 로 48 pose + unsteered 채점 →
  `swept_reach_baseline.csv`(감사용 원본 verdict). (b) v2로 동일 입력 재채점 → `swept_reach.csv`.
  (c) `swept_reach_verdict.md` = Δ(verdict 바뀐 포즈 수·어느 tier가 뒤집었나) + 3분할 회색지대 +
  MRT6160 anchor 정합(4범인 명시).

## Out of scope

- **Tier 2 GPU**(flexible docking/MD) — 상위 계약 소관, survivors>0 + 사용자 go 게이트 유지.
- **rigid_M1 scorer 변경**(상대 ranker 불변, ⊥ steering). 7–12Å 중 상한(12Å) 사용·full-sphere 식 7Å화.
- VAV1 SH3 재배향·full-length VAV1 동역학 모델링(인정된 미모델 자유도, 본 계약 비대상 — 한계로만 기록).
- 신규 generation/방향 스캔 재실행. distal lysine. m-relativity 양자/committor.

## Success criteria

1. **baseline 채점**: `python swept_reach.py --batch <scan-dir>` (ac5aa68 코드) → `swept_reach_baseline.csv`
   48행 + unsteered, ERR 행 0(또는 사유). 원본 동결 judge의 정직한 verdict 확보.
2. **judge v2 정합**: 패치 후 `python swept_reach.py --pose <completed>` →
   nesting `full ≤ rotamer+receptor ≤ rotamer ≤ rigid` 모든 pose 성립 + **rigid_M1이
   `m1_existing_poses.csv` 정확 재현**(⊥ 보존) + pivot이 `rbx1_ring_zn` 사용.
3. **patched 채점 + Δ**: `swept_reach.csv` + `swept_reach_verdict.md` → baseline 대비 verdict 변경
   포즈 수·tier별 기여 + 3분할(≤16 strict / 16–18 회색 / >18) + 게이트(survivors 또는 STOP).
4. **anchor 정합**: MRT6160 active인데 v2로도 survivors=0이면 red flag + 4범인(method/Boltz/모션부족/
   static graft 한계) 중 무엇이 유력한지 명시(7Å 넣고도 0이면 'judge 빡빡' 가설 약화 → 구조/모델 의심).
5. **amendment 감사성**: `reach_envelope.md`에 날짜표시 amendment 절 + baseline이 amendment **이전**
   원본 judge로 산출됐음이 기록 → post-hoc tuning 아님이 증명됨.

## Triggers matched

- **ranking/verdict 의미 변경**(productive 게이트의 bound 집합) → 계약 필수.
- **4+ files**(swept_reach.py · reach_envelope.md · baseline.csv · swept_reach.csv · verdict.md).
- **zero-GPU**. /mnt/data 스캔 출력 = read-only 입력. 출력 = home repo `analysis/`(shared-storage 쓰기 없음).

## Resource budget

- **zero-GPU**. 48 pose × 2회(baseline + v2) build_complex(pymol, pose당 수초) → 분 단위.
  실행 env = `/home/ubuntu/miniconda3/envs/pymol/bin/python`(pymol+gemmi+numpy).

## Constraints

- **HARD**: rigid_M1 산출 불변(⊥ steering 보존, 성공기준 2로 검증). 7Å = PMC2741574 confirmed 3-0
  **하한만**, reach_envelope amendment는 날짜표시·pose-derived 아님. baseline은 패치 **전** 원본
  동결 judge로 채점(감사 추적). soft/full = relative-rank only(절대판정 아님).
- 신규/개정 파일만 surgical commit. baton 미접촉. subagent에 dirty 파일 git 조작 금지(미커밋이면 선커밋).

## Rollback

- `git checkout analysis/productive_pose/swept_reach.py`(→ ac5aa68, 클린 — 이미 커밋됨).
  reach_envelope.md amendment 절 제거. 신규 csv/md 삭제. **GPU·외부·shared-storage 부작용 0.**
  baseline.csv는 어느 경우든 원본 judge 기록으로 보존 가치(롤백해도 유지 가능).

## Progress Log

- 2026-06-14: /brainstorm → judge v2 개정 스펙. 직전 심층분석 7발견 중 게이트 영향분(§2 7Å 누락,
  §3 pivot) 반영. fork 잠금: 7Å=semi-hard 4단 tier / baseline-first / RING-Zn pivot. 나머지(§1 해상도,
  §5 4범인, §6 회색지대, §7 None-가드)는 비게이트 보정으로 동반. pre-reg: 7Å은 신규 임계 아닌
  confirmed-but-omitted 보정 + baseline-first로 감사성 확보.
