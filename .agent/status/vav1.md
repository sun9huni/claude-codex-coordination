---
owner_session: ""
owner_label: ""
owner_agent: ""
version: 0
last_updated: 2026-05-26
heartbeat: ""
remaining_actions: []
contract_pointers: []
---
# VAV1 Ranking Status

As of: 2026-05-18

## Where we are

- **Shared `scripts/vav1_ensemble_rank.py`가 active production rank script.**
  `baseline_rank` / `production_rank` 두 모드 모두 구현됨, `final_rank =
  production_rank`. `ranking_priority`, `production_ranking.score_weights`,
  `production_ranking.priority` config-driven.
- **Local git worktree에는 같은 파일이 삭제 상태** — `git status`가 `D
  scripts/vav1_ensemble_rank.py` 출력. 즉 shared와 local이 divergent.
- Ranking 의미 변경/추가 미진행. Cursor 최근 활동에 ranking 관련 plan은
  지난 주 이후 없음.

## Next action

후속 ranking 변경 들어가기 **전에 reconcile** 필요: shared의 active script를
local git worktree로 commit하는 작업. 이건 별개 contract감 — schema 변경 아닌
누락 회복이라 보수적으로 그대로 import.

## Live truth

- Active script: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/vav1_ensemble_rank.py` (2026-04-09)
- Local (deleted): `/home/ubuntu/FKSFold-Boltz_Advancement/scripts/vav1_ensemble_rank.py`
- Configs divergence (auto-scan 결과): local에는 `oracle_ranking_3seed_optimized.yaml` (2026-04-15)만, shared에는 `oracle_ranking.yaml`/`blind_ranking.yaml` (2026-04-09). reconcile 시 같이 처리.
- Metric 보존 목록: `keyres_hit_rate`, `keyres_mean/median`,
  `ligand_aware_mean`, `n_lv_mean`, `iptm_mean`

## Open

- shared와 local 사이에 ranking config YAML도 divergent한지 확인 필요
  (reconcile 범위).
