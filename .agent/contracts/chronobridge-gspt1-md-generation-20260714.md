---
status: approved
slice: chronobridge
topic: gspt1-md-generation
date: 2026-07-14
owner: claude
approved_by: sunghoon.kim (2026-07-14, "진행")
requested: 2026-07-14
cross_slice: []
triggers_matched:
  - "4개 파일 이상 수정 (예상) — 6개 시스템 × (토폴로지+솔베이션+이온화+mdp×3단계) +
     글루 3종 파라미터화 + 패키징 스크립트 + README"
  - "실행 환경이 이 워크스페이스 밖(B200, 접근 불가) — 표준 SLURM 승인 게이트가
     적용 안 되는 대신, '이 계약이 실제로 뭘 검증할 수 있는가'를 명시적으로
     한정해야 하는 특수 케이스"
---

# chronobridge — GSPT1 6-system MD 패키지 준비 (B200 실행용)

## Purpose

`chronobridge-gspt1-loo-algorithm-20260714`(DESIGN COMPLETE)에서 확정한 3-fold
leave-one-out 분석은 6개 시스템(정답 3: 5HXB/6XK9/9HNE + 디코이 3)의 MD 앙상블이
있어야 실행 가능하다. 실제 MD는 사용자가 **B200 GPU 서버**(이 세션이 접근 불가,
파일은 사용자가 scp/rsync로 직접 옮김, 이 워크스페이스의 SLURM과 무관)에서 돌린다.

Claude의 역할은 "MD를 제출"하는 게 아니라 — 접근 권한이 없어 물리적으로 불가능 —
**여기서 실행 가능한 만큼 준비해서 사용자가 B200에 그대로 복사해 `gmx mdrun`만
돌리면 되는 패키지를 만드는 것**이다. 사용자 확인(2026-07-14, AskUserQuestion):
(1) 토폴로지/솔베이션/이온화까지 전부 여기서 GROMACS로 빌드, (2) 결과 회수 후
분석 흐름은 트라젝토리 경로/매니페스트를 받은 뒤 그때 판단(지금 확정 안 함).

## Current State

- 6개 시작 구조 확보 완료: `.agent/scratch/chronobridge/phaseB/pdb/{5HXB.pdb,
  6XK9.pdb,9HNE.cif}` + `.agent/scratch/chronobridge/phaseB/decoys/{
  6xk9_glue_into_5hxb_backbone.pdb, 5hxb_glue_into_6xk9_backbone.pdb,
  9hne_glue_into_5hxb_backbone.pdb}`.
- 이 워크스페이스 `mmgbsa` conda 환경에 GROMACS 2025.4(conda-forge, CUDA 빌드)와
  AMBER/GAFF 계열 리간드 파라미터화 도구 체인(acpype, antechamber, parmchk2,
  tleap, parmed, rdkit)이 이미 설치되어 있음(확인 완료, 2026-07-14). mmgbsa
  슬라이스가 이미 단백질+리간드 삼원복합체 MD를 이 도구로 돌린 전례가 있으므로
  (`.agent/status/mmgbsa.md`), 그 레시피를 재사용/차용하는 것이 우선순위 — 처음부터
  새로 만들지 않는다.
- 로컬(이 워크스페이스) A100 드라이버: 535.129.03 / CUDA 12.2 (확인 완료). B200은
  훨씬 최신 아키텍처(Blackwell)라 드라이버/CUDA 버전 요구사항이 다를 수 있음 —
  이 계약은 B200 자체의 호환성을 검증할 수 없음(접근 불가), 패키지에 버전 정보를
  명확히 남겨 사용자가 B200 쪽에서 직접 확인하도록 한다.
- 글루 3종(85C/CC-885, V4M/CC-90009, A1IWG/Compound-1, 9HNE 디코이는 A1IWG 그대로
  운반)은 표준 아미노산이 아니라 GROMACS 표준 힘장이 모르는 분자 — 각각 파라미터화
  (전하 계산 + GAFF2 원자유형 할당)가 필요하다.

## Assumptions And Questions

- assumptions: mmgbsa의 기존 리간드 파라미터화 스크립트/레시피가 이번 3개 글루에도
  큰 수정 없이 적용 가능하다(구조가 유사한 CRBN glue 화합물이므로) — task 1에서
  실제 확인.
- open questions:
  - B200에 최종적으로 뭐가 깔릴지(GROMACS 버전, CUDA 버전)는 이 계약이 끝나도
    모른다 — 패키지에 "이 버전으로 빌드했다"는 메타데이터만 남기고, 실제 호환성
    문제는 사용자가 B200에서 마주쳤을 때 대응.
  - 결과 회수 후 분석(leave-one-out 통계 적용)은 이번 계약 범위 밖 — 트라젝토리가
    돌아오면 그때 새 계약으로 스코핑.
- tradeoffs: 로컬에서 정밀하게 빌드해둘수록 B200에서 사용자가 겪을 마찰이 줄지만,
  이 세션은 B200에서 실제 `gmx mdrun`이 도는지 검증할 수 없다(구조적 한계, 우회
  불가). 이 계약의 "완료"는 "여기서 검증 가능한 데까지 grompp까지 통과시켰다"는
  뜻이지 "B200에서 확실히 돌아간다"는 보장이 아니다 — Done When에서 이 한계를
  명시한다.

## Constraints

- allowed change scope: `.agent/scratch/chronobridge/phaseB/md_package/`(신규,
  이 계약의 모든 산출물). mmgbsa 슬라이스의 기존 스크립트는 **참고/복사**만 하고
  원본은 수정하지 않는다(다른 슬라이스 소유 코드).
- forbidden change scope: 이 워크스페이스 SLURM에 어떤 잡도 제출하지 않는다
  (B200은 이 SLURM과 무관 — 애초에 여기 sbatch로 낼 수 있는 대상이 아니다). 만약
  패키지 검증 차원에서 이 클러스터의 A100으로 짧은 smoke MD를 돌려보고 싶다면,
  그건 이번 계약과 별개로 사용자에게 명시적으로 물어보고 진행한다(WORKFLOW.md §3,
  자동으로 하지 않음).
- external constraints: GPU 예산 자체(B200에서 쓸 ~100 GPU-시간)는 이 세션이
  소비하지 않음 — 이 계약은 CPU 전용(GROMACS 시스템 빌드는 grompp까지 GPU 불필요).

## Non-Goals

- 실제 MD 실행(B200, 사용자가 직접) — 범위 밖.
- leave-one-out 통계 분석 적용 — 트라젝토리 회수 후 별도 계약.
- B200 자체의 환경 설치/디버깅(사용자가 직접, 이 세션은 접근 불가) — 이 계약은
  "필요한 게 뭔지" 문서화까지만.
- 이 워크스페이스 A100으로 실제 프로덕션 MD를 대신 돌리는 것(그러면 B200을 쓸
  이유가 없어짐) — 오직 옵션으로 언급되는 "짧은 smoke 검증"만 별도 승인하에 고려.

## Done When

- mmgbsa의 기존 리간드 파라미터화/시스템 빌드 레시피를 확인하고, 이번 3개 글루에
  적용 가능한지 검증(적용 안 되면 최소 수정으로 대응, 문서화).
- 글루 3종(85C, V4M, A1IWG) 전부 GAFF2 파라미터화 완료(전하+원자유형), 파일로
  보존.
- 6개 시스템(5HXB/6XK9/9HNE 정답 3 + 디코이 3) 전부 토폴로지+솔베이션+이온화
  완료, 각 시스템의 에너지최소화+평형화(NVT/NPT, ~1-2ns)+생산(~20-30ns) mdp 파일
  준비.
- **로컬에서 검증 가능한 한계까지 확인**: 각 시스템에 대해 `gmx grompp`가 에러
  없이 `.tpr`을 생성하는지 확인(CPU만 필요, GPU 불필요) — 이것이 "실행 가능한
  시스템"의 최선의 로컬 증거다. `gmx mdrun`을 실제로 돌려보는 것(설령 몇 스텝만)은
  이 계약 범위 밖(위 Constraints) — 사용자가 별도로 원하면 그때 승인받아 진행.
- 패키지화: `.tar.gz` 하나로 6개 시스템의 `.top`/`.gro`/(가능하면)`.tpr`/mdp
  파일 전부 + README(B200에서 실행할 정확한 명령어, 빌드에 쓴 GROMACS/CUDA
  버전, 각 시스템의 예상 실행시간/GPU-시간 추정치 재확인).
- 결과 문서 + 계약 done.

## Implementation Steps

1. mmgbsa의 기존 리간드 파라미터화 스크립트/워크플로 확인(`.agent/status/mmgbsa.md`,
   관련 스크립트 경로 탐색). verify: 재사용 가능한 스크립트/함수 목록 + 이번
   3개 글루에 필요한 조정 사항 문서화.
2. 글루 3종 GAFF2 파라미터화(acpype/antechamber, mmgbsa 레시피 재사용). verify:
   각 글루의 `.itp`/전하 파일 생성 확인.
3. 6개 시스템 토폴로지 빌드(단백질 3체인 + 글루 + Zn, `gmx pdb2gmx` 또는 동등).
   verify: 토폴로지 파일 생성, 원자수 sanity check(사전 확인한 체인별 잔기수와
   일치).
4. 솔베이션+이온화(6개 시스템 전부). verify: 각 시스템 중성 전하 확인.
5. mdp 파일 준비(최소화/평형화/생산, 3세트 × 6시스템 또는 공유 템플릿 + 시스템별
   파라미터). verify: mdp 파일 존재, 파라미터가 md_necessity.md의 추정(20-30ns
   생산 등)과 일치.
6. 각 시스템 `gmx grompp` 실행해 `.tpr` 생성 확인(CPU only). verify: 6/6 성공,
   경고/에러 로그 확인.
7. 패키징(tar.gz) + README 작성(B200 실행 명령어, 버전 정보, GPU-시간 추정 재확인).
   verify: 압축 파일 존재, README에 정확한 명령어 포함.
8. 결과 문서 + 계약 done.

## Resource budget

- CPU 전용(GROMACS 시스템 빌드/grompp는 GPU 불필요). 이 세션에서 GPU 예산 소비
  없음. B200에서 쓸 ~100 GPU-시간은 사용자가 직접 관리.

## Risks

- regression risk: mmgbsa 슬라이스의 원본 스크립트 미수정(복사/참고만) — 다른
  슬라이스에 영향 없음.
- integration risk: 없음.
- hidden dependency risk: B200의 실제 GROMACS/CUDA 버전이 여기서 빌드한 것과
  호환 안 될 가능성(Blackwell은 최신 아키텍처라 드라이버/CUDA 요구사항이 이
  워크스페이스 A100(CUDA 12.2)보다 높을 수 있음) — 이 계약이 해소할 수 없는
  리스크, README에 버전 정보를 명확히 남겨 사용자가 B200 쪽에서 확인하도록
  위임한다.

## Rollback

- revert strategy: `.agent/scratch/chronobridge/phaseB/md_package/` 삭제.
  공유 상태 변경 없음.
- containment strategy: 다른 슬라이스·Phase A/B 산출물·기존 디코이에 영향 없음.

## Progress Log

- 2026-07-14: /brainstorm 진행. 사용자가 B200에서 실제 MD를 돌릴 것을 재확인
  (Claude는 B200에 접근 불가 — 두 번째 명시적 확인). 핵심 결정 2가지: (1) 토폴로지
  /솔베이션/이온화까지 이 워크스페이스에서 GROMACS로 전부 빌드(mmgbsa 환경의
  GAFF2 도구체인 확인 완료), (2) 결과 회수 후 분석 흐름은 트라젝토리 경로를 받은
  뒤 그때 결정. 승인 대기.
- 2026-07-14: 사용자 승인("진행"). status: approved. 다음 단계 /write-plan.
