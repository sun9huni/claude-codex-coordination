# fksfold-core-tier2-productive-confirm — Tier-2 staged 설계 (구성가능성 게이트 → GPU 국소 confirm)

- **Status**: done
- **Approval**: requested 2026-06-14 · approved by: user (2026-06-14 "approved")
- **Closed**: 2026-06-15 — plan(done, REVISION-1). **Verdict** = `analysis/productive_pose/TIER2_VERDICT.md`:
  Stage-2a **0/9 constructible** = **method-limited inconclusive, NOT 강한-음성**. 병목 이동: 라이신
  reach 가능(3/9 Nζ–carbonyl ≤3.5Å)이나 E2~Ub+RBX1 모듈 placement 가 cullin scaffold(L)·VAV1(V)와
  충돌(severe median 392). 단일 강체 경첩으로 CRL 통합 동역학(cullin arm 굴절+neddylation) 재현 불가.
  Stage-2b GPU SKIP(0 constructible). 사용자 결정 2026-06-15: **통합 CRL 모델링 별도 워크스트림 ESCALATE**.
  상위 20260612 Tier-2(Phase C) 소진. commits 3350c7e/1461d82/0cc277a.
- **Slice**: vav1-ubq (legacy slug `fksfold-core-` 유지 — 본 슬라이스 소관)
- **상위 계약**: `fksfold-core-swept-reach-judge-20260612`(2-tier, approved) — 본 sub-contract는 그
  **Tier-2(Phase C, plan Task 6–9)의 *방법*을 직전 input audit 결과로 구체화·pre-register**한다. 상위가
  이미 Tier-2 GPU를 authorize하나, audit가 *naive short-MD/docking = false-negative*임을 드러내 method
  재설계가 필요. ⚠️ baton 미접촉(durable 기록 = 본 contract/plan).

## Purpose

Tier-1(judge v2)이 **9 SEMI survivor**를 냈고 사용자 go도 받았다. 그러나 survivor의 completed-overlay
구조는 **MD-ready가 아니다** — 9체인 강체 graft다. naive short-MD/docking을 그대로 GPU에 올리면 생물학이
아니라 graft 아티팩트 + timescale 한계를 측정해 **false negative**가 난다. productive near-attack
(lysine Nζ→촉매 Cys85 Sγ ≤3.5Å)을 정직하게 판정하려면 (a) 닫힘을 만드는 **큰 자유도(VAV1 linker +
CRL hinge)로 near-attack 포즈를 *생성***하고, (b) 그 **국소 기하만 GPU로 *확정*(basin 안정성)**하는 2단
구조가 필요하다. 본 계약의 목적 = 이 staged Tier-2를 pre-register해, GPU는 *생성이 성공한 뒤에만* 돌게 하는 것.

## Current State

직전 input audit(`completed_seed42.pdb` + `complete_structure.py`)에서 확정된 사실:

- **graft 구조**: 9체인(A=CRBN, B=docked SH3, C=MRT6160, D=DDB1, E=UBE2D2[cat Cys85], L=CUL4A,
  U=Ub, V=full-VAV1, X=RBX1)을 5개 출처(pose/AF-P15498/9NFR/2HYE/6TTU)에서 **강체 super로만** 얹음.
  결합·에너지 이완 0.
- **결함 1 — 중복 SH3**: chain B(docked SH3, resi 1–61) + chain V(full-VAV1, SH3를 resi 782–842에
  재포함)가 같은 영역을 겹쳐 점유 → MD는 두 복사본을 못 돌림. (chain V super RMSD<2Å gate PASS이므로 V로
  B 대체 가능.)
- **결함 2 — 도메인 스케일 갭**: 최우선 survivor p60_seed123조차 best lysine **Cα→촉매 Sγ ≈ 28.6Å**
  (SEMI 15.1Å은 rotamer 6.5 + 수용체 7Å을 *뺀 bound*이지 실거리 아님). near-attack 3.5Å까지 backbone/
  도메인 운동 **~18Å** 필요 = **ns-scale MD 영역 밖**(자발적으로 안 닫힘).
- **결함 3 — productive 자유도 동결**: E2~Ub 위치를 정하는 CUL4–RBX1 hinge가 2HYE 한 컨포메이션에 고정
  + cross-cullin 키메라(E2~Ub=6TTU/CRL1, scaffold=2HYE/CRL4). 정작 닫힘을 만드는 자유도가 graft에서 제거됨.
- **입력 보유**: 9 survivor(`swept_reach_verdict.md`), frozen `reach_envelope.md`(near-attack ≤3.5Å =
  Tier-2 임계, 출처 PMC4086935; Bürgi-Dunitz 3.3–3.5Å/112–128°). 실행 env =
  `/home/ubuntu/miniconda3/envs/pymol/bin/python`.

## Assumptions And Questions

- **가정**: productive near-attack은 큰 자유도로만 도달 가능 → *생성(modeling)이 본질*, GPU MD는 *국소
  confirm*만 한다(MD는 18Å 도메인 운동을 자발 생성 못 함).
- **가정**: clean MD-ready system 복구 가능(chain V가 chain B 대체, Zn/양성자화/이완 추가).
- **tradeoff**: 본격 integrative ensemble(productive 경로 전체 샘플링)은 scope 밖 → 본 Tier-2는
  "contact **constructible + 국소 stable**"만 판정하고 "**pathway/kinetically accessible**"는 판정하지
  않는다(한계로 명시). 이는 정직한 *necessary→sufficient 중간* 판정이지 productive 확정의 최종형이 아니다.
- **open question(→ plan에서 결정)**: 모델링 scope = full-complex(~28k atom) vs **reduced productive
  sub-system**(E2~Ub + RBX1 + substrate SH3-loop + linker; tractable + active-site 먼 graft 아티팩트
  적음). 기본 권장 = reduced.
- **결정된 fork(2026-06-14 사용자)**: Tier-2 go 後 audit가 naive 경로를 깸 → /brainstorm 경유 staged 설계.

## Scope

**staged rung 2 → rung 3** (rung = 직전 제시한 rigor ladder):

- **Stage 2a — zero-GPU 구성가능성 (★게이트, load-bearing)**:
  1. **system-repair**: 각 survivor → clean MD-ready system(중복 SH3 해소[V 유지], Zn 추가, 양성자화,
     국소 이완). 산출 = repair 스크립트 + 복구 구조.
  2. **near-attack 구성/샘플링**: documented 큰 자유도(full-VAV1 linker flexibility + CRL hinge)로
     nearest lysine Nζ를 촉매 Sγ ≤3.5Å(Bürgi-Dunitz 각)로 가져가는 포즈를 *구성* 시도. readout =
     **constructible(yes/no)** + clash/strain + 각도 부합 + 사용 자유도. 산출 `tier2_construct.md` +
     per-survivor 구조.
- **Stage 2b — GPU 국소 confirm (Stage-2a constructible>0 + 사용자 go 後, GATED)**:
  구성된 near-attack 포즈에 **짧은 restrained/equilibrium MD** → near-attack basin이 **안정·populated**
  한지(아티팩트 아닌지) 확인. 산출 SLURM 스크립트 + GPU 출력 + `tier2_confirm.md`.
- **종합 verdict**: productive contact "constructible + 국소 stable" / "constructible 0 → 강한 음성" /
  "구성하나 불안정" 중 판정 + MRT6160 active anchor 정합 재확인 + 한계(pathway 미판정).

## Out of scope

- **본격 integrative production MD / full 자유에너지 / productive pathway 전체 ensemble 샘플링**
  (= full-length VAV1 동역학 + flexible CRL 통합모델링). 인정된 미모델 자유도 — 한계로만 기록.
- **rigid M1 / Tier-1 `swept_reach` judge 변경**(확정됨, ⊥ steering 보존).
- 새 generation / 방향 스캔 재실행. distal lysine. m-relativity 양자/committor. 엔진·Boltz 재실행.

## Success criteria

1. **system-repair 검증**: `python <repair>.py --pose <survivor>` → 체인 인벤토리(중복 SH3 0, 촉매 Sγ
   n=1, Zn 존재, 단일 좌표계) + sanity. 깨진 graft가 MD-ready로 정리됨.
2. **Stage 2a 산출 + 게이트**: `cat tier2_construct.md` → 9 survivor별 constructible(yes/no) +
   clash/strain + Bürgi-Dunitz 부합 + 사용 자유도. **constructible 목록 또는 "0 → 강한 음성"** 게이트.
3. **[★GATE] Stage 2b**(constructible>0 시): `squeue` 제출 → 후보별 near-attack basin 안정성
   (Nζ–Sγ 거리 시계열 / RMSD / populated fraction).
4. **종합 verdict**: `cat tier2_confirm.md` → productive 판정(constructible+stable / 미구성 / 구성-불안정)
   + **한계(pathway/kinetic 미판정)** 명시 + MRT6160 anchor 정합.
5. **pre-reg 감사성**: 본 contract가 audit(graft 3대 결함)를 method에 반영했고 GPU(Stage 2b)는
   Stage-2a 게이트 뒤임이 기록 → post-hoc 아님.

## Triggers matched

- **Stage 2b = SLURM/GPU 제출** → 상위 contract 20260612가 authorize + 본 sub-contract가 method
  pre-register. **Stage-2a constructible>0 + 사용자 go 後에만**.
- **4+ files**(repair 스크립트 · `tier2_construct.md` · SLURM · `tier2_confirm.md` · 복구/구성 구조).
- **Stage 2a = zero-GPU**(CPU 모델링/최소화). /mnt 스캔 = read-only 입력. 출력 = home `analysis/`
  (GPU 출력만 `/mnt/data/users/ubuntu`).

## Resource budget

- **Stage 2a = zero-GPU**(CPU: system-repair + 제약 모델링/최소화, survivor당 분 단위).
- **Stage 2b = GPU/SLURM**, constructible survivor만(몇 후보 × 짧은 restrained MD — GPU 풍부하나
  Stage-2a 게이트 後). MD 엔진은 plan에서 확정(OpenMM/GROMACS 중). 모델링 env = pymol python.

## Constraints

- **HARD: Stage-2a 게이트** — constructible 0이면 **Stage 2b GPU 금지(강한 음성 결론)**. near-attack
  임계·각도 = frozen `reach_envelope.md`(출처 PMC4086935), fabricate 0. soft 요소는 상대-rank.
- **HARD: GPU(Stage 2b)** = Stage-2a constructible>0 + **사용자 go 後에만 sbatch**.
- 신규 파일만 surgical commit. **baton·Tier-1 judge 미접촉**. subagent에 dirty 파일 git 조작 금지(미커밋 선커밋).
- graft 한계(cross-cullin, 미모델 자유도) verdict에 명시 — "constructible/stable" ≠ "pathway accessible".

## Rollback

- **Stage 2a**: 신규 스크립트/구조/md 삭제 — GPU·shared-storage 부작용 0.
- **Stage 2b**: GPU 출력 디렉토리 삭제 — production·엔진·타 세션 미변경.

## Progress Log

- 2026-06-14: /brainstorm. 사용자 Tier-2 go 後 input audit가 graft 3대 결함(중복 SH3, ~18Å 도메인 갭,
  frozen hinge/cross-cullin) 발견 → naive short-MD = false-negative 판명. staged rung2→3 설계:
  **Stage-2a**(zero-GPU 큰-자유도 near-attack 구성 = load-bearing) 게이트 → **Stage-2b**(GPU 국소
  stability confirm). 한계: pathway/ensemble 미판정(통합모델링 scope 밖). 사용자: brainstorm 경유 결정.
  대안(C=zero-GPU reachability-only / D=STOP, Tier-1 종결)은 승인 시 revise 가능으로 남김.
- 2026-06-14 **REVISION-1 (construction 모델 정정, 사용자 승인)**: plan(approved) Task 1–4 실행 중
  Stage-2a clash check가 초기 construction hinge 모델을 **falsify**. 9 survivor 전부 severe clash
  159–309(hinge 각에 비례, 보편적) = **RING-Zn 강체회전 아티팩트**(E2~Ub를 RBX1 내부 점 둘레로 강체
  회전 → RING 인터페이스 shear). 동시에 N이 Sγ로만 최적화돼 **reactive carbonyl(Ub Gly76 C)엔
  7–12Å 잔존**. 따라서 plan의 `constructible=severe==0` 게이트는 0을 trivially 내며 이는 생물학이 아닌
  아티팩트 → strong-negative 보고는 본 redesign이 피하려던 바로 그 false-negative. **정정(2가지)**:
  ①pivot/축 = E2-about-RING → **{RBX1+E2~Ub}(X+E+U)를 CUL4–RBX1 hinge로 회전**(RING 인터페이스
  보존, shear 제거); ②최적화 타깃 = Sγ → **reactive carbonyl**(단 Nζ–Sγ 도 계속 보고 = 계약 원 metric
  연속성 유지, carbonyl=productive 반응중심으로의 정련). Tasks 1–2 done 보존, Task 3(+4 타깃) 재개정
  → /write-plan REVISION. zero-GPU. 진짜(비아티팩트) constructibility 신호 확보가 목적.
