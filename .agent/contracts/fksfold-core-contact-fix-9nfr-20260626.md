---
status: done
slice: aigen-fold-core
topic: contact-fix-9nfr
date: 2026-06-26
owner: claude
approved_by: sunghoon.kim
requested: 2026-06-26
cross_slice: []
triggers_matched:
  - "SLURM/GPU submission — 12 cells (ARM-0 × 9 seeds + ARM-2 × 3 seeds)"
  - "shared-storage writes — /mnt 워크스페이스 생성 + 출력"
  - "YAML 변경 — 새 contact constraints 18개, 9NFR 6번째 template"
  - "closure_spec 변경 — near_attack_A 3.5 → 20.0 (복사본, 공유 파일 미수정)"
---

# Contact 재설계 + 9NFR template 추가 — DockQ 개선 실험

## Purpose

template_ddb1_combo_9nfr(8444) 사후 분석에서 세 가지 root cause 확인:

| 버그 | 현상 | 원인 | 수정 |
|---|---|---|---|
| DDB1 contacts 잘못된 resid | contact_satisfied=1/12 | crystal resid를 YAML 1-index로 그대로 복사; CRBN +45 오프셋, DDB1 +395 오프셋 적용 누락. 12쌍 중 실제 crystal 계면 접촉(<5Å) = 4개만 유효 | 9NFR crystal에서 정확한 YAML position mapping으로 재추출한 10쌍으로 교체 |
| VAV1-CRBN contacts 없음 | VAV1 배치 오직 IK에 의존 | YAML에 VAV1-CRBN 계면 constraint 미수록 | 9NFR crystal에서 8쌍 추출 (2.67-3.39Å 쌍) |
| near_attack_A=3.5Å 불가능 | IK가 31-clash 비물리 포즈 생성 | zone_superpose_crbn.json: crystal K804 NZ → apex 13.23Å. 3.5Å에 도달하려면 VAV1이 CRBN 내부로 침투해야 함 | near_attack_A = 20.0Å (reach_A=13.5Å 이상; 생물학적 기준은 Lys < reach_A) |

새 설정:
1. CRBN-DDB1 contacts: 10쌍 (9NFR crystal <3.4Å 쌍, 정확한 YAML position 매핑)
2. VAV1-CRBN contacts: 8쌍 (9NFR crystal <3.6Å 쌍, chain A/B YAML positions)
3. 6번째 template: 9NFR_prot.cif (CRBN-VAV1 계면 direct prior, circular validation 인지)
4. near_attack_A: 3.5 → 20.0 Å (closure_spec 복사본에서만 변경)
5. ARM-0 × 9 seeds + ARM-2 × 3 seeds = 12 cells

## Contacts (검증됨)

### CRBN-DDB1 (10쌍)
| YAML A | YAML D | crystal CRBN | crystal DDB1 | 거리 |
|--------|--------|--------------|--------------|------|
| 170 | 386 | 222 | 781 | 2.80Å |
| 173 | 389 | 225 | 784 | 2.80Å |
| 196 | 530 | 248 | 925 | 2.90Å |
| 184 | 327 | 236 | 722 | 2.95Å |
| 185 | 610 | 237 | 1005 | 2.95Å |
| 144 | 685 | 189 | 1080 | 2.98Å |
| 146 | 558 | 191 | 953 | 3.02Å |
| 191 | 441 | 243 | 836 | 3.15Å |
| 188 | 517 | 240 | 912 | 3.18Å |
| 151 | 577 | 196 | 972 | 3.36Å |

### VAV1-CRBN (8쌍)
| YAML A | YAML B | crystal CRBN | crystal VAV1 | 거리 |
|--------|--------|--------------|--------------|------|
| 308 | 19 | 353 | 800 | 2.67Å |
| 310 | 17 | 355 | 798 | 2.70Å |
| 306 | 16 | 351 | 797 | 2.70Å |
| 352 | 14 | 397 | 795 | 2.81Å |
| 306 | 18 | 351 | 799 | 3.15Å |
|  58 | 32 | 103 | 813 | 3.18Å |
| 352 | 15 | 397 | 796 | 3.30Å |
|  41 | 41 |  86 | 822 | 3.39Å |

## Configuration

| 항목 | 설정 |
|---|---|
| 체인 | A=CRBN(375AA), B=VAV1 SH3c(61AA), C=MRT23227, D=DDB1 ΔBPA(745AA) |
| DDB1 MSA | single-seq CSV (8398과 동일) |
| templates | 9UUM, 9V0F, 4TZ4, 4CI3, 5HXB + **9NFR_prot.cif** (신규) |
| contacts | 18쌍 force:true max_distance=8.0Å (CRBN-DDB1×10 + VAV1-CRBN×8) |
| near_attack_A | 20.0Å (closure_spec 복사본, 공유 파일 미수정) |
| guidance_weight | 1.5 (src_local 기존 패치 재사용) |
| ARM-0 seeds | 16, 42, 123, 200, 300, 400, 500, 600, 700 (9개) |
| ARM-2 seeds | 16, 42, 123 (3개, near_attack_A=20Å) |

## Constraints

- allowed change scope:
  - 신규 WS: `/mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/`
  - 신규 YAML: `inputs/9NFR_contact_fix.yaml`
  - 신규 런처: `run_contact_fix_9nfr.sh`
  - 신규 closure_spec 복사본: `stage/closure_spec_contact_fix.json` (near_attack_A=20.0)
  - 신규 9NFR_prot.cif: `refs/9NFR_prot.cif` (gemmi로 protein-only 추출)
  - src_local: contact_early 기존 src_local symlink 재사용
  - 결과 문서: `/home/ubuntu/analysis/crl_integrative/contact_fix_9nfr_results.md`
- forbidden change scope:
  - 공유 `closure_spec_generic.json` 변경 금지 (복사본 사용)
  - `ddb1_contact_early_9nfr_20260626/stage/src_local/` 변경 금지
  - 기존 실험 WS 변경 금지
- external constraints:
  - GPU: `sudo -u kim sbatch --qos=normal`
  - 출력: `/mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/` (chmod 777)
  - SLURM GPU selector: `memory.free > 75000 MiB`
  - ARM-2 num_particles=2 (OOM 방지)

## Non-Goals

- guidance_weight 튜닝 (1.5 유지)
- DDB1 full MSA (8413/8415에서 악화 확인)
- ARM-1 (gradient only)
- IK re-enable at 3.5Å

## Done When

```bash
wc -l /mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/analysis/scores.tsv
# → 13 (header + 12 rows)

test -f /home/ubuntu/analysis/crl_integrative/contact_fix_9nfr_results.md
# → 존재
```

판정 기준:
- ARM-0 ≥ 4/9 seeds에서 CRBN_RMSD < 8Å → 9NFR template 효과 확인
- contact_satisfied ≥ 12/18 for ≥ 2 seeds → contacts 수정 효과 확인
- DockQ_total ≥ 0.25 for best ARM-0 → DDB1 인터페이스 개선
- DockQ_crbn-vav1 ≥ 0.10 → VAV1-CRBN contacts 효과

## Rollback

```bash
sudo -u kim scancel <JOBID>
sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/
```
src_local은 변경 없으므로 롤백 불필요.

## Progress Log

- 2026-06-26: spost-hoc analysis (8444): 3 root cause 확인.
  contact resid offset bug (CRBN+45, DDB1+395), VAV1-CRBN 미수록, near_attack_A=3.5 불가능.
  새 contacts 검증 완료 (zone_superpose_crbn.json + crystal distance analysis).
  사용자 승인.
