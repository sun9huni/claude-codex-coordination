---
contract: .agent/contracts/fksfold-core-tier2-productive-confirm-20260614.md
slice: vav1-ubq
status: done
total_tasks: 10
estimated_total_min: 56
revision: REVISION-1 (2026-06-14) — construction 모델 정정 (Task 4b 삽입)
---

# Plan — Tier-2 staged productive-confirm (구성가능성 게이트 → GPU 국소 confirm)

> **REVISION-1 (2026-06-14, 사용자 승인):** Tasks 1–4 실행 중 Stage-2a clash check가 초기 construction
> hinge 모델(E2-about-RING-Zn 강체회전)을 **falsify** — 9 survivor 전부 severe clash 159–309(hinge 각
> 비례, 보편적) = RING shear 아티팩트 + Nζ가 Sγ로만 최적화돼 reactive carbonyl엔 7–12Å 잔존. plan의
> `constructible=severe==0` 게이트가 0을 trivially 내는데 이는 아티팩트(생물학 아님). **정정 = Task 4b
> 삽입**: ①{RBX1+E2~Ub}=X+E+U를 **CUL4–RBX1 hinge**로 함께 회전(RING 인터페이스 보존→shear 제거);
> ②타깃 = **reactive carbonyl**(Ub Gly76 C), Nζ–Sγ 도 계속 보고; ③clash 분할 갱신(block=X+E+U,
> rest=A,C,D,L,V). Tasks 3·4 = done이나 모델 SUPERSEDED(단 clash 채점 machinery는 Task 4b가 재사용).
> 계약 Progress Log REVISION-1 참조.

> survivor overlay = MD-ready 아님(강체 graft: 중복 SH3, ~18Å 도메인 갭, frozen hinge/cross-cullin).
> **Stage 2a**(zero-GPU, load-bearing): clean system + 큰-자유도 near-attack 포즈 *구성* → clash/strain
> 게이트. **Stage 2b**(GPU, constructible>0 + 사용자 go 後): 구성된 포즈 짧은 restrained MD로 basin
> 안정성 confirm. 종합 verdict + 한계(pathway 미판정).

## 설계 정제 (audit 기반, contract 의도에 충실)

- **닫힘 자유도 = CRL hinge / E2~Ub positioning (VAV1 linker 아님).** SH3 lysine
  K788/804/810/814/815는 전부 *glue-anchored* C-SH3(resi 782–842)에 있다(distal lysine 배제). 따라서
  도달은 VAV1 linker가 아니라 **RBX1-RING hinge로 E2~Ub를 substrate 쪽으로 sweep + lysine rotamer**로
  닫힌다. construction은 이 자유도만 쓴다.
- **Stage-2b reduced subsystem = E2(chain E) + Ub C-term(chain U) + C-SH3(chain V resi 782–842)만.**
  CRBN/DDB1/CUL4/RBX1/LIG/Zn **제거** → 금속·신규리간드 parameterization 불필요(표준 protein FF로 충분).
  scaffold의 E2 고정 역할은 core position restraint로 대체. = "near-attack 접촉이 국소 안정인가"만 검증.
- **Stage 2b는 Stage-2a constructible=0이면 전면 SKIP**(강한 음성 → Task 9 종합 직행).
- **GATE 이중**: Stage 2b sbatch(Task 7) = Stage-2a constructible>0 **AND** 사용자 go. execute-plan은
  Task 7에서 정지.
- 실행 env = `/home/ubuntu/miniconda3/envs/pymol/bin/python`(이하 `$PY`). near-attack 임계 3.5Å·
  Bürgi-Dunitz 112–128° = frozen `reach_envelope.md`(PMC4086935). hinge sweep RANGE 미확보 → 크기
  보고 + in/beyond 플래그(hard-fail 안 함, relative).

## Phase A — Setup + system-repair (zero-GPU)

## Task 1: 9 survivor manifest 도출 (CSV에서)
- **Status**: done (commit 3364e16) · **Prereq tasks**: none
- **Files touched**: `analysis/productive_pose/tier2_survivors.txt`
- **Change shape**: `swept_reach.csv`에서 verdict 열(col 11)==SEMI 행을 필터(손-입력 금지, CSV에서 도출)
  → 각 pose를 scan model PDB 경로로 해소(swept_reach.py의 scan-dir glob 재사용/복제) → `pose_name<TAB>
  model_pdb_path` 9행 기록.
- **Verification**: `awk -F, 'NR>1 && $11=="SEMI"{c++} END{print c}' analysis/productive_pose/swept_reach.csv`
  → `9`; `wc -l < analysis/productive_pose/tier2_survivors.txt` → `9`; 각 col2 경로 `test -f` 통과.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `rm analysis/productive_pose/tier2_survivors.txt`

## Task 2: tier2_repair.py — clean MD-ready 전체 시스템
- **Status**: done (commit 1e9f1d7) · **Prereq tasks**: 1
- **Files touched**: `analysis/productive_pose/tier2_repair.py`
- **Change shape**: survivor model PDB → `complete_structure.build_complex()`로 completed overlay 생성 →
  **clean**: chain B(중복 docked SH3) 제거(chain V full-VAV1이 SH3 영역 보유), RING **Zn 보장**(overlay가
  누락 시 2HYE chain D에서 추가), 단일 좌표 프레임으로 `tier2_clean_<pose>.pdb` 저장. sanity 출력 =
  per-chain 인벤토리 + assert(chain B 부재 / chain V 존재 / chain E resi85 Sγ n==1 / Zn 존재).
- **Verification**: `$PY analysis/productive_pose/tier2_repair.py --pose <p60_seed123 model> --out /tmp/clean_p60_123.pdb`
  → 인벤토리에 `chain B: ABSENT`, `cat Cys85 Sγ: n=1`, `Zn: present`; `/tmp/clean_p60_123.pdb` 존재.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `rm analysis/productive_pose/tier2_repair.py`

## Phase B — near-attack 구성 + 게이트 (zero-GPU, load-bearing)

## Task 3: tier2_construct.py — near-attack 기하 구성 (hinge sweep + rotamer)
- **Status**: done (commit 3066a6b) — ⚠️ 모델 SUPERSEDED by Task 4b (RING-Zn 강체회전 = clash 아티팩트로 falsified) · **Prereq tasks**: 2
- **Files touched**: `analysis/productive_pose/tier2_construct.py`
- **Change shape**: clean 시스템 입력 → 닫힘 자유도로 productive near-attack 기하 구성: (1) RBX1-RING hinge
  축/pivot 정의(`reach_envelope_geom`/`swept_reach`의 RING-Zn pivot 재사용); (2) E2~Ub 블록(chain E+U)을
  hinge 축으로 강체 회전해 `d(Cys85 Sγ, best-lysine Cα)` 최소화; (3) best SH3 lysine 측쇄 rotamer를 Sγ
  쪽으로 빌드해 Nζ–Sγ 최소화(Bürgi-Dunitz 접근각). 구성 포즈 `tier2_pose_<name>.pdb` 저장 + 달성 Nζ–Sγ,
  hinge 회전 크기(°), 접근각 출력. (clash/verdict는 Task 4.)
- **Verification**: `$PY analysis/productive_pose/tier2_construct.py --clean /tmp/clean_p60_123.pdb --geom-only`
  → 달성 Nζ–Sγ(Å, rigid ~36Å보다 크게 작아야) + hinge Δ(°) + 각(°); `tier2_pose_*.pdb` 기록.
- **Estimated time**: 7 min
- **Rollback (if this task only)**: `rm analysis/productive_pose/tier2_construct.py`

## Task 4: tier2_construct.py — clash/strain 채점 + constructible 플래그
- **Status**: done (commit 69480e1) — clash 채점 machinery는 RETAINED(Task 4b 재사용); 타깃(Sγ)·constructible 정의는 Task 4b가 SUPERSEDE · **Prereq tasks**: 3
- **Files touched**: `analysis/productive_pose/tier2_construct.py`
- **Change shape**: 회전 후 steric clash(E2~Ub vs CRL scaffold/substrate/CRBN heavy-atom <2.0Å 겹침 수) +
  rotamer strain proxy 추가; **constructible = (달성 Nζ–Sγ ≤ 3.5Å) AND (clash ≤ 임계) AND (hinge Δ
  in/beyond-range 플래그)**. hinge 절대 range 미확보이므로 크기+플래그만(hard-fail 안 함). constructible
  y/n + 구성요소 출력.
- **Verification**: `$PY analysis/productive_pose/tier2_construct.py --clean /tmp/clean_p60_123.pdb`
  → `constructible: yes|no`, `clash=N`, `Nζ-Sγ=X`, `hinge=Y°`, `strain=Z`.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout analysis/productive_pose/tier2_construct.py` (→ Task 3 상태; 단 미커밋이면 수동 되돌림)

## Task 4b: [REVISION-1] construction 모델 정정 — CUL4–RBX1 hinge + carbonyl 타깃
- **Status**: done (commit 3350c7e) — manipulation |Δ|=0.0000Å AGREE; p60_123 severe 220→382 증가(비감소, Task 5/9 해석) · **Prereq tasks**: 4
- **Files touched**: `analysis/productive_pose/tier2_construct.py`
- **Change shape**: `construct()`의 hinge 모델을 정정(RING-Zn 강체회전 = clash 아티팩트로 falsified).
  Rodrigues/`_ttt_matrix`/`_score_clashes` machinery는 **재사용**, 다음 4가지만 정정:
  (1) **hinge pivot 정정** — RING Zn → **CUL4–RBX1 인터페이스 centroid**: chain X(RBX1) 원자 중 chain
  L(CUL4) 5.0Å 이내 접촉 원자들의 centroid(없으면 X–L 최근접 쌍 midpoint fallback). = 물리적 scaffold hinge.
  (2) **moving block 정정** — `E2UB_CHAINS=(E,U)` → **`(X,E,U)`**: RBX1을 E2~Ub와 함께 회전시켜 E2–RBX1
  RING 인터페이스 보존(shear 아티팩트 제거).
  (3) **타깃 정정** — Sγ → **reactive carbonyl**(chain U 마지막 Gly의 atom C = Ub Gly76 C): `_hinge_for_lysine`
  의 lever를 `carbonyl − pivot`로, best lysine = argmin Nζ–carbonyl. **Nζ–Sγ 도 계속 산출·보고**(계약 원 metric 연속).
  (4) **clash 분할 갱신** — `REST_CHAINS=(A,C,D,L,V,X)` → **`(A,C,D,L,V)`**(X가 block으로 이동). 상수만 갱신.
  보고 = Nζ-carbonyl(primary) + Nζ-Sγ(continuity) + hinge° + 접근각 + clash_count/severe_count. constructible
  최종 정의는 Task 5 게이트에서 post-fix clash landscape 보고 확정(여기선 carbonyl·Sγ·severe 모두 보고).
- **Verification**: `$PY analysis/productive_pose/tier2_construct.py --clean /tmp/clean_p60_123.pdb`
  → Nζ-carbonyl + Nζ-Sγ + hinge° + severe_count 출력; manipulation 일치(<0.1Å). **핵심 = severe_count가
  이전 RING-Zn 모델(p60_seed123=220) 대비 크게 감소**(shear 아티팩트 제거 확인; 안 줄면 clash가 real이란
  신호 → Task 5/9에서 해석).
- **Estimated time**: 7 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout analysis/productive_pose/tier2_construct.py` (→ Task 4 상태 69480e1; 미커밋이면 수동)

## Task 5: 9 survivor 배치 + tier2_construct.md + GATE
- **Status**: done (commit 1461d82) — 0/9 constructible; severe median 392 (정정 모델로도 미해소); calibration 긴장 → 사용자 surface, Stage-2b 미트리거 · **Prereq tasks**: 4b
- **Files touched**: `analysis/productive_pose/tier2_construct.py`, `analysis/productive_pose/tier2_construct.md`
- **Change shape**: `--batch <manifest>` 추가(tier2_survivors.txt 순회) → 9 survivor 전부 **정정 모델
  (Task 4b)** 로 채점 → `tier2_construct.md`: per-survivor 표(constructible / **Nζ-carbonyl** / Nζ–Sγ /
  clash_count / severe_count / hinge° / strain / best lys) + **GATE 판정**. GATE = post-fix clash
  landscape 보고 확정: constructible = (Nζ-carbonyl near-attack 도달 AND severe 허용) → 후보 목록, 또는
  "0 constructible → 강한 음성, Stage 2b SKIP". ⚠️ **post-fix에도 calibration 긴장(예: 도달하나 severe
  잔존, 또는 carbonyl 잔차)이 남으면 강한-음성 선언 전 사용자에 surface**(REVISION-1 교훈). MRT6160
  anchor 노트.
- **Verification**: `$PY analysis/productive_pose/tier2_construct.py --batch analysis/productive_pose/tier2_survivors.txt`
  후 `cat analysis/productive_pose/tier2_construct.md` → 9행 표(Nζ-carbonyl + Nζ-Sγ + severe) + GATE 줄.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm analysis/productive_pose/tier2_construct.md`; batch 플래그 되돌림

## Phase C — GPU 국소 confirm (GATED, contingent on Task 5)

## Task 6: tier2_md_prep.py — reduced subsystem restrained-MD 입력 (no submit)
- **Status**: SKIPPED (Task 5 GATE=0 constructible → contingent SKIP per plan)
- **Prereq tasks**: 5
- **Files touched**: `analysis/productive_pose/tier2_md_prep.py`
- **Change shape**: constructible 포즈마다 **reduced subsystem 추출**(chain E=UBE2D2 + chain U=Ub C-term +
  chain V의 C-SH3 resi 782–842; CRBN/DDB1/CUL4/RBX1/LIG/Zn **제거**) → OpenMM restrained-MD 입력 구성
  (ff14SB + implicit GBSA, Nζ–Sγ 조화 거리 restraint = near-attack, 도메인 core position restraint).
  첫 단계 = **toolchain preflight**(OpenMM import 가능? 아니면 가용 엔진으로 폴백/보고). per-pose 입력 +
  run manifest 기록. **제출 없음.**
- **Verification**: `$PY -c "import openmm; print(openmm.version.version)"` (preflight) ;
  `$PY analysis/productive_pose/tier2_md_prep.py --construct analysis/productive_pose/tier2_construct.md --dry-run`
  → constructible 포즈별 MD 입력 파일 + restraint 스펙 출력; 잡 미제출.
- **Estimated time**: 7 min
- **Rollback (if this task only)**: `rm analysis/productive_pose/tier2_md_prep.py` + 생성 입력 삭제

## Task 7: [★GATE/SLURM] 짧은 restrained/equil MD 제출
- **Status**: SKIPPED (0 constructible → GPU 미트리거; 게이트 미도달)
- **Prereq tasks**: 6
- **Files touched**: `analysis/productive_pose/tier2_slurm_confirm.sh`
- **Change shape**: constructible reduced subsystem마다 짧은 restrained→free equilibration MD(수 ns) 실행
  SLURM 스크립트; readout = near-attack Nζ–Sγ 시계열. **constructible=0 → SKIP.** ⚠️ sbatch는 Stage-2a
  게이트 통과 + 명시적 사용자 go 후에만(상위 contract 20260612 + 본 sub-contract authorize).
- **Verification**: `squeue -u $USER` → 잡 running/queued; 완료 후 per-pose trajectory + Nζ–Sγ 시계열 파일.
- **Estimated time**: prep 5 min (MD wall-clock 별도)
- **Rollback (if this task only)**: `scancel <jobids>` + GPU 출력 디렉토리 삭제

## Task 8: tier2_confirm.md — basin 안정성 분석
- **Status**: SKIPPED (Stage-2b 미실행 → 분석 대상 없음)
- **Files touched**: `analysis/productive_pose/tier2_confirm.md`
- **Change shape**: Stage-2b trajectory 분석 → 포즈별 basin 안정성: near-attack populated fraction,
  restraint 해제 후 평균 Nζ–Sγ, RMSD. 분류 = stable(productive contact confirmed) / unstable(빌드
  아티팩트). Stage 2b SKIP(0 constructible)였으면 강한-음성 사유 기재.
- **Verification**: `cat analysis/productive_pose/tier2_confirm.md` → 포즈별 stability verdict(또는 skip 사유).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm analysis/productive_pose/tier2_confirm.md`

## Phase D — 종합

## Task 9: TIER2_VERDICT.md 종합 + contract/plan 마감 + handoff
- **Status**: done (commit 0cc277a) — verdict=method-limited inconclusive → 통합 CRL 모델링 ESCALATE · **Prereq tasks**: 5, 8
- **Files touched**: `analysis/productive_pose/TIER2_VERDICT.md`
- **Change shape**: Stage 2a(구성가능성) + Stage 2b(안정성) 종합 → 최종 Tier-2 verdict: productive contact
  constructible+stable(어느 포즈) / constructible-unstable / not-constructible. MRT6160 active anchor 정합.
  **한계 명시: pathway/kinetic accessibility 미판정(통합 ensemble 필요, scope 밖) · cross-cullin graft ·
  hinge range 미확보(relative).** 상위 plan(20260612) Task 6–9도 본 결과로 충족됨 명시. contract+plan
  status done + `/handoff`(baton remaining_actions 갱신).
- **Verification**: `cat analysis/productive_pose/TIER2_VERDICT.md` → 최종 verdict + 한계 + 재현; contract/plan frontmatter `done`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm analysis/productive_pose/TIER2_VERDICT.md` (verdict만; 분석 산출 보존)
