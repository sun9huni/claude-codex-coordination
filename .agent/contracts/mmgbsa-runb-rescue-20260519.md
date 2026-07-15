# Contract: MMGBSA RunB Rescue Lane (normtest143)

- Date: 2026-05-19
- Owner: claude
- Slice: `mmgbsa`
- Status: **draft, awaiting user approval before any SLURM submission**.
- Linked status: `.agent/status/mmgbsa.md`
- Linked harness: `.agent/projects/fksfold-mmgbsa-slurm-harness.md`

## Why this contract

normtest143 RunA-paired RunB end-to-end가 끝났지만 Stage 1 prepare에서 **18 compound 실패**. Stage 2/3는 100% 완주(37/37)이라 병목은 RunB(binary) equilibration. 같은 compound가 RunA(ternary)에서는 통과했으므로 ligand 구조나 force field 자체 문제는 아니고, **CRBN-LIG binary에서 ligand 고정도가 떨어져 NVT 초기에 hang하거나 equilibration이 timeout까지 늘어진다는 가설**.

이 contract는 SLURM 재제출이 아닌 **rescue 정책 설계와 검증 plan**을 정의한다.

## Failure inventory (n=18, 전부 Stage 1 prepare)

| 패턴 | n | last_step | last_time_ps | fatal_signature | 가설 |
|---|---|---|---|---|---|
| `acpype_timeout` | 2 | — | — | (acpype 단계) | ligand parameterization 자체 한계. 더 큰/conjugated ligand 의심. |
| `early_nvt_hang` | 8 | ~7500 | ~1.87 | `NO_PROGRESS_TIMEOUT` | 01_nvt 초기 (~2 ps)에서 GPU/CPU 진행 멈춤. rescue 후에도 NO_PROGRESS. |
| `early_nvt_hang` | 7 | 84k–981k | 21–981 | `HARD_TIMEOUT` | 02_nvt safe까지 진행은 됐으나 너무 느려 hard cap에 걸림. |
| `post_rescue_02_nvt_lincs` | 1 | 775k | 775 | `NO_PROGRESS_TIMEOUT` | rescue 후 LINCS instability 재발 (VAV1_471). |

대상 compound (예시): VAV1_{349, 463, 489, 325, 417, 187, 372, 101, 388, 280, 352, 292, 193, 345, 439, 200, 471, 246}.

## Hypotheses to test

H1. **NVT timestep이 RunB binary에 비해 너무 큼.** RunA ternary에서는 VAV1과 CRBN이 양쪽에서 ligand를 잡아주지만, RunB binary는 CRBN만 잡으므로 ligand가 더 자유로움. dt=2 fs가 marginal pose에서 LINCS/SETTLE을 깨뜨릴 수 있다.

H2. **Posre가 binary에서 ligand 쪽에 부족하다.** RunA는 ternary interface가 두 단백질을 동시에 묶지만, RunB는 한쪽만이라 ligand가 drift할 시간이 더 큼.

H3. **acpype/AM1-BCC가 특정 ligand에서 수렴 실패.** 두 compound (VAV1_193, 349)는 ligand 자체 화학 구조 문제일 가능성이 높음. rescue로 살리기보다 별도 분리.

H4. **HARD_TIMEOUT 그룹은 실제로는 progress하고 있었으나 NVT safe mode가 너무 느림.** 21–981 ps까지 갔다는 점에서 instability라기보다 wallclock 부족.

## Proposed rescue protocol (draft, not implemented)

별도 `rescue_runb_v1` lane:

```
00_min:    nsteps=200   emtol=5000   emstep=0.01   absolute_max=300s   (현재 fast lane 유지)
01_nvt:    dt=0.0005 fs (was 0.002), nsteps=200000 (=100 ps),
           tc-grps with stronger T coupling, posre on heavy atoms + ligand heavy atoms,
           absolute_max=600s
02_nvt:    dt=0.001, nsteps=500000 (=500 ps),
           gradually relax posre, absolute_max=900s
03_npt:    dt=0.001, nsteps=200000 (=200 ps), Berendsen→Parrinello-Rahman switch only at end
04_npt:    dt=0.002 (normal), nsteps=500000 (=1000 ps), absolute_max=1800s
equi_prod: 동일
```

핵심 변경:
- 01_nvt timestep을 0.5 fs로 시작 (현재 1 fs).
- ligand heavy atom에 명시적 posre (binary fragility 보완).
- 02_nvt를 500 ps로 늘려 HARD_TIMEOUT 그룹이 살 시간 확보.
- 04_npt 진입 전 Berendsen→PR switch를 한 단계 늦춤.

acpype_timeout 2개(VAV1_193, 349)는 rescue lane 제외, **별도 ligand-parameterization audit**으로 분리.

## Verification plan (no SLURM yet)

1. **Diff-first.** Stage 1 worker script에 위 protocol 적용한 patch를 `.agent/scratch/`에 저장하고 diff 검토 (Stage 1 본체 변경 금지).
2. **Dry-run smoke.** 1 compound (예: VAV1_463)로 inline test. SLURM 없이 한 GPU에서 단독 실행, last_step / log tail 확인.
3. **Smoke 통과 후에만** rescue lane SLURM 제출 안 (1 node × 8 A100, normal QoS) 작성 후 다시 사용자 승인.
4. 통과한 compound는 RunB ready manifest에 append, 기존 paired ΔΔG에 추가.

## Out of scope

- 본 contract는 SLURM 제출을 포함하지 않는다.
- Stage 2 multidir 설정 변경 없음 (16×A100 DPG4 그대로 검증됨).
- 143 panel 확장은 별도 contract.

## Done when

- [ ] H1–H4 가설 검증 결과 정리 (text + plot).
- [ ] rescue protocol patch와 diff 검토 완료.
- [ ] 1-compound dry-run smoke 결과 기록.
- [ ] 사용자 승인 후 rescue lane SLURM 제출안 별도 contract로 분기.

## Approval gates

- **이 contract만으로는 어떠한 SLURM 제출도 하지 않는다.**
- patch 작성 → diff 리뷰 → smoke 결과 → 사용자 승인 → SLURM contract 신설.
- `failed_stage.tsv` legacy dedup도 사용자 승인 후 별도 작업.
