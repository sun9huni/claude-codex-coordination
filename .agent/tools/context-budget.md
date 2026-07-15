# Context Budget

Use this to control context pollution from tools, MCP schemas, plugins, Skills, and large docs.

## Budget Targets

- default tools: shell, codex CLI, `./scripts/verify.sh`
- on-demand tools: browser QA, eval harness, remote harness, MCP/plugin tools, skill sync
- always-loaded docs: root or project `AGENTS.md`
- large docs requiring progressive disclosure: `.agent/knowledge/raw/`, design docs, uploaded PDFs, long project docs

## Audit Questions

- Which tools were actually used in the last 10 sessions?
- Which tool schemas are loaded but unused?
- Which tools can be represented as a Skill instead?
- Which docs should become references instead of always-loaded instructions?

## Actions

- disable: none during initial install
- convert to Skill: repeated workflows observed 3+ times
- keep core: shell, codex CLI, harness scripts
- needs owner: new MCP servers, plugins, external APIs, production-facing tools
