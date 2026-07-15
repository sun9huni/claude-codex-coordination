---
status: done
slice: aigen-fold-core
topic: template-steering-crbn-9nfr
date: 2026-06-26
owner: claude
approved_by: sunghoon.kim
requested: 2026-06-26
cross_slice: []
triggers_matched:
  - "SLURM/GPU submission — template-steered 생성 런"
  - "shared-storage writes — /mnt 워크스페이스 생성 출력"
---

# TemplateSteering CRBN 방향 수정 — 9NFR 재현 검증

## Purpose

T14-T14d 진단 결론: **DDB1 스캐폴딩 없이 CRBN TBD가 9NFR 크리스탈 대비 ~20Å 빗나감** → cone apex 기준계 오염 → CRLClosureIK 불능.

해결책: DDB1을 4번째 체인으로 접지 않고, **Boltz 트렁크 레벨 템플릿 컨디셔닝**을 활용한다. 5개의 DDB1-CRBN 복합체 PDB(9UUM + 9V0F + 4TZ4 + 4CI3 + 5HXB)를 YAML `templates:` 블록으로 제공 → `trunkv2.py`가 `template_cb` / `template_mask_cb`를 통해 Boltz 네트워크 내부 표현을 DDB1-bound CRBN conformation으로 conditioning → CRBN이 DDB1-anchored 상태로 fold된다.

**메커니즘 주의사항 (2026-06-26 점검 완료)**:
- 트렁크 컨디셔닝(trunkv2.py): DDB1-CRBN 템플릿으로 작동, `templates:` 블록만 필요. **이것이 CRBN 방향 수정의 실제 메커니즘.**
- TemplateSteering GD(`inject_template_force_feats` + `TemplateReferencePotential`): VAV1 SH3c가 템플릿에 없으면 sh3_mask=0, CRBN anchor 50Å threshold > 현재 RMSD 20Å → **그래디언트 제로**. DDB1-전용 템플릿으로는 GD no-op. `--template_steering_config` 불필요.

**가설**: CRBN_RMSD 20Å → <10Å (9NFR 크리스탈 대비).

## Current State

- **이미 구현된 코드**:
  - `boltz_extension/steering/template_steering.py` — `inject_template_force_feats()` + `build_template_potential()`, 자체검사 통과
  - `TemplateReferencePotential` (`potentials.py`) — `template_force` + `template_force_threshold` 기반 flat-bottom restraint
  - `--template_steering_config` CLI 인수(main.py:1247) — `template_steering` YAML 블록을 읽어 `steering_args.template`에 주입
  - 메커니즘: CRBN 토큰 → anchor_threshold 50Å (rigid align 앵커, 실질 패널티 없음); SH3 토큰 → sh3_threshold 3Å (tight restraint); CRBN 세트가 align을 지배 → SH3 위치가 CRBN-anchored 기준계에서 구속됨
- **기존 3체인 시스템 유지**: CRBN(A) + VAV1 SH3c(B) + MRT23227(C) — DDB1 추가 불필요
- **기존 인프라 재사용**: score_9nfr_dockq.py, contact_recovery.py, score_ik_poscontrol.py, run_ik_9nfr.sh 패턴

## Assumptions And Questions

- assumptions:
  - 9UUM + 9V0F + 4TZ4 + 4CI3 + 5HXB 모두 전장 DDB1-bound CRBN 포함 → trunkv2.py가 CRBN 서열 매핑으로 template_cb 생성.
  - 트렁크 컨디셔닝이 CRBN 방향 수정의 실제 메커니즘. `--template_steering_config` 불필요(GD는 DDB1-전용 템플릿 → zero-gradient로 확인됨).
  - TemplateSteering GD: VAV1 SH3c가 없는 DDB1 전용 템플릿 → sh3_mask=0, CRBN anchor 50Å > 현재 RMSD 20Å → 그래디언트 제로. No-op. 향후 VAV1-containing 템플릿 추가 시 활성화 가능.
  - 5FQD 제외 확정: DDB1 789AA (1-789 = BPC 도메인 1-789까지만, CRBN-binding 말단 BPC 절단됨).
  - 5HXB 추가 확정: DDB1(1080AA) + CRBN(381AA) ×2 사본, BPC 완전 포함.
- open questions:
  - 5개 template 동시 사용 시 Boltz featurizer 처리 방식 (averaging; Task 1 smoke 확인 예정).
- tradeoffs:
  - 5개 템플릿 전부 trunk conditioning → CRBN 방향 prior 강화; 생성 다양성은 CRBN이 고정 scaffold이므로 문제 없음.

## Constraints

- allowed change scope:
  - DDB1-CRBN CIF 다운로드(완료): 4TZ4, 4CI3, 5HXB, 9V0F → `analysis/crl_integrative/refs/` ✓
  - 기존 9NFR YAML 기반 새 YAML: `templates:` 블록 추가 (5개: 9UUM + 9V0F + 4TZ4 + 4CI3 + 5HXB)
  - 신규 런처: `run_template_9nfr.sh` (기존 run_ik_9nfr.sh 패턴 기반)
  - 신규 결과 MD: `analysis/crl_integrative/template_9nfr_results.md`
- forbidden change scope:
  - `template_steering.py`, `potentials.py`, `diffusionv2_extend.py` 코드 변경 금지 (additive only = 설정만)
  - 기존 9NFR 크리스탈 refs 변경 금지
  - MRT6160 실험은 이번 범위 밖
  - DDB1 체인을 YAML에 추가하지 않음 (3체인 유지)
- external constraints:
  - GPU: un-containerize(boltz_native) + kim batch; free-GPU selector(memory.free>75GB)
  - SLURM: sudo -u kim sbatch ... --submit
  - 출력: /mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/
  - 출력 디렉토리 chmod 777 필요

## Non-Goals

- DDB1을 4번째 체인으로 추가하는 접근 (이번 범위 밖)
- MRT6160 template steering (9NFR GATE 통과 후 별도)
- TemplateSteering 코드 개선 / guidance_weight 스윕
- near_attack ≥2/3 GATE (이번 주목표는 CRBN 배치, near_attack 참고용)
- VAV1 SH3c에 대한 template restraint (9UUM에 VAV1 없음 → SH3 restraint 없음이 정상)

## Done When

- **GATE (주)**: ARM-0 (template-only, IK 없음) CRBN_RMSD < 10Å vs 9NFR 크리스탈, 3 seeds 중 최솟값. 현재 기준선: 18-23Å.
- **비교 지표**: ARM-2 (template+IK) CRBN_RMSD + contact_recovery + cone_dist 측정 (GATE 기준 아님, 보조 정보)
- **결과 문서**: `analysis/crl_integrative/template_9nfr_results.md` — CRBN_RMSD 표(ARM-0/ARM-2 × seeds) + 기존 3체인 대비 비교 + gate 판정
- **GATE PASS 시**: → MRT6160 template steering 컨트랙트로 진행
- **GATE FAIL 시**: CRBN_RMSD 감소 정도 확인 → guidance_weight 조정 여부 결정 또는 DDB1 4체인 접근으로 에스컬레이션

## Implementation Steps

1. **CIF 확인** (zero-GPU) ✓ DONE (2026-06-26)
   - 9UUM, 9V0F, 4TZ4, 4CI3, 5HXB 전부 `analysis/crl_integrative/refs/`에 존재 확인
   - CRBN 체인 + DDB1 체인 서열 길이 점검 완료 (5HXB: DDB1 1080AA + CRBN 381AA ×2; 5FQD 제외 사유: DDB1 789AA = BPC 절단)
   - verify: ✓ (refs/5HXB.cif, 9UUM.cif, 9V0F.cif, 4TZ4.cif, 4CI3.cif 전부 존재)

2. **9NFR YAML + templates 블록 작성** (zero-GPU)
   - 기존 9NFR YAML 기반, `templates:` 블록에 5개 DDB1-CRBN CIF 추가
   - `templates:` 형식: `[{"cif": "/path/to/file.cif"}]` (run_9nfr_template_batch.py 패턴 확인)
   - verify: `python -c "import yaml; d=yaml.safe_load(open('template_9nfr.yaml')); print(len(d['sequences']))"` → 3 체인(CRBN+SH3c+ligand)

3. **런처 작성 + 드라이런** (zero-GPU)
   - `run_template_9nfr.sh`: ARM-0(template-only, IK 없음) / ARM-2(template+IK) × 3 seeds = 6셀
   - `--template_steering_config` 인수 **불필요** (GD zero-gradient 확인됨; trunk conditioning만으로 CRBN 방향 수정)
   - verify: `bash run_template_9nfr.sh --dry-run` → 6셀 목록

4. **[GPU GATE] 생성 런 제출** ⛔ APPROVAL GATE
   - `sudo -u kim sbatch run_template_9nfr.sh --submit`
   - 첫 셀 로그 즉시 모니터링: Boltz template preprocessing 확인 (`templates preprocessed`, `.npz` 생성)

6. **채점 + 결과 문서** (zero-GPU, 생성 후)
   - score_9nfr_dockq.py → CRBN_RMSD + DockQ
   - contact_recovery.py + score_ik_poscontrol.py → CR_n/3 + cone_dist
   - `template_9nfr_results.md` 작성: 전체 표 + 기존 baseline(IK-only, ~20Å) 비교 + gate 판정

## Change Discipline

- simplest adequate approach: 코드 변경 없음 — Boltz 트렁크 컨디셔닝을 YAML `templates:` 블록으로만 활성화. YAML + launcher 2개 신규. (`--template_steering_config` 불필요로 config 파일 1개 감소)
- new abstractions introduced: 없음.
- unrelated code touched: 없음.
- request-to-diff trace: T14/T14d(CRBN 20Å빗나감 = DDB1 absent) → TemplateSteering 발견(기존 구현) → 이 컨트랙트.

## Verification

- Boltz 로그에 `templates preprocessed` + `.npz` 파일 생성 확인 — 트렁크 컨디셔닝 활성화 증거
- `analysis/crl_integrative/template_9nfr_results.md` 존재 + CRBN_RMSD 표 + gate 판정
- Chrome QA: N/A

## Risks

- **트렁크 컨디셔닝이 충분하지 않을 가능성**: 20Å CRBN 편차가 DDB1 부재 외 다른 원인(예: VAV1 SH3c-CRBN interface OOD)에서도 기인할 수 있음. GATE FAIL 시 → DDB1 4체인 접근 에스컬레이션.
- **5개 template 처리**: Boltz trunkv2.py가 template 수 무제한 averaging (mask 기반). CRBN 서열이 5개 모두 매핑 가능해야 함 (Task 2에서 확인).
- **VAV1 배치는 여전히 Boltz prior 의존**: 템플릿에 VAV1 없음 → VAV1 배치 = Boltz prior. ARM-2(IK)가 보완하나 CRBN 방향이 먼저 수정되어야 IK 정상 작동.

## Rollback

- revert strategy: 설정 파일 + launcher만 신규 — 삭제로 완전 롤백. 코드 변경 없음.
- containment strategy: 출력 `/mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/` 격리; 기존 ik_9nfr_20260625/ 건드리지 않음.

## Progress Log

- 2026-06-26: initial draft (brainstorm). 이전 DDB1 4체인 접근(v1)에서 TemplateSteering 활용(v2)으로 변경 — 기존 구현 발견으로 훨씬 단순해짐.
- 2026-06-26 (점검 완료): 메커니즘 분석 결과 트렁크 컨디셔닝이 실제 메커니즘; TemplateSteering GD는 DDB1-전용 템플릿 → zero-gradient (SH3 없음). PDB 점검: 5FQD 제외(DDB1 789AA 절단) → 5HXB 추가(DDB1 1080AA 완전, CRBN 381AA ×2). 최종 템플릿: 9UUM + 9V0F + 4TZ4 + 4CI3 + 5HXB. `--template_steering_config` 불필요.
