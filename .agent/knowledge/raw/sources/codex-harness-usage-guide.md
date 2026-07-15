# Codex Harness Usage Guide

이 문서는 Codex 하네스를 실제 프로젝트에서 효과적으로 쓰기 위한 운영 가이드다.

목표는 단순하다.

`작업 전에는 맥락과 기준을 고정하고, 작업 중에는 범위를 좁히고, 작업 후에는 검증과 학습을 남긴다.`

---

## 1. 처음 적용할 때

### 1.1 최소 도입

처음부터 모든 레이어를 쓰지 않는다. 아래 4개만 먼저 적용한다.

```text
AGENTS.md
.agent/PLANS.md
.agent/contracts/_template.md
scripts/verify.sh
```

최소 도입 후 Codex에게 이렇게 요청한다.

```text
이 repo의 AGENTS.md와 .agent/PLANS.md를 읽고, 현재 프로젝트에 맞지 않는 규칙이나 빠진 검증 명령을 찾아서 수정해줘.
```

### 1.2 팀 도입

팀에서 쓸 때는 아래를 추가한다.

```text
.agent/checklists/change-discipline.md
.agent/qa/browser-checklist.md
.agent/skills/registry.md
.agent/tools/inventory.md
```

팀 도입의 목적은 개인 습관을 문서화하는 것이 아니라, 반복되는 실수와 반복되는 작업을 repo 안에 고정하는 것이다.

---

## 2. 일상 작업 흐름

## 2.1 작은 작업

작은 버그 수정, 단일 파일 변경, 작은 문서 수정은 아래 순서로 한다.

1. `AGENTS.md` 확인
2. `.agent/checklists/change-discipline.md` 확인
3. 수정
4. `./scripts/verify.sh`
5. 결과 보고

Codex에게 줄 프롬프트:

```text
AGENTS.md와 change-discipline을 따르면서 이 버그를 최소 범위로 고쳐줘.
수정 후 ./scripts/verify.sh를 실행하고 결과를 보고해줘.
```

## 2.2 큰 작업

리팩터링, 기능 추가, 여러 파일 변경, 도메인 규칙 변경은 계약서를 먼저 만든다.

1. `.agent/contracts/<task>.md` 작성
2. 목적, 가정, 비목표, 범위, 완료 조건 고정
3. 사람이 승인
4. 구현
5. 검증
6. 계약서에 진행 로그 업데이트

Codex에게 줄 프롬프트:

```text
이 작업은 큰 변경이니 바로 구현하지 말고 .agent/contracts/<task>.md 계획부터 작성해줘.
가정, 비목표, 수정 가능 범위, 금지 범위, 단계별 검증 기준을 포함해줘.
```

## 2.3 완료 보고

완료 보고에는 항상 아래를 포함한다.

- 무엇을 바꿨는가
- 무엇은 의도적으로 건드리지 않았는가
- 어떤 검증을 실행했는가
- 실패가 남아 있다면 왜 남았는가
- 다음에 rule, checklist, skill로 승격할 만한 반복 패턴이 있는가

---

## 3. 상황별 사용법

## 3.1 UI 변경

UI 변경은 코드 검증만으로 완료하지 않는다.

사용 파일:

```text
.agent/qa/browser-checklist.md
scripts/browser-check.sh
```

흐름:

1. `./scripts/verify.sh`
2. `./scripts/browser-check.sh`
3. Chrome으로 실제 화면 확인
4. desktop/mobile 뷰포트 확인
5. 클릭, 입력, 전환 확인
6. 콘솔 에러와 깨진 레이아웃 확인

Codex에게 줄 프롬프트:

```text
UI 변경 후 browser-checklist 기준으로 Chrome QA까지 수행해줘.
확인한 URL, 뷰포트, 플로우, 발견한 문제를 보고해줘.
```

## 3.2 AI behavior, RAG, 검색, 추천 변경

이 작업은 테스트만으로 충분하지 않다. eval case를 남긴다.

사용 파일:

```text
.agent/evals/eval-plan.md
.agent/evals/dataset.jsonl
.agent/evals/failure-taxonomy.md
.agent/evals/judge-calibration.md
scripts/eval.sh
```

흐름:

1. 실제 실패 사례 확인
2. failure mode 분류
3. `dataset.jsonl`에 case 추가
4. `./scripts/eval.sh`
5. 기준 변경이 있으면 `criteria-drift.md` 기록

Codex에게 줄 프롬프트:

```text
이 변경은 AI behavior에 영향을 주니까 eval-harness 방식으로 처리해줘.
실패 taxonomy를 먼저 확인하고 dataset.jsonl에 최소 1개 회귀 케이스를 추가해줘.
```

## 3.3 아키텍처/도메인 탐색

raw 문서를 매번 뒤지지 않는다. 먼저 knowledge layer를 본다.

사용 파일:

```text
.agent/knowledge/wiki/index.md
.agent/knowledge/graphify-out/GRAPH_REPORT.md
.agent/knowledge/provenance.md
scripts/knowledge-build.sh
```

흐름:

1. `wiki/index.md` 또는 `GRAPH_REPORT.md` 확인
2. source backing이 필요한 주장은 `provenance.md` 확인
3. 새 raw 자료가 생기면 `./scripts/knowledge-build.sh`
4. 추론은 `inferred`, 원본 근거는 `source-backed`로 표시

Codex에게 줄 프롬프트:

```text
이 질문은 아키텍처 탐색이니까 raw 검색 전에 knowledge index와 provenance를 먼저 확인해줘.
근거가 source-backed인지 inferred인지 구분해서 답해줘.
```

## 3.4 원격 SSH 서버 작업

원격 서버는 기본적으로 read-only에서 시작한다.

사용 파일:

```text
.agent/remote/policies.md
.agent/remote/hosts.example.md
.agent/remote/runbook.md
scripts/remote-bootstrap.sh
scripts/remote-verify.sh
```

흐름:

1. SSH alias와 repo path 확인
2. `.agent/remote/policies.md` 확인
3. read-only 상태 점검
4. 필요하면 `./scripts/remote-bootstrap.sh <alias> <repo-path>`
5. 작업 후 `./scripts/remote-verify.sh <alias> <repo-path>`
6. 웹앱이면 SSH tunnel 후 Chrome QA

Codex에게 줄 프롬프트:

```text
원격 서버 작업이니 remote policies를 먼저 읽고 read-only 점검부터 해줘.
변경이 필요하면 실행 전 어떤 명령을 실행할지 먼저 설명해줘.
```

## 3.5 MCP, plugin, tool 추가

도구는 많을수록 좋은 것이 아니다. context budget을 관리한다.

사용 파일:

```text
.agent/tools/inventory.md
.agent/tools/mcp-policy.md
.agent/tools/context-budget.md
scripts/tool-audit.sh
```

흐름:

1. 도구 목적 확인
2. core/project/on-demand/disabled로 분류
3. owner, risk, context cost 기록
4. `./scripts/tool-audit.sh`

Codex에게 줄 프롬프트:

```text
이 MCP를 추가하기 전에 tool-budget 기준으로 필요한지 평가해줘.
inventory와 context-budget을 업데이트하고 tool-audit 결과를 보고해줘.
```

## 3.6 Skill 추가/수정

Skill은 반복 workflow가 3번 이상 나왔을 때 만든다.

사용 파일:

```text
.agent/skills/registry.md
.agent/skills/sync-policy.md
.agent/skills/selection.md
scripts/skills-sync.sh
```

흐름:

1. 반복 workflow인지 확인
2. 기존 Skill과 중복 확인
3. `skills/<name>/SKILL.md` 작성
4. registry 업데이트
5. `./scripts/skills-sync.sh --dry-run`

Codex에게 줄 프롬프트:

```text
이 작업이 Skill로 만들 만한 반복 workflow인지 먼저 판단해줘.
만들 가치가 있으면 registry와 SKILL.md를 같이 업데이트해줘.
```

## 3.7 대량 생성/반복 작업 위임

Codex가 모든 걸 직접 오래 생성하게 하지 않는다. 긴 생성은 bounded delegation으로 분리한다.

사용 파일:

```text
.agent/delegation/policy.md
.agent/delegation/log.md
```

흐름:

1. Architect가 spec과 acceptance criteria 작성
2. Developer에게 제한된 파일 범위만 위임
3. Reviewer가 별도 컨텍스트로 검증
4. 결과를 delegation log에 기록

Codex에게 줄 프롬프트:

```text
이 작업은 반복 생성이 많으니 delegation-manager 방식으로 나눠줘.
Architect/Developer/Reviewer 역할과 allowed files, max iterations, stop criteria를 먼저 정리해줘.
```

---

## 4. 주간 유지보수

매주 30분만 아래를 점검한다.

```bash
./scripts/verify.sh
./scripts/tool-audit.sh
./scripts/skills-sync.sh --dry-run
```

점검 항목:

- 반복된 실수가 checklist나 rule로 승격됐는가
- 반복 workflow가 Skill 후보로 올라왔는가
- 안 쓰는 MCP/tool/Skill이 남아 있는가
- eval dataset에 실제 실패 사례가 추가됐는가
- knowledge layer가 오래되지 않았는가
- remote bootstrap log가 최신인가

---

## 5. 월간 정리

월 1회는 하네스를 줄이는 작업을 한다.

- 안 쓰는 Skill deprecated 처리
- unused/on-demand tool 정리
- 오래된 계약서 archive
- stale knowledge 표시
- eval criteria drift 확인
- remote host inventory 최신화
- AGENTS.md가 길어졌다면 하위 문서로 분리

좋은 하네스는 시간이 지날수록 복잡해지는 것이 아니라, 반복되는 판단을 짧은 규칙과 실행 가능한 검증으로 압축한다.

---

## 6. 빠른 선택표

| 상황 | 먼저 볼 파일 | 실행 명령 |
| --- | --- | --- |
| 작은 코드 수정 | `AGENTS.md`, `change-discipline.md` | `./scripts/verify.sh` |
| 큰 기능/리팩터링 | `.agent/contracts/_template.md` | `./scripts/verify.sh` |
| UI 변경 | `.agent/qa/browser-checklist.md` | `./scripts/browser-check.sh` |
| AI behavior 변경 | `.agent/evals/eval-plan.md` | `./scripts/eval.sh` |
| 아키텍처 탐색 | `.agent/knowledge/wiki/index.md` | `./scripts/knowledge-build.sh` |
| SSH 서버 작업 | `.agent/remote/policies.md` | `./scripts/remote-verify.sh` |
| MCP/tool 변경 | `.agent/tools/mcp-policy.md` | `./scripts/tool-audit.sh` |
| Skill 변경 | `.agent/skills/sync-policy.md` | `./scripts/skills-sync.sh --dry-run` |
| 위임 작업 | `.agent/delegation/policy.md` | 기록: `.agent/delegation/log.md` |

---

## 7. 프롬프트 기본형

### 구현 요청

```text
AGENTS.md와 change-discipline을 따르면서 이 작업을 처리해줘.
큰 변경이면 먼저 .agent/contracts/<task>.md 계획을 작성하고 멈춰줘.
구현 후 필요한 검증 스크립트를 실행하고 결과를 보고해줘.
```

### 리뷰 요청

```text
리뷰 모드로 봐줘.
버그, 회귀, 누락된 테스트, 범위 이탈, 보안 리스크를 우선순위대로 지적해줘.
필요하면 .agent/evals 또는 .agent/qa 기준도 같이 확인해줘.
```

### 세션 종료 요청

```text
이번 세션에서 반복된 실수, 반복 workflow, 문서 부족, 새로 필요한 검증을 정리해줘.
rule/checklist/skill/eval case로 승격할 후보를 제안해줘.
```
