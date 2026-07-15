# Hada Archive Upgrades

Source review date: 2026-05-18

## Sources

| Source | Applied upgrade |
| --- | --- |
| https://news.hada.io/topic?id=27457 | Keep `AGENTS.md` short, version plans, enforce architecture with machine checks, optimize repo readability for agents. |
| https://news.hada.io/topic?id=28105 | Add eval harness, failure taxonomy, judge calibration, criteria drift, and data inspection workflow. |
| https://news.hada.io/topic?id=27578 | Add MCP/tool inventory, context budget, and on-demand tool policy. |
| https://news.hada.io/topic?id=29554 | Add cost-aware delegation: Architect, Developer, Reviewer roles with bounded iteration. |
| https://news.hada.io/topic?id=25231 | Strengthen Codex Skill governance around `SKILL.md`, scripts, references, assets, and progressive disclosure. |
| https://news.hada.io/topic?id=21772 | Add deterministic gates via scripts/CI for behavior that should not rely on prompts. |
| https://news.hada.io/topic?id=28538 | Keep cross-agent/model review and handoff patterns explicit. |
| https://news.hada.io/topic?id=28558 | Add team Skill registry and sync policy with dry-run and state preservation. |

## Resulting Harness Additions

- `.agent/evals/`
- `.agent/tools/`
- `.agent/skills/`
- `.agent/delegation/`
- `scripts/eval.sh`
- `scripts/tool-audit.sh`
- `scripts/skills-sync.sh`
- `skills/eval-harness/`
- `skills/tool-budget/`
- `skills/skills-governance/`
- `skills/delegation-manager/`
