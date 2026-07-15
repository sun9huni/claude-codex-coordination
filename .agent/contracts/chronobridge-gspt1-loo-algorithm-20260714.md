---
status: done
slice: chronobridge
topic: gspt1-loo-algorithm
date: 2026-07-14
owner: claude
approved_by: sunghoon.kim (2026-07-14, "승인")
requested: 2026-07-14
cross_slice: []
triggers_matched:
  - "4개 파일 이상 수정 (예상) — 알고리즘 스펙 문서 + 9HNE 디코이 스크립트 확장/신규 +
     디코이 구조 파일 + 시퀀스 일치성 검증 + MD 범위 갱신 문서"
  - "후속 MD 예산(B200) 산정에 영향 — 이 계약의 결과로 md_necessity.md의 '3개 시스템'
     추정이 '6개 시스템(정답 3 + 디코이 3)'으로 갱신될 예정"
---

# chronobridge — GSPT1 leave-one-ternary-out: 분석 알고리즘 확정 + 3-fold 디코이 완성

## Purpose

`chronobridge-gspt1-leave-one-out-20260713`(BRANCH B, done)에서 leave-one-ternary-out
자체는 실행하지 못했다(기존 앙상블 데이터 없음). 사용자가 B200 서버에서 신규 MD를
돌리기로 했는데, GPU 예산을 쓰기 전에 "leave-one-out이 정확히 무엇을 측정하는
테스트인가"부터 확정해야 한다는 것이 이번 계약의 출발점이다(2026-07-14 대화에서
Claude가 지적한 설계 공백: 시스템 3개를 각각 독립적으로 MD 돌린다고 자동으로
"교차검증"이 되는 게 아니다 — Phase A의 ChronoBridge/FP검출기는 둘 다 "단일 앙상블
내부"에서만 작동하는 비지도 방법이라, "나머지 2개로 3번째의 basin을 복원/예측"하는
메커니즘이 원래 없다).

사용자 확인(2026-07-14, AskUserQuestion): (1) "구조 복원/예측"이 아니라 **FP검출기의
cross-glue 일반화 테스트**로 재정의, (2) ChronoBridge(pseudotime)는 이번 테스트에서
**시스템별 QC 전용**(교차시스템 예측에는 안 씀), (3) 9HNE을 포함한 3번째 디코이도
**지금(zero-GPU) 만들어 3-fold 전부 완성**.

## Current State

- 결정구조 3개(5HXB/CC-885, 6XK9/CC-90009, 9HNE/Compound-1) 확보 완료
  (`.agent/scratch/chronobridge/phaseB/pdb/`).
- 디코이 2개 완성(`decoys/decoy_report.txt`): 6XK9-glue→5HXB-backbone,
  5HXB-glue→6XK9-backbone. 둘 다 강체 수준 clash(1.846Å/4쌍, 2.382Å/1쌍) —
  실제 불안정 basin인지 정렬 아티팩트인지는 MD 없이 구분 불가(이 계약 범위 밖,
  B200 계약에서 해소).
- `build_decoys.py`는 5HXB/6XK9 쌍만 지원(같은 chain 표기법 X/Y/Z+A/B/C, 둘 다
  legacy PDB). 9HNE은 다른 표기법(A/B/C+D/E/F) + mmCIF라 명시적으로 미지원 상태로
  남겨져 있음(`build_decoys.py` 모듈 docstring "Scope note").
- Phase A의 FP검출기는 pairwise Cα-Cα distance를 특징으로 쓴다(회전/이동 불변).
  Phase A에서는 서로 다른 단백질(1k5n_A vs 1r6w_A, Cα 개수 다름)이라 크롭이
  필요했지만, GSPT1/6XK9/9HNE의 GSPT1·DDB1·CRBN 체인이 **동일 구성체(같은 서열)**인지는
  아직 확인 안 됨 — 확인되면 크롭 없이 바로 특징 비교 가능, 안 되면 Phase A처럼
  정렬/크롭 절차가 필요.

## Assumptions And Questions

- assumptions: 5HXB/6XK9/9HNE의 GSPT1·DDB1·CRBN이 재조합 구성체로서 서열이 동일할
  가능성이 높다(같은 프로젝트에서 나온 결정구조들, PDB_notes.md에 서열 불일치 언급
  없음) — 이 계약의 task 1에서 직접 확인한다.
- open questions:
  - 9HNE 디코이를 5HXB/6XK9 양쪽에서 다 만들지(대칭), 한쪽만 만들지(fold C에 필요한
    최소 1개)는 실행 단계에서 build_decoys.py의 기존 관행(상호 양방향)을 따를지
    결정한다.
  - fold별 정확한 통계량(예: 부트스트랩 CI로 real-vs-decoy FP-score 분리 유의성)은
    Phase A의 evaluate.py 패턴을 그대로 재사용 가능한지, 아니면 cross-system이라
    다시 설계해야 하는지 — task에서 확정.
- tradeoffs: 이 계약은 알고리즘 설계 + 디코이 완성까지만(zero-GPU). 실제 MD 실행과
  그 결과에 통계량을 적용하는 것은 B200 후속 계약(별도)의 범위다.

## Constraints

- allowed change scope: `.agent/scratch/chronobridge/phaseB/`(9HNE 디코이 추가,
  알고리즘 스펙 문서, 시퀀스 확인 스크립트/결과, MD 범위 갱신 노트).
- forbidden change scope: SLURM/GPU 제출 없음(이 계약은 완전히 zero-GPU). Phase A
  산출물(`phaseA/`) 미수정. 기존 `build_decoys.py`의 5HXB/6XK9 로직은 그대로 두고
  9HNE 지원을 추가(기존 동작 변경 금지, 회귀 위험 방지).
- external constraints: 없음.

## Non-Goals

- 실제 신규 MD 실행(B200 서버) — 완전히 별도 계약.
- leave-one-glue-out 테스트 — 여전히 범위 밖.
- IKZF/CK1α/VAV1(Phase C~E) — 범위 밖.
- ChronoBridge를 교차시스템 예측 도구로 확장하는 것 — 사용자 확인대로 시스템별 QC로만
  범위 한정.

## Done When

- GSPT1·DDB1·CRBN 서열이 5HXB/6XK9/9HNE 전체에서 동일한지 직접 확인(잔기 수 +
  서열 비교), 결과를 문서화(동일하면 Phase A식 크롭 불필요, 다르면 정렬 전략 명시).
- 3-fold 전부를 커버하는 디코이 확보: 9HNE을 backbone 또는 glue-donor로 포함하는
  디코이를 최소 1개 신규 생성(9HNE의 mmCIF/다른 chain 표기법을 처리하는 로직 추가,
  기존 5HXB/6XK9 디코이는 그대로 유지).
- 알고리즘 스펙 문서 작성: fold별로 (a) calibration set(나머지 2개 시스템의 앙상블
  프레임 풀), (b) test set(held-out 시스템의 실제 앙상블 프레임 + 그 fold의 디코이
  앙상블 프레임), (c) 통계량(예: real vs decoy FP-score 분포 차이의 부트스트랩 CI,
  Phase A evaluate.py 패턴 재사용 여부 명시)을 정확히 정의. "일반화한다"고 판정할
  구체적 기준(예: 3-fold 중 최소 몇 개에서 CI가 0을 배제해야 하는지)도 명시.
- ChronoBridge의 역할을 "시스템별 QC(단일 앙상블이 하나의 결맞은 basin으로 수렴했는지
  확인 — Phase A에서 발견된 것 같은 component 분리가 없는지)"로 명시적으로 문서화하고,
  교차시스템 예측에는 쓰지 않음을 못박는다.
- md_necessity.md의 "3개 시스템" 추정을 "6개 시스템(정답 3 + 디코이 3)"으로 갱신하는
  노트 작성 — B200 계약의 예산 산정 입력이 되도록.
- 결과 문서 + 계약 done.

## Implementation Steps

1. 5HXB/6XK9/9HNE의 GSPT1·DDB1·CRBN 체인 서열/잔기수 비교(Biopython, `build_decoys.py`
   패턴 재사용). verify: 일치/불일치 명시적 결론 + 근거.
2. 9HNE 지원 추가(신규 스크립트 또는 `build_decoys.py` 확장 — 기존 5HXB/6XK9 로직
   불변): mmCIF 파싱, 9HNE의 A/B/C(+D/E/F) 표기법에 맞는 chain lookup, 최소 1개
   9HNE-포함 디코이 생성 + clash 체크(Task 4와 동일 방법론). verify: 새 디코이 구조
   파일 존재 + 이전 2개 디코이 파일 변경 없음(git diff 확인).
3. 알고리즘 스펙 문서 작성(`.agent/scratch/chronobridge/phaseB/loo_algorithm_spec.md`):
   fold별 calibration/test set, 통계량, 판정 기준, ChronoBridge 역할. verify: 3-fold
   전부 명시적으로 기술됨(fold A/B/C 각각 held-out 시스템 + 사용할 디코이 + 통계량).
4. `md_necessity.md`에 6-시스템 갱신 노트 추가(기존 3-시스템 절 유지, 갱신 사유 명시).
   verify: 신규 GPU-시간 추정치(대략 2배, ~60-160시간 범위) 반영.
5. 결과 문서 + 계약 done.

## Resource budget

- 완전 zero-GPU. 새 디코이 생성은 Task 4와 동일하게 CPU/Biopython만 사용.

## Risks

- regression risk: `build_decoys.py`의 기존 5HXB/6XK9 로직에 영향 없어야 함 — task 2
  verify에서 git diff로 확인.
- integration risk: 없음(독립 파이프라인).
- hidden dependency risk: 9HNE의 mmCIF 파싱이 예상과 다른 residue-id 체계를 쓸 경우
  (예: label_seq_id vs auth_seq_id 불일치) 서열 대응이 깨질 수 있음 — task 1의 서열
  비교에서 이 문제를 먼저 확인하고 넘어간다.

## Rollback

- revert strategy: 이번 계약이 만든 신규 파일만 삭제(기존 phaseB 산출물 불변).
- containment strategy: 다른 슬라이스·Phase A·기존 디코이 2개에 영향 없음.

## Progress Log

- 2026-07-14: /brainstorm 진행. Phase B(BRANCH B) 완료 후 사용자가 B200 서버로 MD를
  옮기는 것을 고려하다가, GPU 쓰기 전에 leave-one-out 알고리즘부터 확정하기로 결정.
  핵심 결정 3가지: (1) cross-glue 일반화 테스트로 재정의, (2) ChronoBridge는
  시스템별 QC 전용, (3) 9HNE 디코이도 지금 만들어 3-fold 완성. 승인 대기.
- 2026-07-14: 사용자 승인("승인"). status: approved. 다음 단계 /write-plan.
- 2026-07-14: /write-plan → /execute-plan 7-task 실행 완료 (commits a4bf6642..7843b84e).
  **결과: DESIGN COMPLETE (zero-GPU).** 서열 검증(CRBN·DDB1은 3개 구조 전부 동일,
  GSPT1은 서열은 동일하나 6XK9 넘버링이 -1 오프셋 — 코디네이터 리뷰에서 방향 오류
  1건 발견·수정: "6XK9 residue N == 5HXB/9HNE residue N-1"이 아니라 반대 방향이
  맞음, 두 곳 모두 정정). 9HNE 지원 추가해 3-fold 디코이 완성(9hne_glue_into_5hxb,
  RMSD 0.602Å/clash 2.310Å) — 5자리 확장 CCD 코드(A1IWG)가 legacy PDB 3자리 필드를
  넘쳐서 출력용 별칭(A1I)으로 우회, 실제 코드는 리포트에 보존. leave-one-out을
  "구조 복원"이 아니라 **FP검출기의 cross-glue 일반화 테스트**로 재정의하고 3-fold
  스펙 확정(calibration=나머지 2개 앙상블, test=held-out 실제+그 fold 디코이,
  통계량은 evaluate.py의 percentile_ci 재사용+2-independent-samples 부트스트랩,
  pass 기준=3-fold 중 2개 이상 CI가 0 배제). Fold C는 디코이 backbone이 9HNE이
  아니라 5HXB(calibration 시스템)라 구조적으로 더 약한 fold임을 명시적으로 문서화
  (평균내지 않고 별도 해석). ChronoBridge는 앙상블별 QC 전용(교차시스템 예측 없음)
  으로 범위 확정. MD 규모 3→6개 시스템(정답 3+디코이 3)으로 갱신, ~60-160 GPU-시간
  (중심값 ~100). `.agent/status/chronobridge.md` 갱신(다음 결정: B200 MD 생성 계약
  승인 여부, 진짜 SLURM/GPU 게이트) + handoff + CURRENT.md 갱신 완료. 상세:
  phaseB/loo_algorithm_results.md. status: done.
