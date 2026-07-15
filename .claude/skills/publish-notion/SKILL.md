---
name: publish-notion
description: Publish a long Markdown doc to Notion with faithful math, tables, and mermaid using scripts/notionize.py plus the Notion MCP. Use for putting a .md file into Notion or creating a Notion page. For authored research/results reports, follow the catalog skeleton in docs/notion_report_template.md. For slice cockpit row sync, use /handoff and notion_sync.py instead.
argument-hint: "<path/to/file.md> [parent: <notion page url or id>]"
allowed-tools: Read Bash(python3 scripts/notionize.py:*) Bash(python3 ./scripts/notionize.py:*) mcp__claude_ai_Notion__notion-create-pages mcp__claude_ai_Notion__notion-update-page mcp__claude_ai_Notion__notion-fetch
---

# /publish-notion — Markdown → Notion page

Notion's MCP takes **Notion-flavored Markdown**, not GFM: inline math must be
`$`…`$`` (backtick-wrapped), tables must be `<table>` blocks, and a single
`content` string has a size ceiling. Hand-pasting a long GFM doc therefore
breaks math, breaks pipe tables (especially cells with `|` inside `$…$` like
`$|W_3|$`), and overflows. This skill makes it deterministic + chunked.

The hard part is already solved by `scripts/notionize.py`. The MCP create/insert
loop still needs Claude-in-session (the Notion MCP is interactively
authenticated — it is NOT headless/cron-able; for unattended publishing extend
`scripts/notion_sync.py` instead).

## Step 0 — Report structure (authored research/results reports only)

If you are publishing an **authored research / results report** (findings,
comparisons, catalogs, analyses, audits), structure the source `.md` to the
**catalog skeleton in `docs/notion_report_template.md`** (FKSFold-Boltz repo)
BEFORE Step 1. Skeleton order:

1. 📋 **문서 목적** callout (1 paragraph + 측정/소스)
2. 🎯 **한 줄 결론** callout (current truth; causal label precise)
3. 📌 **핵심 논의 사항** — 3 strategic *big* questions (colored callouts), not ops tasks
4. **읽는 법 (범례)** — color/metric/verdict legend
5. **라인업 요약** table (all items + verdict emoji)
6. per-regime sections — short prose + **embedded figures** where the report is structural
7. ★ **key caveat/insight** the data directly proves
8. 🔬 **방법론 appendix** — pipeline / params / attribution control / provenance / limits

Plain 평서체. iPTM/ipDE-type confidence ≠ accuracy. Provenance per number. Causal
labels precise ("which channel contributed", not "X won"). 산문은 `AGENTS.md §출력 문체`
(anti-AI)를 따른다: em-dash(—)·과한 볼드·이모지 장식 금지, 연결어미 뒤 쉼표 금지, AI 상투구 금지,
첫째/둘째 나열·문장 머리 또한/따라서/그리고 반복 금지. 표·수치·기술용어는 보존.

**Scope:** this is the DEFAULT for *authored reports only*. Do NOT force it onto
arbitrary docs (specs, meeting digests, runbooks, handoffs, RFPs) — publish those
as-authored. Anti-patterns that dropped recent report quality (avoid): text-wall
prose, skipped scaffolding, stacked correction appendices (`§정정-N`), and missing
structure-overlay figures in structural reports.

## Step 1 — Convert + chunk (deterministic)

Run the converter on the target file:

```
python3 scripts/notionize.py <FILE.md>
```

It prints a JSON manifest and writes `chunk_00.md … chunk_NN.md` to
`<FILE>_notion_chunks/`. It guarantees:
- inline `$…$` → `$`…`$`` ; block `$$…$$` left as-is (Notion renders both)
- GFM pipe tables → `<table header-row="true">`, **`|`-aware** (a `|` inside
  `$…$`, `` `…` ``, or escaped `\|` is NOT a column delimiter — this is the fix
  for the table-breakage that used to require hand-repair)
- ```` ```mermaid ```` / code fences passed through untouched
- first `# H1` lifted to `manifest.title` (the Notion page title) and removed
  from the body; chunks split only at heading / blank-line boundaries (never
  inside a code block, `$$` block, or table)

Read the manifest's `title` and `chunks` (ordered list of paths).

**Sanity gate (do this, cheap):** confirm every `<table>` has consistent column
counts before publishing — catches any residual split bug:

```
cat <FILE>_notion_chunks/chunk_*.md | python3 -c "import sys,re; t=sys.stdin.read(); tabs=re.findall(r'<table.*?</table>',t,re.S); bad=[i for i,x in enumerate(tabs) if len({len(re.findall(r'<td>',r)) for r in re.findall(r'<tr>(.*?)</tr>',x,re.S)})>1]; print('tables',len(tabs),'inconsistent',bad)"
```

If `inconsistent` is non-empty, STOP and inspect that table (do not publish a
broken table); fix the source `.md` and re-run Step 1.

## Step 2 — Create the page (chunk 00)

`Read` `chunk_00.md`, then `mcp__claude_ai_Notion__notion-create-pages` with:
- `properties.title` = manifest `title`
- `icon` = a fitting emoji (optional)
- `content` = the chunk_00 text **verbatim** (do not paraphrase — copy exactly)
- `parent` = omit for a standalone private page, OR `{type:"page_id", page_id}`
  if the user passed a parent. (For a database parent, `fetch` the DB first to
  get the `data_source_id`.)

Capture the returned `page_id` and `url`.

## Step 3 — Append the rest (chunks 01…NN, in order)

For each remaining chunk in order: `Read` it, then
`mcp__claude_ai_Notion__notion-update-page` with
`command:"insert_content"`, `position:{type:"end"}`, `content:`<chunk verbatim>`.

Rules:
- One chunk per `insert_content` call (keeps each call well under the size
  ceiling). Preserve order — `position:end` appends.
- Copy chunk text **exactly** (Korean/unicode/LaTeX fidelity matters). Read the
  chunk immediately before its insert so you copy from a fresh tool result.

## Step 4 — Verify

`mcp__claude_ai_Notion__notion-fetch` the `page_id` (or just report the URL and
ask the user to eyeball). Confirm: `$`…`$`` rendered as equations, `<table>` as
tables, ```` ```mermaid ```` as diagrams (Notion may show mermaid as a code
block if its preview is off — note that). Report the page URL.

## Red Flags

| Rationalization | Reality |
|---|---|
| "It's a results report, I'll just dump the findings." | Authored research/results reports follow `docs/notion_report_template.md` (Step 0): 목적/한 줄/핵심논의/범례/요약표/figures/방법론. Dense text-walls + correction-stacks are the exact quality regression this guards against. (Arbitrary docs publish as-authored.) |
| "I'll just paste the GFM into Notion." | Raw `$…$` and pipe tables break (math + `\|`-in-math cells). Always go through `notionize.py` Step 1 — that is the whole point. |
| "One big `content` on create will fit." | Long docs overflow the create ceiling — chunk and insert in order (Steps 2–3), one chunk per call. |
| "The table looks fine, skip the sanity gate." | A `\|` inside a math cell can still split columns — run the column-consistency check before publishing. |
| "I'll commit the chunks dir." | `<FILE>_notion_chunks/` is scratch — never commit it. |

## Forbidden / notes

- Do NOT hand-paste GFM tables or raw `$…$` into Notion — always go through
  Step 1; that is the whole point.
- Do NOT commit the `<FILE>_notion_chunks/` scratch dir.
- This skill publishes CONTENT pages. It is NOT the slice-cockpit sync — that is
  `./scripts/handoff.sh` + `./scripts/notion_sync.py --handoff-emit <slice>`.
- The Notion MCP requires interactive auth → session-only, not cron. Headless
  publishing is a future `notion_sync.py publish-doc` (REST API, md→blocks).
