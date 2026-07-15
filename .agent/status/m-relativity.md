---
owner_session: 3f51c95e-edfe-4a39-a556-7b975bdaa885
owner_label: 
owner_agent: claude
version: 3
last_updated: 2026-06-16
heartbeat: 2026-06-12T12:00:51Z
state: active
remaining_actions:
  - "AGENT: §1 1차 개선 적용 완료(협동성·전자구조·링커 난제 구체화, 각주 6건, mermaid 모식도). 다음 개선 섹션 사용자 지정 후 scratch 파일 수정 → notionize → Notion 재발행 순서로 진행."
  - "AGENT: §3 케이메디허브·강원대 2·3차년도 내용, §5 큐노바·케이메디허브 역량, §6/§7/§8 사업화 투자계획 보강 필요 (각 섹션 내용 받은 후 진행)."
  - "DECISION/결정권자(사용자 패스): 주관/공동기관 정식명·총괄 PI·실예산·인력 M/M·매칭투자 실값 → §6 연구개발비 + §8 사업화 채움 (제출 전제)."
contract_pointers:
  - .agent/contracts/m-relativity-platform-workflow-20260611.md
  - .agent/contracts/m-relativity-w3-prototype-20260610.md
---
# M-RELATIVITY — 양자보조 committor 기반 OOD 단백질분해 (연구과제 제안)

As of: 2026-06-11 (platform-workflow 정식화 — Qunova FMO/HI-VQE × committor 통합 병합 완료).

## 이 슬라이스가 무엇인가

OOD 분해제의 분해 *운명*을 물리로 계산하는 하이브리드 엔진 + 양자이득 실증 grant 제안서
(기관형, 연 10억×3년). 핵심 = committor q(x)(운명장) + **R/Q 절대 분리**(R=W₃^FF≡0 표현가능성
무조건 / Q=M∧F∧P 양자컴퓨터 필요성, 저우선). 양자가치=표현가능성(속도 아님). VAV1 degrader
파이프라인과 구분되는 독립 과제.

## 어디까지 왔나

- 제안서 전문(9절+부록, ~120K자) + Notion 발행(구판) + 적대검증 4회 (2026-06-09, commit e72c998).
- **2026-06-16 공식 RFP 형식 신판 Notion 발행**: `quantum_tpd_rfp_20260616.md` → Notion 페이지 생성. §1 개선(협동성·전자구조·링커 난제 구체화, 각주 6건, mermaid 모식도 포함).
- W₃ 프로토타입(2026-06-10): 9NFR 계면 3체 DFT W₃=+0.572 kcal/mol, **W₃^FF≈0 실증**(R 핵심).
- **2026-06-11 platform-workflow 정식화** (contract approved→실행, plan 16개 중 14 done):
  - RFP 성과지표 입수 → 제안서 **병합**: §2.6 브리지(난제1·2·3 매핑·FMO/HI-VQE 엔진·**2-타깃 Q배터리**·성과지표 layer) + §7.3 [표3b] KPI crosswalk + §6.6 **IDO1 2-타깃 사전등록**. 기존 committor/W₃/Q-NULL thesis 무손상.
  - metal scout(5타깃 PDB 실측): 2단계 타깃 **NEK7→IDO1 전환** — IDO1 heme Fe(open-shell) 저해제에 2.0Å 직접배위 → **likely Q-PASS**(BAc2 likely Q-NULL과 대조 → thesis 강화). HDAC6=R-only 헤지.
  - 적대검증 게이트 1회(REQUEST_CHANGES) → 7결함 수정(ΔS 모순·R² 동일관측량·physics 정렬 등).

## 다음 행동

결정권자 사업성 입력(§8/§7.4, Task 16) → AGENT Notion 재발행 → IDO1 Q-gate 구체화.

## Live truth

- 병합 제안서: `.agent/scratch/m_relativity_proposal_20260609.md` (§2.6·§6.6·§7.3 [표3b] 갱신, ~1830줄)
- 설계문서: `.agent/scratch/m_relativity_qunova_platform_design_20260611.md` (난제 매핑·committor↔FMO·검증)
- 증거: `m_relativity_metal_demo_scan.md`(NEK7→IDO1) · `m_relativity_rfp_checklist_20260611.md`(RFP gap-0)
- W₃ 프로토타입: `.agent/scratch/m_relativity_w3_prototype/` (contract w3-prototype-20260610 DONE)
- contract/plan: `m-relativity-platform-workflow-20260611` (plan in-progress; Task 16=결정권자 blocked)
- Notion 발행본(구판, M-RELATIVITY 자체 제안서): https://app.notion.com/p/37a1e76c3b6081a9985bdaff8c710cb1
- **Notion 발행본(신판, 공식 RFP 형식)**: https://app.notion.com/p/3811e76c3b6081a08256da8686527544
- scratch 파일(신판): `.agent/scratch/quantum_tpd_rfp_20260616.md`

## 경계 메모

- Task 16(사업성 40%)=결정권자 입력 대기, 임의작성 금지. 커밋: 이번 세션 아티팩트는 handoff 시 커밋.
- "양자 필요성" 주장 금지 — R/Q 분리·tier 비혼동 규약 유지. 범용 Notion 툴화는 harness 소관.
