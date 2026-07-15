# Codex Harness Engineering 설계안

## 1. 목적

이 설계안은 발표 자료의 `구조 → 맥락 → 계획 → 실행 → 검증 → 개선` 6축을 Codex 환경에 맞게 재해석한 운영 설계다.

목표는 다음 3가지다.

1. Codex가 저장소 안에서 일관된 방식으로 작업하도록 만든다.
2. 사람은 직접 코드를 많이 치기보다 `환경, 기준, 피드백 루프`를 설계한다.
3. 단발성 프롬프트가 아니라 `반복 가능한 작업 시스템`을 만든다.

---

## 2. Codex에 맞는 핵심 해석

발표 자료의 메시지를 Codex 관점으로 바꾸면 아래와 같다.

- `프롬프트 최적화`보다 `작업 환경 설계`가 성능 차이를 더 크게 만든다.
- Codex는 문서, 테스트, 명령, 구조, 승인 기준이 명확할수록 강해진다.
- Codex는 `AGENTS.md`, 실행 가능한 테스트/린트 명령, 분리된 계획 문서, 작업 격리(worktree), 재현 가능한 검증 루프`가 있을 때 가장 안정적으로 동작한다.
- 긴 작업은 한 번에 시키기보다 `계획 문서 승인 → 구현 → 검증 반복` 구조로 운영해야 한다.
- 생성과 검증은 같은 컨텍스트에 두지 말고 분리해야 한다.

운영 원칙은 한 문장으로 정리할 수 있다.

`Humans steer, Codex executes, the repo verifies.`

---

## 3. 목표 운영 모델

### 3.1 사람의 역할

- 요구사항을 명확히 한다.
- 완료 조건을 먼저 정한다.
- Codex가 읽을 수 있는 형태로 문서와 규칙을 유지한다.
- 병렬 작업이 필요할 때 역할을 분리한다.
- 세션 종료 후 반복 패턴을 추출해 규칙 또는 스킬로 승격한다.

### 3.2 Codex의 역할

- 저장소 구조와 문서에 맞춰 작업한다.
- 큰 일은 먼저 계획으로 분해한다.
- 구현 후 검증 명령을 반드시 실행한다.
- 실패 시 원인과 다음 액션을 남긴다.
- 승인된 범위 안에서만 수정/실행한다.

### 3.3 저장소의 역할

- 아키텍처와 규칙을 Codex가 읽을 수 있게 드러낸다.
- 테스트, 린트, 타입체크, 스모크체크를 자동화한다.
- 작업 기준과 검증 기준을 코드/문서/스크립트로 남긴다.

---

## 4. 권장 리포지토리 구조

```text
repo/
  AGENTS.md
  README.md
  docs/
    product/
    architecture/
    adr/
    runbooks/
    qa/
  .agent/
    PLANS.md
    contracts/
    delegation/
    templates/
    checklists/
    evals/
    handoffs/
    knowledge/
    qa/
    remote/
    skills/
    tools/
  src/
  tests/
  scripts/
    verify.sh
    browser-check.sh
    eval.sh
    knowledge-build.sh
    remote-bootstrap.sh
    remote-verify.sh
    skills-sync.sh
    tool-audit.sh
    smoke.sh
    review.sh
  tools/
  .github/
    workflows/
```

### 4.1 책임 분리

- `docs/`
  - 사람이 유지하는 진실의 원본
  - 제품 요구사항, 도메인 룰, 아키텍처, ADR, 운영 절차
- `.agent/`
  - Codex 작업 시스템
  - 계획 규격, 체크리스트, 계약 템플릿, handoff, eval
- `.agent/checklists/`
  - 변경 규율, 리뷰 기준, 작업 유형별 완료 조건
- `.agent/delegation/`
  - 모델/에이전트별 역할, 위임 기준, 비용·품질 trade-off
- `.agent/evals/`
  - 평가 데이터셋, 실패 분류, judge 검증, 기준 drift 기록
- `.agent/knowledge/`
  - raw 자료, 컴파일된 wiki, graph 리포트, provenance 기록
- `.agent/qa/`
  - Chrome 기반 화면 검증 기준
  - 스크린샷, 상호작용, 접근성, 반응형 체크리스트
- `.agent/remote/`
  - SSH 서버 인벤토리, bootstrap 로그, 원격 실행 정책
- `.agent/skills/`
  - 팀 공용 skill registry, 동기화 정책, 활성 skill 목록
- `.agent/tools/`
  - MCP/외부 도구 인벤토리, 사용량 감사, context budget
- `scripts/`
  - 검증 명령의 표준 진입점
  - Codex가 매번 다른 커맨드를 추측하지 않게 함

핵심은 `사람 문서`와 `에이전트 운영 문서`를 분리하는 것이다.

---

## 5. Codex 하네스의 6개 축

## 5.1 구조 Scaffolding

Codex용 구조의 중심은 `AGENTS.md`다.

`AGENTS.md`에는 최소한 아래가 있어야 한다.

- 저장소 지도
- 주요 폴더 책임
- 필수 검증 명령
- 변경 금지/주의 영역
- 큰 작업에서 `PLANS.md`를 사용해야 하는 조건
- 변경 규율 체크리스트 위치
- PR/커밋/브랜치 규칙
- 사람이 승인해야 하는 작업 조건

### 권장 규칙

- 한 저장소에는 최소 1개의 루트 `AGENTS.md`를 둔다.
- 복잡한 도메인은 하위 디렉토리에 보조 `AGENTS.md` 또는 도메인 문서를 둔다.
- 검증 명령은 문장 설명보다 실행 가능한 스크립트로 둔다.
- Codex가 추측하지 않게 `scripts/verify.sh` 같은 고정 진입점을 만든다.

## 5.2 맥락 Context

Codex에서 맥락은 `많이 주는 것`보다 `정확히 찾게 하는 것`이 중요하다.

### 권장 계층

1. `AGENTS.md`
   - 가장 짧고 강한 운영 규칙
2. `docs/architecture/*`
   - 시스템 구조, 의존성 방향, 핵심 불변식
3. `docs/product/*`
   - 비즈니스 요구사항, 용어, 예외 케이스
4. `.agent/checklists/*`
   - 작업 유형별 기준
5. `.agent/contracts/*`
   - 완료 정의와 승인 조건

### 맥락 원칙

- `AGENTS.md`는 짧게 유지한다. 저장소 지도와 행동 규칙 중심으로 작성한다.
- 긴 설명은 `docs/`나 `.agent/` 문서로 분리하고, `AGENTS.md`에서 참조만 건다.
- 한 문서에 모든 규칙을 넣지 않는다.
- 작업 종류별로 읽을 문서를 명시한다.

예시:

- API 변경 시 `docs/architecture/api.md` 우선 읽기
- 결제 모듈 작업 시 `docs/product/payments.md` 우선 읽기
- UI QA 전 `.agent/qa/browser-checklist.md` 읽기
- 아키텍처/도메인 질문 전 `.agent/knowledge/graphify-out/GRAPH_REPORT.md` 또는 `.agent/knowledge/wiki/index.md` 읽기

### Knowledge Layer

Karpathy의 LLM Wiki와 Graphify에서 가져올 핵심은 `compile once, query many times`이다. Codex가 매번 raw 파일, PDF, 영상, 긴 문서를 다시 읽게 하지 않고, 사람이 신뢰할 수 있는 원본과 에이전트가 탐색하기 쉬운 지식층을 분리한다.

권장 구조:

```text
.agent/knowledge/
  raw/
    sources/
    transcripts/
    screenshots/
  wiki/
    index.md
    concepts/
    decisions/
    flows/
  graphify-out/
    GRAPH_REPORT.md
    graph.json
    graph.html
  provenance.md
```

역할:

- `raw/`
  - 원본 저장소. 직접 수정하지 않는다.
  - PDF, 영상 transcript, 회의록, 외부 문서, 설계 스케치 등.
- `wiki/`
  - Codex가 읽기 쉬운 컴파일된 지식.
  - 개념 페이지, 결정 기록, 흐름 설명, cross-link.
- `graphify-out/`
  - Graphify 같은 도구가 만든 지식 그래프 산출물.
  - 아키텍처 질문 전 `GRAPH_REPORT.md`를 먼저 읽는다.
- `provenance.md`
  - 어떤 wiki/graph 항목이 어떤 raw source에서 나왔는지 기록.

운영 규칙:

- 원본은 `raw/`에만 넣고 직접 편집하지 않는다.
- wiki/graph는 재생성 가능한 산출물로 본다.
- Codex는 큰 탐색을 시작하기 전에 `GRAPH_REPORT.md` 또는 `wiki/index.md`를 먼저 읽는다.
- 추론된 관계는 `inferred`로 표시하고, 원본에서 직접 확인된 관계는 `source-backed`로 표시한다.
- 새 자료를 추가하거나 구조를 크게 바꾼 뒤에는 `scripts/knowledge-build.sh`를 실행한다.

Graphify를 쓸 수 있는 프로젝트라면 기본 명령은 아래처럼 둔다.

```bash
graphify .agent/knowledge/raw --wiki --no-viz
graphify . --update
graphify export callflow-html
```

Graphify를 설치하지 않는 프로젝트도 같은 구조는 유지한다. 이 경우 Codex가 `raw/`를 읽어 `wiki/`와 `provenance.md`를 수동으로 갱신한다.

### Tool Context Budget

Hada archive의 MCP optimizer 사례에서 가져올 핵심은 `도구는 많을수록 좋은 것이 아니라, 필요한 시점에 필요한 것만 로드해야 한다`는 점이다. MCP 서버와 외부 도구는 schema, 설명, 권한 정책만으로도 컨텍스트를 먹고, 안 쓰는 도구가 많아지면 Codex의 주의가 분산된다.

권장 구조:

```text
.agent/tools/
  inventory.md
  context-budget.md
  audit-log.md
  mcp-policy.md
```

운영 규칙:

- 프로젝트별로 실제 필요한 MCP/도구만 활성화한다.
- 자주 쓰지 않는 MCP 도구는 Skill로 감싸서 필요할 때만 읽게 한다.
- 도구 추가 시 `목적, 허용 작업, 금지 작업, 예상 context 비용, 마지막 사용일`을 기록한다.
- 월 1회 `scripts/tool-audit.sh`를 실행해 unused/stale 도구를 찾는다.
- 도구가 작업에 직접 필요하지 않으면 AGENTS.md에 장황하게 설명하지 않는다.

도구 등급:

- `core`: 매 작업에 필요한 도구. 예: shell, rg, git, verify script.
- `project`: 특정 repo에서 자주 필요한 도구. 예: DB schema inspector, internal CLI.
- `on-demand`: 특정 작업에서만 쓰는 도구. Skill이나 runbook으로 노출.
- `disabled`: 설치되어 있어도 기본 컨텍스트에 넣지 않는 도구.

### Skill Supply Chain

Codex Skills는 팀 워크플로를 공유하기에 좋지만, 늘어나면 context pollution과 버전 drift가 생긴다. Skills도 코드처럼 registry, version, sync, deprecation 정책이 필요하다.

권장 구조:

```text
.agent/skills/
  registry.md
  sync-policy.md
  selection.md
skills/
  <skill-name>/SKILL.md
```

운영 규칙:

- 팀 공용 Skills는 repo의 `skills/`를 SSOT로 둔다.
- 개인 실험 Skills와 팀 Skills를 구분한다.
- 모든 Skill은 owner, version, trigger, dependencies, last-reviewed를 가진다.
- 같은 실수가 3번 반복되면 rule/checklist가 우선이고, 같은 workflow가 3번 반복되면 Skill 후보로 올린다.
- 사용량이 낮거나 중복된 Skill은 deprecated로 표시하고 제거한다.
- 자동 동기화는 dry-run과 마지막 성공 상태 보존을 기본값으로 한다.

### Remote SSH Harness

원격 SSH 서버에는 로컬 하네스를 그대로 복사하기보다 `서버 인벤토리, bootstrap, 원격 검증, 터널 기반 QA`를 추가한다. 목표는 Codex가 서버 상태를 추측하지 않고, 매번 같은 순서로 접속, 확인, 실행, 검증하게 만드는 것이다.

권장 구조:

```text
.agent/remote/
  hosts.example.md
  bootstrap-log.md
  runbook.md
  policies.md
scripts/
  remote-bootstrap.sh
  remote-verify.sh
```

역할:

- `hosts.example.md`
  - 서버 alias, 용도, repo 경로, 안전 등급, 접속 전제 조건.
  - 실제 secret, private IP, token은 넣지 않는다.
- `bootstrap-log.md`
  - 서버별 OS, shell, git, Node/Python, package manager, Codex/Graphify 설치 상태 기록.
- `runbook.md`
  - 원격 서버에서 자주 하는 작업 절차.
  - 배포, 로그 확인, 서비스 재시작, 터널링, rollback.
- `policies.md`
  - 원격 서버에서 Codex가 해도 되는 일과 사람이 승인해야 하는 일.

원격 서버 작업 흐름:

1. `ssh <host> 'pwd && uname -a && git --version'`로 기본 상태 확인
2. repo 경로 확인
3. `AGENTS.md`, `.agent/`, `scripts/` 존재 여부 확인
4. 없으면 `scripts/remote-bootstrap.sh <host> <repo-path>`로 하네스 skeleton 동기화
5. 원격에서 `./scripts/verify.sh` 또는 `./scripts/remote-verify.sh <host> <repo-path>` 실행
6. 웹 서버면 `ssh -L` 터널을 열고 로컬 Chrome QA 수행
7. 결과를 `.agent/remote/bootstrap-log.md` 또는 작업 계약서에 기록

원격 승인 게이트:

- production 서비스 재시작
- DB migration 또는 데이터 삭제/수정
- firewall, SSH, systemd, nginx, docker compose 변경
- secret, env, credential 변경
- root 권한 작업
- 외부 네트워크로 데이터 전송

원격에서는 destructive 명령을 더 강하게 제한한다. Codex는 먼저 dry-run, 상태 출력, diff, 로그 수집을 수행하고, 실제 변경은 승인된 범위에서만 한다.

## 5.3 계획 Planning

Codex에서 가장 큰 품질 차이는 `바로 구현`이 아니라 `계획을 먼저 고정`하는 데서 나온다.

### 작업 규율

`andrej-karpathy-skills`에서 가져올 만한 핵심은 도구 자체보다 행동 규칙이다. Codex 하네스에는 이를 `Change Discipline`으로 넣는다.

1. 가정을 드러낸다
   - 모호한 요구사항은 조용히 해석하지 않는다.
   - 가능한 해석이 여러 개면 선택지를 짧게 제시한다.
   - 불명확성이 결과를 크게 바꿀 때는 질문한다.
2. 가장 작은 해법부터 시작한다
   - 요청받지 않은 기능, 설정, 확장 포인트를 넣지 않는다.
   - 단일 사용처를 위해 새 추상화를 만들지 않는다.
   - 구현이 커지면 먼저 더 작은 해법을 찾는다.
3. 변경 범위를 좁힌다
   - 모든 변경 라인은 사용자 요청 또는 검증 실패와 연결되어야 한다.
   - 주변 코드 리팩터링, 포맷 변경, 주석 정리는 별도 요청이 없으면 하지 않는다.
   - 내 변경으로 생긴 unused code는 정리하되, 기존 dead code는 보고만 한다.
4. 목표를 검증 가능하게 바꾼다
   - "고쳐줘"를 "재현 테스트 작성, 수정, 회귀 검증"으로 바꾼다.
   - "추가해줘"를 "성공/실패 조건 테스트, 구현, 검증"으로 바꾼다.
   - 각 구현 단계에는 대응되는 검증 방법이 있어야 한다.

이 규율은 `.agent/checklists/change-discipline.md`에 두고, `AGENTS.md`에서 항상 참조하게 한다.

### 계획 진입 조건

아래 중 하나면 계획 문서를 먼저 만든다.

- 파일 5개 이상 수정 가능성이 높다
- 리팩터링이다
- 도메인 규칙을 건드린다
- UI + 백엔드 + 테스트가 같이 바뀐다
- 30분 이상 걸릴 작업이다
- 병렬 작업이 필요하다

### 계획 문서 규격

`.agent/PLANS.md`는 계획을 어떻게 쓰는지 정의하는 메타 문서다.

실제 작업 계획은 `.agent/contracts/feature-x.md` 같은 파일로 만든다.

각 계획 문서는 아래를 포함한다.

- 목적과 사용자 관점의 변화
- 명시된 가정과 열린 질문
- 현재 상태 요약
- 비목표
- 제약 조건
- 구현 단계
- 단계별 검증 기준
- 검증 방법
- 위험 요소
- 롤백/복구 전략
- 진행 로그

### 운영 규칙

- 사람이 계획을 승인하기 전에는 큰 구현을 시작하지 않는다.
- Codex는 모호하면 먼저 질문하거나 가정을 명시한다.
- 작업 도중 발견한 설계 변경은 계획 문서에 누적한다.

## 5.4 실행 Orchestration

Codex에서는 실행 패턴을 3개로 단순화하는 것이 좋다.

### 패턴 A: Single

적합:

- 단일 파일 수정
- 버그 수정
- 작은 테스트 보강
- 문서 정리

규칙:

- 한 번의 thread/branch/worktree에서 끝낸다.

### 패턴 B: Parallel Workers

적합:

- 프런트/백엔드/테스트가 비교적 독립적
- 여러 후보안 탐색
- 다수 파일군 분석

규칙:

- 각 작업자는 서로 다른 write scope를 가진다.
- 메인 스레드는 통합과 충돌 해소만 한다.
- worktree 단위 격리를 기본값으로 쓴다.

예:

- Worker 1: API 설계 및 핸들러
- Worker 2: UI 변경
- Worker 3: 테스트/검증

### 패턴 C: Generator + Evaluator

적합:

- 실패 비용이 큰 변경
- 보안/성능/릴리즈 위험이 있는 작업
- UI 품질 검증이 필요한 작업

규칙:

- 생성 에이전트와 검증 에이전트는 분리한다.
- 검증 에이전트는 별도 컨텍스트에서 회의적으로 리뷰한다.
- 가능하면 다른 모델 또는 다른 스레드 관점을 사용한다.

### 패턴 D: Cost-Aware Delegation

Hada archive의 `tunaLlama` 사례에서 가져올 핵심은 `분해/검증/통합은 상위 모델에 남기고, 긴 생성/반복 수정은 저비용 실행자에게 위임한다`는 비대칭이다.

적합:

- 대량 코드 생성
- 반복적인 리팩터링
- 긴 파일 리뷰
- boilerplate 변환
- 테스트 케이스 대량 생성

역할:

- `Architect`
  - Codex 또는 고품질 모델
  - 요구사항 분해, spec 작성, acceptance criteria, 최종 판정
- `Developer`
  - 로컬 LLM, 저비용 모델, 또는 별도 worker
  - 코드 생성, 자체 리뷰, 자체 수정
- `Reviewer`
  - Architect와 분리된 컨텍스트
  - 요구사항 충족, diff 범위, 테스트 결과 검증

운영 규칙:

- 위임 입력은 짧은 spec과 제한된 파일 범위로 구성한다.
- 위임 결과는 곧바로 merge하지 않고 `review → fix → max iteration` 루프를 둔다.
- 종료 조건은 `review pass`, `max iteration`, `scope drift`, `verification failure` 중 하나로 명시한다.
- 모든 위임 호출은 `.agent/delegation/log.md`에 기록한다.
- 저비용 실행자는 설계 결정을 하지 않고 구현 후보만 만든다.

이 패턴은 비용 절감보다 품질 안정화가 목적이다. 긴 생성을 분리하면 Codex의 컨텍스트를 계획과 검증에 더 많이 쓸 수 있다.

## 5.5 검증 Verification

Codex용 하네스에서 검증은 `나중 옵션`이 아니라 `작업 정의의 일부`여야 한다.

### 필수 검증 계층

1. 정적 검증
   - format
   - lint
   - typecheck
2. 동작 검증
   - unit test
   - integration test
   - smoke test
3. 변경 목적 검증
   - 이번 작업의 완료 조건이 충족됐는지 확인
4. 독립 리뷰
   - 생성자와 다른 컨텍스트에서 리뷰

### Eval Harness

Hada archive의 eval 관련 글에서 가져올 핵심은 `하네스의 큰 부분은 데이터 과학`이라는 점이다. 테스트와 리뷰만으로는 부족하고, 실패 데이터를 보고, 지표를 좁게 정의하고, judge를 검증해야 한다.

권장 구조:

```text
.agent/evals/
  eval-plan.md
  dataset.jsonl
  failure-taxonomy.md
  judge-calibration.md
  criteria-drift.md
  reports/
scripts/
  eval.sh
```

운영 규칙:

- 범용 점수보다 애플리케이션 특화 pass/fail 기준을 쓴다.
- "도움됨", "품질 좋음" 같은 모호한 judge 질문을 피한다.
- production trace, 실제 버그, 리뷰 지적, 사용자 피드백에서 eval case를 수집한다.
- LLM judge를 쓰면 인간 라벨 샘플로 precision/recall을 확인한다.
- test set, dev set, examples를 분리한다.
- 기준이 바뀌면 `.agent/evals/criteria-drift.md`에 기록한다.
- eval 자동화가 데이터 직접 보기와 오류 분류를 대체하지 못한다.

Eval case 최소 필드:

- `id`
- `source`
- `input`
- `expected_behavior`
- `failure_mode`
- `acceptance_check`
- `owner`
- `last_reviewed`

완료 보고에는 테스트 통과 여부뿐 아니라, 어떤 실패 분류가 줄었는지와 새로 발견한 실패 분류를 남긴다.

### Codex용 Sprint Contract 템플릿

작업 시작 전에 아래를 고정한다.

- 산출물
- 수정 가능 범위
- 수정 금지 범위
- 통과해야 할 명령
- 사람이 직접 확인할 항목
- 실패 시 중단 기준

예:

- 산출물: 결제 실패 재시도 로직 추가
- 수정 가능 범위: `src/payments/**`, `tests/payments/**`
- 수정 금지 범위: DB schema, infra, public API
- 통과 명령: `./scripts/verify.sh payments`
- 사람 확인: 운영 정책 문구 변경 여부
- 중단 기준: 기존 결제 성공 경로 회귀 발생

### UI/브라우저 검증

웹/앱 변경은 코드만 보면 부족하다.

권장 루프:

1. Codex가 구현
2. 테스트/빌드 실행
3. 브라우저 또는 컴퓨터 사용 도구로 실제 화면 확인
4. 스크린샷/관찰 결과 기반 수정
5. 완료 기준 충족 시 종료

### Chrome QA Harness

Chrome은 Codex 하네스에서 `눈이 달린 검증자` 역할을 한다. 코드 검증이 "실행 가능한가"를 본다면, Chrome 검증은 "사용자가 실제로 쓸 수 있는가"를 본다.

Chrome QA는 아래 작업에 필수로 붙인다.

- 웹 UI 변경
- 랜딩 페이지/대시보드/폼/테이블 변경
- 로그인, 결제, 가입, 검색 같은 핵심 플로우 변경
- 반응형 레이아웃 변경
- 스타일 시스템 또는 컴포넌트 변경
- 접근성/키보드 조작 관련 변경

검증 기준은 `.agent/qa/browser-checklist.md`에 둔다.

Chrome QA 루프:

1. 로컬 서버 실행
2. Chrome으로 대상 URL 열기
3. 데스크톱 뷰포트에서 핵심 화면 확인
4. 모바일 폭에서 레이아웃 확인
5. 핵심 상호작용 클릭/입력/전환 확인
6. 콘솔 에러, 깨진 이미지, 겹친 텍스트, 잘린 버튼 확인
7. 실패 시 수정 후 같은 루프 반복

완료 보고에는 아래를 남긴다.

- 확인한 URL
- 확인한 뷰포트
- 수행한 사용자 플로우
- 발견한 문제와 수정 여부
- 남은 수동 확인 항목

Chrome QA를 자동화할 때는 `scripts/browser-check.sh`를 표준 진입점으로 둔다. Playwright 같은 코드 기반 브라우저 검증이 있으면 이 스크립트에 연결하고, 없으면 Codex가 Chrome/Computer Use로 수동 시각 검증을 수행한다.

## 5.6 개선 Compounding

좋은 Codex 하네스는 문서와 규칙이 계속 늘어나는 시스템이 아니라, `필요한 규칙만 남는 시스템`이다.

### 개선 규칙

- 같은 실수가 3번 나오면 `AGENTS.md` 또는 체크리스트로 승격
- 같은 작업이 3번 반복되면 Skill 또는 스크립트로 승격
- 안 쓰는 규칙/스킬/스크립트는 삭제
- 세션 종료 후 `무엇이 반복됐는지`를 남긴다

### 추천 운영 로그

`.agent/handoffs/` 또는 `.agent/retros/`에 짧게 남긴다.

- 무엇이 막혔는가
- 어떤 문서가 부족했는가
- 어떤 검증이 없어서 사람이 개입했는가
- 무엇을 자동화 후보로 올릴 것인가

---

## 6. Codex용 핵심 파일 설계

## 6.1 `AGENTS.md`

루트 `AGENTS.md`는 아래 구조를 추천한다.

```md
# Repository Guide

## Purpose
짧은 제품/서비스 설명

## Map
- `src/`: product code
- `tests/`: verification
- `docs/product/`: business truth
- `docs/architecture/`: architecture and invariants
- `.agent/`: Codex operating artifacts

## Operating Rules
- Read this file before planning or editing.
- Follow `.agent/checklists/change-discipline.md` before non-trivial edits.
- For complex work, create or update a plan under `.agent/contracts/`.
- Do not edit infra/schema unless explicitly allowed.
- Prefer changing existing patterns over inventing new abstractions.

## Required Verification
- `./scripts/verify.sh`
- task-specific command when relevant

## When To Use A Plan
- multi-file change
- refactor
- domain rule change
- work expected to exceed 30 minutes

## Approval Gates
- schema change
- external side effects
- secret/config rotation
- destructive operations
```

핵심은 `Codex가 어떻게 일해야 하는지`를 짧고 강하게 적는 것이다.

## 6.2 `.agent/PLANS.md`

이 문서는 계획 작성 규격이다.

반드시 포함할 것:

- 목적
- 사용자 가치
- 현재 상태
- 목표 상태
- 단계별 구현 순서
- 검증 계획
- 리스크
- 로그

권장 규칙:

- 계획은 살아있는 문서로 유지
- 구현 중 발견 사항을 계속 반영
- 재시작 시 계획 문서만 읽어도 이어서 진행 가능해야 함

## 6.3 `.agent/contracts/*.md`

실제 태스크별 계약서다.

예:

- `.agent/contracts/payment-retry.md`
- `.agent/contracts/admin-search-refactor.md`
- `.agent/contracts/mobile-responsive-fix.md`

각 문서에는 아래 3개가 꼭 있어야 한다.

- `Done when`
- `Do not change`
- `Verification`
- `Assumptions`
- `Step-by-step checks`

## 6.4 `scripts/verify.sh`

이 스크립트는 하네스의 핵심이다.

역할:

- 포맷/린트/타입체크/테스트를 한 진입점으로 묶는다.
- Codex가 저장소마다 검증 명령을 추측하지 않게 만든다.
- CI와 로컬을 최대한 일치시킨다.

## 6.5 `scripts/knowledge-build.sh`

이 스크립트는 raw 자료를 Codex가 탐색 가능한 지식층으로 바꾸는 표준 진입점이다.

역할:

- `.agent/knowledge/raw/`의 새 자료를 감지한다.
- Graphify가 있으면 graph/wiki를 갱신한다.
- Graphify가 없으면 수동 갱신이 필요하다는 메시지를 남긴다.
- 갱신 후 `GRAPH_REPORT.md`, `wiki/index.md`, `provenance.md` 중 무엇이 바뀌었는지 확인한다.

운영 기준:

- 아키텍처 변경 후 실행
- 긴 외부 문서, 영상 transcript, 회의록 추가 후 실행
- 온보딩/리서치 문서가 늘어난 뒤 실행
- 월 1회 이상 stale knowledge 점검

## 6.6 `scripts/eval.sh`

AI behavior, 검색, 추천, RAG, 에이전트 판단, 중요 UX copy를 바꾸는 작업의 평가 진입점이다.

역할:

- `.agent/evals/dataset.jsonl` 기반 회귀 평가 실행
- 실패 유형별 pass/fail 집계
- judge prompt 또는 자동 평가가 있으면 calibration 상태 확인
- 새 실패 사례를 `.agent/evals/failure-taxonomy.md`에 추가하도록 안내

`eval.sh`는 범용 "품질 점수"를 내는 도구가 아니라, 애플리케이션 특화 실패를 추적하는 도구다.

## 6.7 `scripts/tool-audit.sh`

MCP, plugin, CLI, Skill 같은 도구의 context 비용과 사용 여부를 점검하는 진입점이다.

역할:

- `.agent/tools/inventory.md`의 도구 목록 확인
- 마지막 사용일과 owner 없는 도구 탐지
- core/project/on-demand/disabled 등급 확인
- 안 쓰는 MCP는 disabled 또는 Skill 전환 후보로 표시

## 6.8 `scripts/skills-sync.sh`

팀 Skills를 최신 상태로 맞추는 진입점이다.

역할:

- `skills/`를 팀 공용 SSOT로 관리
- `.agent/skills/registry.md`와 실제 skill 폴더의 불일치 탐지
- dry-run으로 추가/삭제/변경 예정 항목 출력
- 마지막 성공 상태를 보존해 실패 시 기존 Skills를 유지

## 6.9 `scripts/remote-bootstrap.sh` / `scripts/remote-verify.sh`

원격 서버용 표준 진입점이다.

`remote-bootstrap.sh` 역할:

- SSH 접속 가능 여부 확인
- 원격 repo 경로 확인
- `AGENTS.md`, `.agent/`, `scripts/` skeleton 동기화
- 서버 환경 정보를 `.agent/remote/bootstrap-log.md`에 기록
- 위험한 변경 없이 read-only 상태 점검부터 수행

`remote-verify.sh` 역할:

- 원격 repo에서 `./scripts/verify.sh` 실행
- OS, git status, branch, dependency 상태 출력
- 실패 로그를 로컬에서 읽기 쉬운 형태로 요약
- 웹 서비스면 터널링 후 Chrome QA로 이어갈 URL을 안내

원격 스크립트는 secret을 인자로 받지 않는다. 접속 정보는 SSH config alias를 사용하고, 비밀값은 서버의 기존 secret manager 또는 환경에 맡긴다.

## 6.10 팀 공용 Skills

Codex app의 Skills는 `반복 작업 레시피`에 집중하는 게 맞다.

추천 스킬 목록:

- `repo-bootstrap`
  - AGENTS.md/PLANS.md/checklists 초안 생성
- `exec-plan`
  - 복잡한 요구사항을 계획 문서로 변환
- `change-discipline`
  - 구현 전 가정, 단순성, 변경 범위, 검증 가능성을 점검
- `knowledge-ingest`
  - raw 자료를 wiki/graph/provenance로 컴파일하고 오래된 지식을 점검
- `remote-harness`
  - SSH 서버에 하네스 skeleton을 설치하고 원격 검증/터널 QA 흐름을 설정
- `eval-harness`
  - 실패 taxonomy, eval dataset, judge calibration을 관리
- `tool-budget`
  - MCP/도구 context 비용을 감사하고 on-demand 전환 후보를 찾음
- `skills-governance`
  - 팀 Skills registry, sync, deprecation을 관리
- `delegation-manager`
  - Architect/Developer/Reviewer 역할 분리와 bounded delegation을 운영
- `review-skeptical`
  - 버그/회귀/테스트 누락 중심 검토
- `ui-qa`
  - Chrome 실행 후 화면 캡처와 점검 루프 수행
- `handoff-writer`
  - 현재 상태와 다음 액션을 짧게 정리

원칙:

- 스킬은 범용 지식이 아니라 `반복되는 팀 작업 방식`을 캡슐화해야 한다.

---

## 7. Codex 멀티에이전트 설계

Codex app은 여러 에이전트를 병렬로 운영하고 worktree로 격리하는 데 강점이 있다. 따라서 아래처럼 역할을 고정해두는 것이 좋다.

### 기본 역할 세트

- `Planner`
  - 요구사항 정리, 질문 생성, 계획 문서 작성
- `Builder`
  - 구현 담당
- `Verifier`
  - 테스트/리뷰/회귀 확인
- `UI QA`
  - Chrome으로 화면/상호작용/반응형 확인

### 기본 흐름

1. Planner가 `.agent/contracts/*.md` 작성
2. 사람이 승인
3. Builder가 worktree에서 구현
4. Verifier가 별도 컨텍스트에서 리뷰 및 검증
5. 필요 시 UI QA가 Chrome으로 실제 화면 점검
6. 실패 시 계약 문서 기준으로 반복

### 멀티에이전트 원칙

- 한 에이전트당 하나의 책임
- write scope 겹치지 않기
- 검증자는 생성자의 컨텍스트를 그대로 재사용하지 않기
- 병렬화는 구현보다 `탐색/분석/검증`에서 먼저 적용

---

## 8. 안전 설계

Codex 하네스는 자유도를 주되, 치명적 작업만 강하게 제한하는 쪽이 좋다.

### 기본 안전장치

- `main` 직접 작업 금지
- worktree 또는 feature branch 기본 사용
- destructive 명령은 승인 전 실행 금지
- 배포/외부 발송/실데이터 변경은 dry-run 또는 미리보기 우선
- 비밀값/운영 설정은 명시 승인 전 수정 금지

### Deterministic Gates

Hada archive의 hook 사례에서 가져올 핵심은 `프롬프트로 부탁하는 규칙`과 `항상 실행되는 시스템 규칙`을 분리해야 한다는 점이다. Codex 환경에서는 hook이 없더라도 scripts, CI, pre-commit, remote policy로 같은 역할을 만든다.

Gate 후보:

- `scripts/verify.sh`: 모든 변경 후 기본 gate
- `scripts/eval.sh`: AI/검색/추천/에이전트 behavior 변경 gate
- `scripts/browser-check.sh`: UI 변경 gate
- `scripts/tool-audit.sh`: MCP/도구 설정 변경 gate
- `scripts/remote-verify.sh`: SSH 서버 변경 gate
- CI required check: merge 전 최종 gate

Gate 설계 원칙:

- 실패 메시지는 Codex가 바로 고칠 수 있게 구체적으로 쓴다.
- 금지 규칙은 문서만 두지 말고 스크립트나 CI로 강제한다.
- 위험 파일과 명령은 allowlist 방식으로 관리한다.
- gate 자체가 위험한 명령을 실행하지 않게 한다.

### 승인 게이트 목록

- DB schema 변경
- 외부 API 계약 변경
- 인프라/배포 파이프라인 수정
- 삭제성 마이그레이션
- 대량 파일 이동/삭제

---

## 9. 도입 우선순위

한 번에 다 하지 말고 아래 순서로 도입하는 것을 권장한다.

### 1단계

- 루트 `AGENTS.md`
- `docs/` 정리
- `scripts/verify.sh`

### 2단계

- `.agent/PLANS.md`
- `.agent/contracts/` 템플릿
- 작업 유형별 체크리스트

### 3단계

- Codex Skills 2~3개
- worktree 기반 병렬 운영
- 생성자/검증자 분리

### 4단계

- Chrome UI QA 자동화
- 세션 회고 자동화
- 반복 실수의 규칙화

---

## 10. 바로 쓸 수 있는 운영 정책

아래 정책을 기본값으로 추천한다.

### 정책 A. 큰 일은 무조건 계획 먼저

- 구현보다 계획 문서 승인 우선

### 정책 B. 검증 명령 없는 작업은 완료가 아님

- 테스트/검증 진입점이 없으면 먼저 만든다

### 정책 C. 생성과 검증을 분리

- 작성자와 리뷰어를 분리한다

### 정책 D. 사람이 직접 코드를 쓰는 대신 시스템을 고친다

- 같은 문제가 반복되면 문서/규칙/스크립트/스킬을 고친다

### 정책 E. 하네스는 단순해져야 한다

- 안 쓰는 규칙과 스킬은 지운다

---

## 11. 추천 KPI

Codex 하네스가 좋아지고 있는지 보려면 아래를 측정한다.

- 작업당 평균 재요청 횟수
- 검증 실패 후 수정 루프 횟수
- 사람 개입이 필요한 비율
- 반복되는 리뷰 지적 수
- 요청과 직접 연결되지 않는 diff 비율
- 새 추상화가 실제로 재사용된 비율
- 계획 문서 없이 시작한 작업의 실패율
- 새 기능당 테스트 추가 비율
- UI 변경당 Chrome QA 수행 비율
- Chrome QA에서 발견된 회귀 수
- eval dataset에 추가된 실제 실패 사례 수
- judge calibration precision/recall
- tool inventory 중 unused/on-demand 비율
- Skill registry와 실제 설치 상태 drift 수
- delegation 작업의 review pass율과 max-iteration 도달률
- 세션 종료 후 규칙/스킬로 승격된 패턴 수

---

## 12. 최종 제안

Codex용 하네스는 아래 한 줄로 설계하면 된다.

`AGENTS.md를 허브로 두고, 큰 일은 PLANS.md 기반 계약 문서로 고정하고, 구현과 검증을 분리하고, 검증 명령을 스크립트로 표준화하고, 반복 패턴은 Skill로 승격한다.`

이 구성이 발표 자료의 핵심을 Codex에 가장 자연스럽게 옮긴 형태다.

추가로 실제 도입까지 이어가려면 다음 산출물을 바로 만들면 된다.

1. 저장소용 `AGENTS.md`
2. `.agent/PLANS.md`
3. `.agent/contracts/_template.md`
4. `scripts/verify.sh`
5. 팀 공용 Skill 2개 (`exec-plan`, `review-skeptical`)
