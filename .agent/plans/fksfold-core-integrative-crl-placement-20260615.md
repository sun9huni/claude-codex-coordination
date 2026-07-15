---
contract: .agent/contracts/fksfold-core-integrative-crl-placement-20260615.md
slice: vav1-ubq
status: in-progress
total_tasks: 9
estimated_total_min: 39
---

# Plan — 통합 CRL 모델링 (flexible cullin/neddylation → productive E2-module placement)

> **✅ UNBLOCKED — 구조 확보 완료 (2026-06-15, commit 3b47a05).** NEEDS-DATA→PATH-EXISTS→
> **ACQUIRABLE-NOW**: **9UUM**(mezigdomide CRL4-DDB1-CRBN-IKZF3-UbcH5a~Ub ubiquitylation
> assembly, 3.41Å, RCSB 2026-06-10 공개)을 `refs/9UUM.cif`로 다운로드+실측 검증(8 chains/
> 20807 atoms; CRBN/UBE2D1/NEDD8/Ub/RBX1/DDB1/CUL4A+IKZF3 전부). **단일 공개 구조에 coherent
> neddylated active CUL4 + RING-engaged E2~Ub 다 포함 → cross-cullin graft·생성경로 전부 불요.**
> **Stage A recipe 정정(단일소스)**: 다중-source graft → **9UUM 촉매-half(CUL4A-NEDD8-RBX1-
> UbcH5a~Ub-DDB1-CRBN) 고정 + IMiD·IKZF3 제거 → MRT6160·VAV1 C-SH3 pose를 CRBN에 도킹**(within-
> family substrate swap). Tasks 1–2 done; **다음 = Task 3(재구축)**. fallback(9V0F 3.71Å 백업).

> **★LOAD-BEARING GATE**: Task 1(입력 구조 확보) 이 contract 전체의 전제다. coherent
> neddylated active-CRL4–E2~Ub 구조가 확보 불가면 **Task 1에서 NEEDS-DATA hard stop**
> (Tasks 2–9 차단; rebuild/NMA/MD 진입 금지, RCSB 큐레이션 선행).
> **3단계 staged, 각 compute 에스컬레이션 = 사용자 go 게이트**: Stage A(재구축 zero-GPU)
> → Stage B(NMA 저비용 CPU) → Stage C(enhanced-sampling MD GPU, Task 7에서 정지).
> 실행 env = `/home/ubuntu/miniconda3/envs/pymol/bin/python`(이하 `$PY`). frozen 임계 =
> `analysis/productive_pose/reach_envelope.md`(near-attack ≤3.5Å). 산출 dir =
> `analysis/crl_integrative/`(신규; GPU 출력만 `/mnt/data/users/ubuntu/workspace`).

## Phase A — 입력 구조 + 재구축 (zero-GPU)

## Task 1: neddylated CRL4–E2 입력 구조 recon + AVAILABLE/NEEDS-DATA 판정 (★GATE)
- **Status**: done (ffacc48 NEEDS-DATA → 심층조사 8dfc872 PATH-EXISTS → **확보 3b47a05 ACQUIRABLE-NOW**) — 9UUM 확보로 게이트 통과 · **Prereq tasks**: none
- **Files touched**: `analysis/crl_integrative/structure_sources.md`
- **Change shape**: PDB/문헌 recon으로 coherent **neddylated active-CRL4–E2~Ub** 구조를
  탐색(후보: NEDD8-conjugated CUL4–RBX1 cryo-EM + RING-engaged E2~Ub; 단일 cullin 계열).
  각 후보의 제공 성분(CUL4A/RBX1/NEDD8/DDB1/UBE2D2/Ub) · 해상도 · **E2~Ub–RING 결합(active
  arm) 존재 여부** · 결손 성분(별도 graft 필요분)을 표로 기록. 마지막 줄 = **판정**:
  `AVAILABLE`(후보 PDB ID 목록 + 재구축 경로) 또는 `NEEDS-DATA`(coherent neddylated
  active CRL4–E2 부재 → STOP, 큐레이션 필요 사유). fabricate-0(PDB ID·해상도 실측).
- **Verification**: `cat analysis/crl_integrative/structure_sources.md` → 후보 표 +
  성분 매핑 + `판정: AVAILABLE|NEEDS-DATA` 줄 1개.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm analysis/crl_integrative/structure_sources.md`

## Task 2: 선택 참조 구조 다운로드 (refs/)
- **Status**: done (commit 3b47a05) — 9UUM.cif(+9V0F 백업) refs/ 다운로드+실측 검증. ⚠️ Task 3 recipe = **단일소스 9UUM substrate-swap**(다중-source graft 아님; 상단 배너 참조)
- **Prereq tasks**: 1
- **Files touched**: `analysis/crl_integrative/fetch_refs.sh`, `analysis/crl_integrative/refs/` (다운로드 산출)
- **Change shape**: Task 1이 고른 PDB ID들을 RCSB에서 받는 스크립트(`fetch_refs.sh`,
  curl/wget cif|pdb → `refs/`). 멱등(이미 있으면 skip). VAV1(AF-P15498)·MRT6160 pose 등
  기존 보유분은 경로 재사용(재다운로드 안 함). read-only 입력 확보만.
- **Verification**: `bash analysis/crl_integrative/fetch_refs.sh && ls analysis/crl_integrative/refs/`
  → Task 1 목록의 각 구조 파일 존재(`test -f` 통과).
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `rm -rf analysis/crl_integrative/refs/ analysis/crl_integrative/fetch_refs.sh`

## Task 3: crl_rebuild.py — coherent neddylated CRL4 시스템 재구축
- **Status**: done (commit e0f6396) — 9UUM substrate-swap; CRBN 중첩 1.309Å; 9 component, IKZF3·mezigdomide 제거, downstream id 보존 · **Prereq tasks**: 2
- **Files touched**: `analysis/crl_integrative/crl_rebuild.py`
- **Change shape**: 참조 구조들을 단일 좌표계로 조립: **단일 cullin 계열**(cross-cullin
  키메라 제거) + **NEDD8 명시 포함**(CUL4 WHB conjugation site) + DDB1–CUL4–RBX1 scaffold
  + E2(UBE2D2 cat Cys85)~Ub(Gly76) RING-engaged + VAV1 C-SH3(resi 782–842, MRT6160 anchor
  보존). 단일 프레임 clean PDB 저장(`crl_system.pdb`). 강체 super 정렬 가교는 swept_reach/
  complete_structure 패턴 재사용. (이완·MD는 후속 task.)
- **Verification**: `$PY analysis/crl_integrative/crl_rebuild.py --out /tmp/crl_system.pdb`
  → 체인 인벤토리 출력 + `/tmp/crl_system.pdb` 존재.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm analysis/crl_integrative/crl_rebuild.py`

## Task 4: crl_rebuild.py — sanity 검증 + Stage A 게이트
- **Status**: done (commit 2769e45) — **Stage A gate: PASS** (10/10: 단일 CUL4A·키메라0·NEDD8·Cys85 Sγ·Ub Gly76 C·SH3 5/5·IKZF3·QFC 제거) · **Prereq tasks**: 3
- **Files touched**: `analysis/crl_integrative/crl_rebuild.py`
- **Change shape**: `--verify` 추가: assert(**cross-cullin 키메라 0** = 단일 cullin 계열 /
  **NEDD8 존재** / chain E Cys85 Sγ n==1 / chain U last-Gly C 존재 / SH3 lysine
  K788/804/810/814/815 존재) + MRT6160/anchor super RMSD 게이트 출력. 통과 = Stage A 완료
  (Stage B 진입 허용); 실패 = 사유 보고 + 정지.
- **Verification**: `$PY analysis/crl_integrative/crl_rebuild.py --verify --in /tmp/crl_system.pdb`
  → `chimera: 0`, `NEDD8: present`, `Cys85 Sγ: n=1`, `Ub Gly76 C: present`, `SH3 Lys: 5/5`,
  `anchor RMSD: <gate>` 전부 PASS.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout analysis/crl_integrative/crl_rebuild.py` (→ Task 3 상태; 미커밋이면 수동)

## Phase B — NMA/ENM 모드 진단 (저비용 CPU, 게이트)

## Task 5: crl_nma.py — cullin-arm 저주파 모드 + reach landscape + 게이트
- **Status**: done (commit 80219d2) — **Stage B gate: productive 모드 NO** (starting Nζ→carbonyl 10.66Å[K788]; thioester 3.44Å 정상; 저주파 모드 최대 closure 0.87Å). ANM coarse → 강한-음성 자동선언 금지, **사용자 surface**(Task 6–7 보류) · **Prereq tasks**: 4
- **Files touched**: `analysis/crl_integrative/crl_nma.py`, `analysis/crl_integrative/crl_nma.md`
- **Change shape**: 재구축 시스템에 ENM/NMA(ProDy 등; import preflight 후 가용 라이브러리로
  폴백·보고) → 저주파 모드별 **E2~Ub 모듈을 substrate(SH3) 쪽으로 swing시키는가** 판정 +
  모드 진폭 대비 **min Nζ–carbonyl + severe clash** 스캔(zero-MD reach landscape). `crl_nma.md`
  = 모드 표 + "**productive swing 모드 존재** y/n" 게이트. 부재 시 → enhanced-sampling 정당성
  **사용자 surface**(강한-음성 자동선언 금지, Tier-2 교훈).
- **Verification**: `$PY analysis/crl_integrative/crl_nma.py --in /tmp/crl_system.pdb` 후
  `cat analysis/crl_integrative/crl_nma.md` → 모드 표(freq/swing y-n/min Nζ-carbonyl/severe)
  + `productive 모드: yes|no` 게이트 줄.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm analysis/crl_integrative/crl_nma.py analysis/crl_integrative/crl_nma.md`

## Task 5b: [Stage B 게이트 후속] crl_pose_scan.py — 9 survivor pose/register starting-gap 스캔 (zero-GPU)
- **Status**: done (commit 887452f) — **MD 유망**: best **2Con_0_seed314 K810 = 5.46Å**(+Cys85 Sγ 4.19Å), 7/9 ≤8.2Å. seed42 음성(10.66Å)은 pose-한정. Stage C 후보 = 2Con_0_seed314(K810) · **Prereq tasks**: 5
- **Files touched**: `analysis/crl_integrative/crl_rebuild.py`(--donor 인자 추가, 하위호환), `analysis/crl_integrative/crl_pose_scan.py`, `analysis/crl_integrative/crl_pose_scan.md`
- **Change shape**: Stage B가 단일 pose(completed_seed42, starting 10.66Å)에서 productive 모드 no를 냈으므로,
  9 survivor 각각을 donor로 substrate-swap해 **활성 9UUM 프레임에서 starting min Nζ→Ub carbonyl**을 비교.
  crl_rebuild.py에 `--donor <clean.pdb>` 인자 추가(default 현행 completed_seed42 = 하위호환). crl_pose_scan.py
  = 9 survivor의 `/tmp/tier2_clean_batch_20260614/tier2_clean_<pose>.pdb`(없으면 tier2_repair로 재생성)를
  donor로 swap → per-pose (closest lysine, min Nζ–carbonyl, Nζ–Cys85 Sγ, CRBN super RMSD) 측정.
  `crl_pose_scan.md` = 9행 표 + 판정: best starting gap이 10.66Å보다 **유의하게 가까우면 MD 유망**(그 pose로
  Stage C 후보), 아니면 **음성 강화**(전 pose가 멀다 → 사용자 surface). 해석 neutral·evidence-first.
- **Verification**: `$PY analysis/crl_integrative/crl_pose_scan.py` 후 `cat analysis/crl_integrative/crl_pose_scan.md`
  → 9행(pose / closest Lys / min Nζ-carbonyl / CRBN RMSD) + best-gap 판정 줄.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `rm analysis/crl_integrative/crl_pose_scan.py analysis/crl_integrative/crl_pose_scan.md`; `git checkout analysis/crl_integrative/crl_rebuild.py`(미커밋이면 수동)

## Phase C — enhanced-sampling MD (GPU, GATED)

## Task 6: crl_md_prep.py — enhanced-sampling MD 입력 + toolchain preflight (no submit)
- **Status**: done (commit 2e5ccf2) — Task 5b가 MD 유망(K810 5.46Å) 냄 + 사용자 surface 後 진행 승인. **엔진 = OpenMM 네이티브 metadynamics(CUDA)**(PLUMED 부재→GROMACS+PLUMED 기각). param 경로: NEDD8 isopeptide/E2~Ub thioester=explicit bonded patch, MRT6160 리간드=openff 부재이나 **AmberTools antechamber/GAFF2 fallback 가용**(완전차단 아님). primary CV=K810 Nζ↔Ub Gly76 C, anchor 구속. dry-run=무서명 검증(mmgbsa+pymol 양 env). NO SUBMIT
- **Prereq tasks**: 5
- **Files touched**: `analysis/crl_integrative/crl_md_prep.py`
- **Change shape**: enhanced-sampling MD 입력 구성: 力場(protein FF + **NEDD8 isopeptide /
  E2~Ub thioester linkage 파라미터화** 경로 결정·문서화), CV(cullin-arm hinge / Nζ–carbonyl
  거리), restraint, 엔진(OpenMM+PLUMED / GROMACS+PLUMED 중 preflight로 가용 확인). **첫 단계 =
  toolchain preflight**(import 가능? 아니면 폴백/보고). per-후보 입력 + run manifest. **제출 없음.**
- **Verification**: `$PY -c "import openmm; print(openmm.version.version)"` (preflight) ;
  `$PY analysis/crl_integrative/crl_md_prep.py --dry-run --in /tmp/crl_system.pdb` → MD 입력
  파일 + CV/restraint 스펙 출력; 잡 미제출.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm analysis/crl_integrative/crl_md_prep.py` + 생성 입력 삭제

## Task 7: [★GATE/SLURM] enhanced-sampling MD 제출
- **Status**: in-progress (사용자 go "전체 진행" 2026-06-15 → **job 7201 RUNNING** on A100-80GB host-10-0-3-100). System 빌드(470,312원자 ff19SB/TIP3P/GAFF2, VAV1 C-SH3 783-845 절단, MRT6160 GAFF2, 2 crosslink[NEDD8 isopep K705 5.26Å·E2~Ub thioester Cys85 3.44Å CYX], 4 Zn 12-6-4+restraint) + driver(crl_md_run.py: minimize20k→NVT heat→NPT 2ns→metad) 커밋 a2c8cbd. 검증: Stage A PASS·시작 CV 5.46Å 보존·CPU smoke finite+감소. ⚠️첫 제출(7199) 실패=노드가 /home miniconda 미mount → env를 /mnt/data/users/ubuntu/conda_envs/mmgbsa로 수정 후 재제출(7201). 대용량 prmtop/inpcrd=workspace(비추적). 완료 후 Task 8.
- **Prereq tasks**: 6
- **Files touched**: `analysis/crl_integrative/crl_slurm_md.sh`
- **Change shape**: 재구축 시스템 enhanced-sampling MD(metadynamics/REMD 등) 실행 SLURM
  스크립트; readout = near-attack(Nζ–carbonyl) CV 시계열 + 점유율 추정용 trajectory.
  ⚠️ sbatch는 **Stage A/B 게이트 통과 + 명시적 사용자 go 후에만**(상위 2-tier authorize +
  본 contract method pre-register). execute-plan은 본 task에서 정지.
- **Verification**: `squeue -u $USER` → 잡 running/queued; 완료 후 trajectory + CV 시계열 파일.
- **Estimated time**: prep 4 min (MD wall-clock 별도)
- **Rollback (if this task only)**: `scancel <jobids>` + GPU 출력 디렉토리 삭제

## Task 8: crl_confirm.py — populated basin 분석
- **Status**: pending · **Prereq tasks**: 7
- **Files touched**: `analysis/crl_integrative/crl_confirm.md`
- **Change shape**: Stage-C trajectory 분석 → productive near-attack(Nζ–carbonyl ≤3.5Å,
  severe=0) 상태의 **populated fraction + 자유에너지(ΔG) + 수렴 진단**(블록평균/replica 교환율
  등). 분류 = populated(productive 확정·어느 후보·점유율) / 도달하나 미점유 / 미도달.
- **Verification**: `cat analysis/crl_integrative/crl_confirm.md` → 후보별 populated fraction
  + ΔG + 수렴 판정.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm analysis/crl_integrative/crl_confirm.md`

## Phase D — 종합

## Task 9: CRL_VERDICT.md 종합 + contract/plan 마감 + handoff
- **Status**: pending · **Prereq tasks**: 5, 8
- **Files touched**: `analysis/crl_integrative/CRL_VERDICT.md`
- **Change shape**: Stage A(재구축) + B(NMA) + C(점유) 종합 → 최종 판정: productive geometry
  **populated**(어느 후보/점유율) / 도달-미점유 / 미도달 / (NEEDS-DATA로 미착수). MRT6160
  anchor 정합. **한계 명시**(force-field·sampling 수렴·single active-form 가정·rebuild 의존).
  강체 Tier-2(TIER2_VERDICT.md) 결과와의 연속성 — "강체 불충분 → 통합 모델링이 답한 것" 기술.
  contract+plan status done + `/handoff`(baton 갱신).
- **Verification**: `cat analysis/crl_integrative/CRL_VERDICT.md` → 최종 판정 + 한계 + 재현;
  contract/plan frontmatter `done`.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm analysis/crl_integrative/CRL_VERDICT.md`
