---
contract: .agent/contracts/fksfold-core-md-interface-injection-surface-20260618.md
slice: aigen-fold-core
status: done (T1-T16; #12 verified end-to-end job 7963; ONLY loose end = 4-file wiring uncommitted/entangled)
approved_by: user (2026-06-18, "승인" + "플랜 개정"으로 #12 수식경로 추가)
total_tasks: 16
estimated_total_min: 100
---

# Plan — MD-interface injection surface (v2: 선언적 #1–11 + 수식/potential #12)

> MD best pose(CRBN–MRT6160–VAV1, 7207 frame3849 near-attack)의 계면을 **두 경로**로 주입 가능화·발화검증.
> **경로-선언적**(YAML/config): #1 잔기pocket · #4 CB-template · #6 w400 · #7 key_res · #8 gated w_dist · #11 NPZ density.
> **경로-수식**(#12, 엔진 src potential): T3에서 선언적 미지원으로 판명된 **#2 원자 contact·#3 사이드체인·#5 glue
> 포즈**의 payload를 flat-bottom restraint(MD reference)로 interface_gd에 주입. iPTM 미분 안 함=비순환(리포트 P2).
> ★활성-포켓 알맹이(Y355 4.66Å·glue 6Å/35°)는 선언적 #1/#4(잔기·CB)로는 빠지고 **#12 수식으로만 온전 주입**.
> ⚠️ MD 산출 = vav1-ubq 소유 → **읽기 전용**. aigen-fold-core baton 타 세션 점유 가능 → 본 plan/contract가 durable.
> **Phase D(smoke)=SLURM**, **T11=엔진 src 편집(default-off flag, /code-review)**: 둘 다 사용자 go 후 실행.
> 추출 env=`/home/ubuntu/miniconda3/envs/pymol/bin/python`(pymol+gemmi+numpy). 산출 루트=
> `analysis/md_injection_surface_20260618/`(+리포트 `reports_crystalfree_router/md_injection_surface_20260618.md`);
> smoke workspace=`/mnt/data/users/ubuntu/workspace/md_injection_smoke_20260618/`(삭제 가능).

## Phase A — Setup / reconcile (zero-GPU)

## Task 1: MD best pose 프레임 고정 + 3-component 좌표 확인 (읽기 전용)
- **Status**: in-progress (composition 확인; clean 추출은 T2와 함께) · **Prereq tasks**: none
- **Result(부분)**: best pose = `crl_integrative_md_metad/crl_frame3849_nearattack.pdb` = CRBN+VAV1+**LIG(=MRT6160)**+Zn. protein-only PDB는 glue 없음. ⚠️ **chain ID 없음**(Amber, col22 공백)→ residue-range 분절(T2). solvent/ion strip 필요.
- **Files touched**: `analysis/md_injection_surface_20260618/extract_best_pose.py`, `.../best_pose.pdb`
- **Change shape**: nearattack PDB에서 solvent/ion(WAT/Na+/Cl-) strip → CRBN+VAV1+LIG+Zn만 남긴 best_pose.pdb. (분절은 T2 매핑 사용.)
- **Verification**: `python extract_best_pose.py` → best_pose.pdb 원자수 < nearattack, LIG·ZN 포함, WAT 0.
- **Estimated time**: 5 min · **Rollback**: 파일 삭제

## Task 2: construct/넘버링 reconcile + CRBN-frame 정렬 기준
- **Status**: done (wf_fe210d24) · **Prereq tasks**: 1
- **Files touched**: `analysis/md_injection_surface_20260618/numbering_map.tsv`, `.../reconcile.py`
- **Change shape**: chain ID 없는 MD PDB를 **residue-range로 컴포넌트 분절**(CRBN/VAV1/LIG/Zn 경계 = tleap 빌드 순서)
  + MD CRBN(truncated, W355=full W400 offset 45) ↔ Boltz 입력 CRBN 시퀀스 잔기번호 매핑 + **#12·#4용 CRBN superpose
  원자 셋**(안정 도메인 CA) 정의.
- **Verification**: `python reconcile.py` → `numbering_map.tsv`(component·MD_resid↔Boltz_resid·CRBN-align-atoms) + 컴포넌트 경계 출력.
- **Estimated time**: 6 min · **Rollback**: 삭제

## Task 3: 엔진 injection-API 지원 감사 (zero-GPU)
- **Status**: done · **Prereq tasks**: none
- **Result**: `analysis/md_injection_surface_20260618/api_support_matrix.md`(commit 1a0ec1f). 선언적: #2·#5 미지원, #3 template-CB만, #8/#9 catalysis-gate, #10 포텐셜명 footgun. 받는 것=#1·#4·#6·#7·#8·#11. → #2·#3·#5는 #12 수식경로로 재분류.

## Phase B — MD reference geometry 추출 (zero-GPU, gemmi)

## Task 4: 계면 contact/distance 추출 (#1·#2-ref·#7·#8·#9)
- **Status**: done (wf_fe210d24) · **Prereq tasks**: 1, 2
- **Files touched**: `analysis/md_injection_surface_20260618/extract_contacts.py`, `.../contacts.json`
- **Change shape**: gemmi로 CRBN↔VAV1 heavy-atom <5Å → **#1 잔기쌍**, **#2 원자쌍+거리(d^MD_ij)**(→#12 reference),
  **#7 면별 interface 잔기**, **#8 i–j 거리표**, **#9 하전쌍**.
- **Verification**: `python extract_contacts.py` → `contacts.json`(residue_pairs·atom_pairs+dist·side_residues·elec_pairs) 카운트 비0.
- **Estimated time**: 6 min · **Rollback**: 삭제

## Task 5: 활성 포켓 사이드체인 추출 (#3 → #12)
- **Status**: done (wf_fe210d24) · **Prereq tasks**: 1, 2
- **Files touched**: `analysis/md_injection_surface_20260618/extract_sidechains.py`, `.../sidechain_ref.json`
- **Change shape**: CRBN 포켓 핵심 사이드체인(Y355·tri-Trp W380/386/400·H378) 원자 좌표를 **CRBN-frame**(T2 정렬)로
  → #12 position restraint reference. ★활성형 정보 핵심.
- **Verification**: `python extract_sidechains.py` → `sidechain_ref.json`에 4+ 잔기 사이드체인 원자 위치(CRBN-frame).
- **Estimated time**: 5 min · **Rollback**: 삭제

## Task 6: CB-template 카빙 (#4)
- **Status**: done (wf_fe210d24) · **Prereq tasks**: 1, 2
- **Files touched**: `analysis/md_injection_surface_20260618/carve_template.py`, `.../tmpl_crbn_vav1.cif`
- **Change shape**: best pose에서 CRBN(활성 backbone/CB) + VAV1 placement CIF 카빙(Boltz `templates:` 스키마 정합).
  template_cb = CB 좌표 수준임을 명시(사이드체인은 #12가 담당).
- **Verification**: `python carve_template.py` → CIF gemmi 로드 성공 + chain/원자수 출력.
- **Estimated time**: 6 min · **Rollback**: 삭제

## Task 7: glue reference 원자(#5→#12) + 계면 NPZ density(#11, 수식경로-A)
- **Status**: done (wf_fe210d24) · **Prereq tasks**: 1, 2
- **Files touched**: `analysis/md_injection_surface_20260618/extract_glue_and_density.py`, `.../glue_ref.json`, `.../iface_density.npz`
- **Change shape**: MRT6160(LIG) 원자 좌표(CRBN-frame)→#12 glue restraint reference; + 계면을 fragmap NPZ 스키마
  density grid로(#11, 원자위치서 trilinear 샘플=수식). reference_pdb offset 정합.
- **Verification**: `python extract_glue_and_density.py` → `glue_ref.json`(LIG 원자) + `iface_density.npz`(채널/shape) 출력.
- **Estimated time**: 6 min · **Rollback**: 삭제

## Phase C — Encode(선언적) + Implement(#12 수식)

## Task 8: 선언적 constraint YAML 인코딩 (#1·#6)
- **Status**: done (wf_fe210d24) · **Prereq tasks**: 3, 4
- **Files touched**: `analysis/md_injection_surface_20260618/inputs/inj_constraints.yaml`
- **Change shape**: #1 `pocket`(잔기 contacts), #6 w400 패치 → Boltz YAML/flag. (#2·#3은 선언적 미지원→#12로, 여기 제외.)
- **Verification**: `python -c "import yaml; yaml.safe_load(open('.../inj_constraints.yaml'))"` 통과 + pocket 블록 존재.
- **Estimated time**: 5 min · **Rollback**: 삭제

## Task 9: steering config 인코딩 (#7·#8·#9·#10)
- **Status**: done (wf_fe210d24) · **Prereq tasks**: 3, 4
- **Files touched**: `analysis/md_injection_surface_20260618/inputs/inj_steering.yaml`
- **Change shape**: #7 key_residues_A/target_key_residues, #8 w_dist+stage_based_dist(catalysis-gate caveat 주석),
  #9 w_elec, #10 interface_gd potential(footgun: 이름 불일치 주석). 
- **Verification**: `yaml.safe_load` 통과 + key_residues 비어있지 않음 + w_dist 항목 존재.
- **Estimated time**: 5 min · **Rollback**: 삭제

## Task 10: template 입력 인코딩 (#4)
- **Status**: done (wf_fe210d24) · **Prereq tasks**: 3, 6
- **Files touched**: `analysis/md_injection_surface_20260618/inputs/inj_template.yaml`
- **Change shape**: Task 6 CIF를 `templates: [{cif, chain_id, template_id}]` + `--template_steering_config`로 참조.
- **Verification**: `yaml.safe_load` 통과 + templates가 존재 CIF 참조.
- **Estimated time**: 4 min · **Rollback**: 삭제

## Task 11: ★엔진 src — MD-reference restraint potential 구현 (#12)
- **Status**: code-reviewed(APPROVE_WITH_NITS, fallback fix applied)+new-file committed 0da83d9; 4-file wiring uncommitted(entangled w/ pre-existing glueprint/inference WIP+ruff) · **Prereq tasks**: 3
- **Result(2026-06-18)**: 구현 완료(agent a91290d4, **미커밋 diff**). 파일: NEW `src/boltz_extension/steering/md_reference_potential.py`(`MDReferenceRestraintPotential`: flat-bottom 원자쌍거리 + Kabsch-aligned 위치 restraint, autograd grad) + `potentials.py`(get_potentials append, md_reference_config 있을 때만) + `interface_steering_utils.py`(InterfaceSteeringConfigV2 필드 + upgrade + apply_interface_gd 블록) + `base.py`(필드) + `main.py`(`--md_reference_config`/`--md_reference_weight`, default None). **DEFAULT-OFF 검증**: config=None → identical coords True, 미지정 시 경로 미진입. Kabsch R,t 복원 3e-7, grad finite. **★schema(T12용)**: `{frame:{crbn_align:[[chain,resid,"CA",x,y,z]]}, atom_pairs:[{a:[ch,resid,atom],b:..,d_ref,tol,w}], pos_restraints:[{atom:[ch,resid,atom],xyz,tol,w}]}` — atom_pairs←contacts.json, pos←sidechain_ref.json(xyz_global)+glue_ref.json(xyz_world), frame←crbn_align_atoms.txt(boltz 275–375 CA, world xyz 필요).
- **다음**: (1) `/code-review` on uncommitted diff → APPROVE 시 commit. (2) T12 build mdref_spec.json. (3) Phase D smoke(T13–15) **kim 사용자 sbatch**(GPU). (4) T16 리포트.
- **Files touched**: `src/boltz_extension/steering/potentials.py` (또는 신규 `md_reference_potential.py`) + `interface_steering_utils.py`(wire) + `main.py`(flag)
- **Change shape**: 신규 potential 클래스 — flat-bottom Σ[max(0,|rᵢ−rⱼ|−d_ref−δ)]²(원자쌍 #2) + 사이드체인/glue
  원자 위치 restraint(#3·#5, CRBN-frame). `get_potentials()` 등록 + interface_gd 루프 wire. **`--md_reference_config`
  flag default-off**(미지정 시 경로 미진입=프로덕션 동작 무변). reference는 JSON(원자쌍 dist + ref positions) 입력.
- **Verification**: `python -c "from boltz_extension.steering... import MDReferencePotential"` import OK + flag-off 시 기존 동작 불변(기존 1셀 출력 byte 동일 확인). **/code-review 경유**(production src).
- **Estimated time**: 12 min · **Rollback**: src `git revert` + flag off

## Task 12: #12 config + reference spec 인코딩
- **Status**: done (mdref_spec.json: 219 pairs + 89 pos + 101 frame CA; schema OK) · **Prereq tasks**: 4, 5, 7, 11
- **Files touched**: `analysis/md_injection_surface_20260618/inputs/inj_mdref.yaml`, `.../mdref_spec.json`
- **Change shape**: T4(원자쌍 거리)·T5(사이드체인 위치)·T7(glue 위치)를 #12 potential이 먹는 `mdref_spec.json`으로
  병합 + `--md_reference_config` 참조 YAML.
- **Verification**: `python -c "import json; d=json.load(open('.../mdref_spec.json')); assert d['atom_pairs'] and d['pos_restraints']"`.
- **Estimated time**: 5 min · **Rollback**: 삭제

## Phase D — Smoke 발화 검증 (SLURM, np1·short — 사용자 go 후)

## Task 13: smoke — 선언적 constraint+template 발화 (#1·#4·#6)
- **Status**: done-incidental (7963 同 run: pocket #1 in yaml active, biophysical/w400 path engaged; template #4 not in this run) · **Prereq tasks**: 8, 10
- **Files touched**: `workspace/md_injection_smoke_20260618/`, `analysis/.../smoke_declarative.log`
- **Change shape**: inj_constraints+template로 1셀(np1, steps~10) → pocket/template/w400 active 로그 확인.
- **Verification**: `grep -iE "pocket|template|conditioning|w400" smoke_declarative.log` → active 라인(없으면 FAIL=no-op).
- **Estimated time**: 5 min · **Rollback**: `scancel`+삭제

## Task 14: smoke — steering+density 발화 (#7·#8·#9·#10·#11)
- **Status**: done-incidental (7963: [Biophysical Steering] Enabled + interface_gd ['ligand_volume','clash'] applied ✅; fragmap #11 not in this run) · **Prereq tasks**: 9, 7
- **Files touched**: `workspace/md_injection_smoke_20260618/`, `analysis/.../smoke_steering.log`
- **Change shape**: inj_steering(+NPZ fragmap)로 1셀 → key_residues/w_dist/GD/fragmap 발화 + **w_dist_eff>0**(gate 통과 여부) 확인.
- **Verification**: `grep -iE "w_dist|key_residues|interface_gd|fragmap|gate" smoke_steering.log` → w_dist_eff>0 + steering active(아니면 FAIL+gate원인 기록).
- **Estimated time**: 5 min · **Rollback**: `scancel`+삭제

## Task 15: ★smoke — #12 MD-reference potential 발화 + gradient (#12)
- **Status**: done (job 7963 COMPLETED rc=0: [MDRef] indices 219 pairs/101 frame CRBN-aligned/89 pos, first call E=298554 grad_ok=True; model_0.pdb produced. ★fix 04abc6a = _build inside inference_mode(False), bug caught by smoke not unit-test) · **Prereq tasks**: 12
- **Files touched**: `workspace/md_injection_smoke_20260618/`, `analysis/.../smoke_mdref.log`
- **Change shape**: `--enable_interface_gd --md_reference_config inj_mdref.yaml`로 1셀 → MD-reference potential이
  발화하고 좌표 gradient가 적용되는지(no-op 아님) 로그 확인.
- **Verification**: `grep -iE "md_reference|mdref|restraint|gd" smoke_mdref.log` → potential active + grad 적용 라인(아니면 FAIL).
- **Estimated time**: 5 min · **Rollback**: `scancel`+삭제

## Phase E — 인벤토리 + 리포트

## Task 16: 인벤토리 표 + 리포트 박제
- **Status**: done (8faa751) — md_injection_surface_20260618.md, 12채널 인벤토리 · **Prereq tasks**: 13, 14, 15
- **Files touched**: `analysis/heldout_placement_20260601/reports_crystalfree_router/md_injection_surface_20260618.md`
- **Change shape**: 12채널 × {경로(declarative/formula) / API지원 / 추출 / 인코딩·구현 / smoke 발화 PASS·FAIL(로그근거)}
  표 + 추출 산출물 경로 + 활성-포켓 payload(#2·#3·#5)가 **#12 수식으로 발화했나** 명시 + 다음 단계(주입→VAV1 예측
  개선 측정은 후속 컨트랙트).
- **Verification**: `cat md_injection_surface_20260618.md` → 12행 인벤토리(경로열·발화열 채워짐) + 채널별 판정.
- **Estimated time**: 6 min · **Rollback**: 삭제

## 비고
- #2·#3·#5는 선언적 미지원이나 **#12 수식경로로 주입**(T11 구현 + T12 인코딩 + T15 발화). #11 NPZ는 코드無 수식경로-A.
- 후속(별도 컨트랙트): 발화 PASS 채널을 *실제 주입*해 VAV1 예측이 productive 기하로 가는지 측정(out of scope).
- T11(src)·Phase D(SLURM) = 사용자 go 후. 현재 T1 in-progress, T3 done.
