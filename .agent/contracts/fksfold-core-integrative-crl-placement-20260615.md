# fksfold-core-integrative-crl-placement — 통합 CRL 모델링 (flexible cullin/neddylation → productive E2-module placement 판정)

- **Status**: approved
- **Approval**: requested 2026-06-15 · approved by: user (2026-06-15 "진행")
- **Slice**: vav1-ubq (legacy slug `fksfold-core-` 유지 — 본 슬라이스 소관)
- **상위/선행**: `fksfold-core-swept-reach-judge-20260612`(2-tier, done) → `fksfold-core-tier2-productive-confirm-20260614`(done).
  **에스컬레이션 근거** = `analysis/productive_pose/TIER2_VERDICT.md`: Tier-2(강체 hinge 구성)가 **0/9
  constructible**로 소진되며 병목이 "라이신 reach"(가능, 3/9 Nζ–carbonyl ≤3.5Å)에서 **"E2~Ub+RBX1 모듈
  placement가 cullin scaffold·VAV1과 충돌"**로 이동함을 입증. 단일 강체 경첩으로 CRL 통합 동역학 재현
  불가 → 본 contract가 그 자유도를 제대로 모델링한다. 사용자 결정 2026-06-15.

## Purpose

Tier-2는 "라이신은 닿을 수 있으나, 우리의 강체 모델로는 E2 모듈을 그 자세로 *놓을* 수 없다"까지 답했다.
진짜 질문 = **CRL4의 자연 유연성(cullin arm 굴절 + neddylation 유발 형태 변화)을 명시적으로 모델링하면,
E2~Ub 모듈이 VAV1 SH3 라이신을 반응성 카보닐로 가져오는 productive near-attack 자세에 *scaffold 충돌
없이* 도달하며, 그 상태가 *열역학적으로 점유(populated)*되는가?** 이를 판정해 Tier-2의 "방법-한계
inconclusive"를 productive geometry에 대한 진짜 yes/no(+점유율)로 바꾸는 것이 목적이다.

## Current State

- **입력 보유**: 9 SEMI survivors(`tier2_survivors.txt`), `TIER2_VERDICT.md`(병목·landscape), frozen
  `reach_envelope.md`(near-attack ≤3.5Å = PMC4086935; rotamer 6.5Å = PMC4937519; Bürgi-Dunitz 112–128°).
- **강체 graft 한계(반드시 교정 대상)**: 기존 9체인 graft는 **cross-cullin chimera**(scaffold=2HYE/CRL4,
  E2~Ub=6TTU/CRL1) + **neddylation 미반영**(apo/non-neddylated cullin arm) + 중복 SH3(이미 해소). 이 graft를
  그대로 flexible MD에 넣으면 키메라·비활성-형태 아티팩트를 전파한다 → 시스템 재구축이 선행돼야 한다.
- **방법 선택(사용자 2026-06-15)**: flexible MD (normal-mode/enhanced sampling). **성공 기준 = populated
  basin**(존재만이 아니라 열역학적 점유). **시스템 = coherent neddylated CRL4 재구축 후 MD**(키메라 제거 +
  NEDD8 명시).
- **실행 env**: 모델링/분석 = `/home/ubuntu/miniconda3/envs/pymol/bin/python`. MD 엔진 = plan에서 확정
  (OpenMM/GROMACS + enhanced sampling[metadynamics/REMD 등]). GPU 풍부(정당화 완료 — Tier-2가 강체 한계 입증).

## Assumptions And Questions

- **가정**: productive E2-module placement는 cullin arm의 저주파 굴절 모드 + neddylation 형태 변화로만
  도달 가능 → flexible MD가 본질, 강체 구성은 불충분(Tier-2가 입증).
- **가정**: coherent neddylated active-CRL4–E2 참조 구조를 확보·재구축할 수 있다. **★핵심 의존성/리스크**:
  neddylated CRL4 + E2~Ub 공개 구조가 희박할 수 있음(타 슬라이스에서 ternary 공개구조 희박 관측). 입력
  구조 미확보 시 본 contract는 **NEEDS-DATA로 정지**(RCSB 큐레이션 선행) — 첫 task가 구조 확보/검증.
- **가정**: 9 survivor 전체가 아니라 **near-attack 도달 상위 후보(예: 3/9 ≤3.5Å carbonyl + 경계 몇 개)**로
  MD 대상을 좁혀도 됨(비용 통제; plan에서 확정).
- **open question(→ plan)**: enhanced-sampling 좌표(cullin arm hinge CV vs Nζ–carbonyl 거리 CV), NEDD8
  표현(명시 conjugate vs 형태 구속), 수렴 판정(점유율 추정 오차). 단계화 = **NMA/ENM(저비용) 선행 →
  저주파 productive 모드 확인 後에만 enhanced-sampling MD(GPU)**.
- **결정된 fork**: 방법=flexible MD / 기준=populated basin / 시스템=coherent neddylated 재구축(사용자 2026-06-15).

## Scope

**3단계 staged, 각 compute 에스컬레이션은 사용자 go 게이트**:

- **Stage A — 시스템 재구축 (zero-GPU, ★선행 게이트)**: coherent neddylated active-CRL4 참조 구조 확보·검증
  → 키메라 제거(단일 cullin 계열) + NEDD8 명시 포함 + VAV1/MRT6160 anchor 보존 + E2~Ub 배치. 산출 =
  재구축 스크립트 + clean MD-ready 시스템 + sanity(체인 인벤토리, anchor RMSD, NEDD8 존재). **구조 미확보 시
  NEEDS-DATA 정지.**
- **Stage B — NMA/ENM 모드 진단 (저비용 CPU, 게이트)**: 재구축 시스템의 normal-mode/elastic-network 분석으로
  cullin arm 저주파 굴절 모드가 E2 모듈을 substrate 쪽으로 swing시키는지 확인 + 모드 진폭 대비 Nζ–carbonyl/
  clash 스캔(zero-MD reach landscape). **productive 모드 부재 시 → enhanced-sampling 정당성 재검토(사용자 surface).**
- **Stage C — enhanced-sampling MD (GPU/SLURM, 이중 게이트: Stage B productive 모드 확인 + 사용자 go)**:
  flexible cullin + neddylated 시스템에 enhanced sampling으로 productive near-attack basin의 **점유율/자유에너지**
  추정. readout = near-attack(Nζ–carbonyl ≤3.5Å, severe=0) populated fraction + ΔG + 수렴 진단.
- **종합 verdict**: productive geometry "populated(어느 survivor·점유율) / 도달하나 미점유 / 미도달" 판정 +
  MRT6160 anchor 정합 + 한계(force-field/sampling 수렴, 단일 active-form 가정).

## Out of scope

- **촉매 메커니즘/QM**(thioester transfer 화학, 양자 효과 — m-relativity 소관), DC50/Dmax 등 **활성 정량 예측**
  (본 contract = 기하 feasibility + 점유, 효능 순위 아님).
- 다른 E3/기질, distal lysine(glue-anchored C-SH3 라이신만), Tier-1/Tier-2 재실행, Boltz 생성·방향 스캔 재실행.
- 기존 강체 `swept_reach`/`tier2_construct` judge 변경(확정·종결됨).

## Success criteria

1. **Stage A 검증**: `$PY <rebuild>.py --verify` → 단일 cullin 계열(키메라 0) + NEDD8 존재 + anchor RMSD
   게이트 통과 + E2 Cys85 Sγ / Ub Gly76 C / SH3 라이신 존재. clean MD-ready 시스템.
2. **Stage B 산출**: `cat <nma>.md` → 저주파 모드별 (E2 swing 방향 부합 y/n) + 모드 진폭 대비 min Nζ–carbonyl/
   severe 스캔 표 + "productive 모드 존재" 게이트 판정.
3. **[★GATE] Stage C**(Stage B 통과 + 사용자 go 시): `squeue` 제출 → enhanced-sampling trajectory + near-attack
   **populated fraction + ΔG + 수렴 진단**(survivor별).
4. **종합 verdict**: `cat <CRL_VERDICT>.md` → productive geometry populated 판정(어느 survivor/점유율) + 한계
   (force-field·수렴·active-form 가정) + MRT6160 anchor 정합. 강체 Tier-2 결과와의 연속성 명시.
5. **pre-reg 감사성**: 시스템 재구축이 키메라/neddylation 결함을 교정했고, GPU(Stage C)가 Stage A/B 게이트
   뒤임이 기록 → post-hoc 아님.

## Triggers matched

- **Stage C = SLURM/GPU 제출**(enhanced-sampling MD) → 상위 2-tier가 물리 confirm을 authorize하나, 본
  contract가 통합-모델링 method를 신규 pre-register. **Stage A/B 게이트 통과 + 사용자 go 後에만**.
- **4+ files**(재구축 스크립트 · NMA md · MD 입력/SLURM · verdict · clean/재구축 구조).
- **shared-storage writes**: GPU 출력만 `/mnt/data/users/ubuntu/workspace`(ubuntu 소유, no sudo). 입력
  구조 확보는 read-only(필요 시 kim 경로는 `sudo -u kim`).
- **Stage A/B = zero/low-GPU**(CPU 재구축·NMA). 출력 = home `analysis/`.

## Resource budget

- **Stage A = zero-GPU**(구조 확보 + 재구축 + sanity; 분~시간). **Stage B = 저비용 CPU**(NMA/ENM; 시간).
- **Stage C = GPU/SLURM 풍부**(enhanced-sampling MD — survivor 상위 후보 × 충분한 sampling. 점유율 수렴이
  목표라 generous하게, 단 Stage A/B 게이트 뒤). MD 엔진·CV·sampling 프로토콜 = plan에서 확정.
- **★리스크**: neddylated CRL4–E2 입력 구조 미확보 시 Stage A에서 NEEDS-DATA 정지(GPU 0 소비).

## Constraints

- **HARD: Stage A 게이트** — coherent neddylated 시스템 재구축 실패/구조 미확보면 **Stage B·C 금지**(NEEDS-DATA).
- **HARD: Stage B 게이트** — NMA에서 productive swing 모드 부재면 **enhanced-sampling 정당성 사용자 surface**
  후에만 Stage C(강체 Tier-2 교훈: 음성 자동선언 금지, calibration 긴장 surface).
- **HARD: Stage C GPU** = Stage A·B 통과 + **사용자 go 後에만 sbatch**. near-attack 임계·각도 = frozen
  `reach_envelope.md`, fabricate-0.
- 신규 파일만 surgical commit. **baton·Tier-1/Tier-2 judge·verdict 미접촉**. subagent에 dirty 파일 git 조작
  금지(미커밋 선커밋).
- verdict에 한계 명시 — "populated"는 *이 force-field·sampling·재구축 active-form*에서의 점유이지 절대 진리 아님.

## Rollback

- **Stage A/B**: 신규 스크립트/구조/md 삭제 — GPU·shared-storage 부작용 0.
- **Stage C**: GPU 출력 디렉토리 삭제 — production·엔진·타 세션 미변경(`scancel` + rm 출력 dir).

## Progress Log

- 2026-06-15: /brainstorm. Tier-2(강체) 0/9 constructible 소진 → 병목=E2 모듈 placement(flexible CRL 동역학).
  사용자 결정 5개: 에스컬레이션 / 방법=flexible MD(NMA→enhanced sampling) / 기준=populated basin / 시스템=
  coherent neddylated CRL4 재구축 / 입력=9 survivors+TIER2_VERDICT. 3단계 staged(A 재구축 zero-GPU →
  B NMA 저비용 → C enhanced-sampling MD GPU), 각 compute 게이트 = 사용자 go. ★핵심 리스크 = neddylated
  CRL4–E2 입력 구조 확보(미확보 시 NEEDS-DATA 정지). 승인 시 /write-plan.
- 2026-06-15 **승인 + /write-plan + Task 1 실행 → NEEDS-DATA (commit ffacc48)**. plan 9-task
  작성·승인, Task 1(zero-GPU PDB recon, 5 PDB 검증: 6TTU/2HYE/7OKQ/8JE2/4A0K) 결과 = ★게이트
  **NEEDS-DATA**: coherent neddylated active CRL4–E2~Ub 구조가 PDB에 부재(활성 E2~Ub 트랩 중간체
  = CUL1 6TTU 단 1건; CUL4 계열 2HYE/7OKQ/4A0K 전부 비-네딜화 또는 E2~Ub 결손; 8JE2는 CUL2+E2
  결손). 2HYE(CUL4)+6TTU(CUL1) 조립 = 본 contract가 제거하려는 cross-cullin 키메라 재현이라 불가.
  → **Tasks 2–9 미진입(rebuild/NMA/MD 0 compute)**. plan status=blocked. 재개 트리거 = (a)
  NEDD8-CUL4A active-arm 구조 확보 또는 (b) 사용자가 homology 이식+cross-cullin 보정 명시 모델링을
  허용(별도 검증 게이트). 상세 `analysis/crl_integrative/structure_sources.md`. **함의: VAV1
  productive-geometry 질문은 현재 method-limited를 넘어 STRUCTURE-LIMITED — 강체든 통합이든 활성
  CUL4 catalytic-arm 좌표가 없으면 비순환적으로 답할 수 없다.**
- 2026-06-15 **구조 확보 심층조사 → PATH-EXISTS / acquisition-pending (recon 8dfc872)**. 사용자
  "구조 확보 경로 우선 조사" 결정 → EMDB/preprint/생성경로 deep recon(~14 ID + 8 논문 검증).
  Task 1의 RCSB-only NEEDS-DATA **초월**: **2025 bioRxiv CRL4^CRBN^–IKZF3 활성 ubiquitylation
  복합체**(NEDD8-CUL4A WHB + RBX1 + UbcH5a~Ub catalytic apex, ~3.4Å)가 coherent single-family
  neddylated active CUL4 start-state로 존재 → **cross-cullin graft 불필요**(Task-1 우려 해소).
  Recipe(route a) = 그 catalytic-half(CUL4A–NEDD8–RBX1–UbcH5a~Ub) 고정 + 기질수용체만 VAV1로
  교체(within-family). **★유일 잔여 게이트 = 해당 preprint의 PDB/EMDB accession이 아직 web-
  resolvable 아님**(on-hold deposit) → 식별·검증됐으나 다운로드 불가 = **acquisition-pending**.
  다음 = accession 확보(RCSB advanced-search watch CUL4A+NEDD8+UbcH5a+IKZF3 / 저자 Pan·Liu 요청);
  확보 시 plan Task 3부터 재개. fallback(좌표 끝내 부재): (b) 6TTU(CUL1) homology graft 또는
  (c) 7OKQ→8WQH(neddylated CUL2 active-arm) re-pose 하이브리드 — 둘 다 arc-geometry bias caveat
  + 별도 검증 게이트. 생성경로(AF3/Boltz) = closed-bias·공유결합 미모델·circularity로 백업만.
  상세 `analysis/crl_integrative/structure_acquisition_recon.md`.
- 2026-06-15 **ACQUIRABLE-NOW — 입력 구조 확보(commit 3b47a05)**. 사용자가 Deng et al. 2025
  복합체 PDB ID 8종 제시 → RCSB 직접 검증: 일부 on-hold(9UUQ/9V0C)이나 **9UUM**(mezigdomide
  CRL4-DDB1-CRBN-IKZF3-UbcH5a~Ub ubiquitylation assembly, 3.41Å)이 **2026-06-10 공개**. `refs/
  9UUM.cif` 다운로드 + cif 실측(8 chains/20807 atoms; CRBN/UBE2D1/NEDD8/Ub/RBX1/DDB1/CUL4A+
  IKZF3 전부). 9V0F(3.71Å) 백업. **단일 공개 구조에 coherent neddylated active CUL4 + RING-
  engaged E2~Ub 다 포함 → cross-cullin graft·생성경로 전부 불요(Task-1 NEEDS-DATA 완전 해소).**
  Stage A recipe 정정: **9UUM 촉매-half 고정 + IMiD·IKZF3 제거 → MRT6160·VAV1 C-SH3 pose를
  CRBN에 within-family substrate-swap**. plan UNBLOCKED(status in-progress), Tasks 1–2 done →
  다음 Task 3(재구축). ('accession pending'은 9UUM 5일 전 공개를 놓친 타이밍이었음 — 사용자
  추가검색 직감이 적중.)
