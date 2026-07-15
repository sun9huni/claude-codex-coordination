---
name: meeting-report
description: Compile a Notion-paste-ready digest from CURRENT.md, .agent/status/<slice>.md, recent .agent/contracts/, git log, and SLURM history. Per-slice sections (Done / In flight / Decisions needed / Blocked / Next / Artifacts). Use before a weekly status meeting, before a stakeholder update, or whenever the user asks "what did we do this week?" — replaces manual re-finding across scattered sources.
argument-hint: "[slice-name | all (default)] [since-date YYYY-MM-DD | 7d (default)]"
allowed-tools: Read Grep Edit Write Bash(git log:*) Bash(git -C * log:*) Bash(git status:*) Bash(find:*) Bash(ls:*) Bash(cat:*) Bash(grep:*) Bash(awk:*) Bash(stat:*) Bash(date:*) Bash(squeue:*) Bash(sacct:*) Bash(wc:*)
---

# /meeting-report — Notion-ready weekly digest

The user has many parallel experiments and limited time to compile
status reports. Their data already exists — it's scattered across
CURRENT.md, slice status files, contracts, plans, git history, and
SLURM logs. This skill compiles those sources into one Notion-paste
markdown document, with no invention.

## Output discipline

- Headers up to `###` only (Notion renders h1-h3 cleanly).
- **No emojis** for status indicators — plain markdown text.
- Mix of tables and bullet lists: tables for "compare N things",
  bullets for "list of N items".
- PNG / figure paths are listed verbatim (Notion users can
  upload or link them).
- ~10 lines per slice section. Total output ≤ 100 lines per
  digest. If a slice has more, summarize and link the artifact
  for drilldown.
- Cite the source for each line. If you cannot point at a file,
  contract, or commit, leave the line out.

## Step 1 — Resolve scope

`$ARGUMENTS` parses as `[slice] [since]`:
- slice: a known slice name from `WORKFLOW.md §1`, or `all` (default).
- since: ISO date `YYYY-MM-DD`, or `Nd` (e.g. `7d` = 7 days, default).

Compute `since_date = today - <N>d`. If the user gave an absolute
date, use it.

Read each slice's `.agent/status/<slice>.md` frontmatter — `owner_session`,
`remaining_actions`, `contract_pointers`, `last_updated`, `version` — plus the
derived `.agent/handoffs/CURRENT.md` index (lab-wide owner table). These drive
multiple sections below. Approval gates come from each slice's contracts
(`approval_required`/decisions), not a CURRENT.md scalar.

## Step 2 — Collect data per slice

For each target slice (one or all):

### a. Static status
`.agent/status/<slice>.md` — extract Done / In flight / Next action
/ Open risks. Note mtime; if > 7 days flag the slice as stale.

### b. Contracts
`find .agent/contracts -name '<slice>-*.md' -mtime -<N>` filtered
by `Status:` field:
- `approved` + recent → In flight
- `done` → Done
- `pending` → Decisions needed (user approval pending)

### c. Recent commits
`git -C <project-repo-for-slice> log --since=<since_date> --oneline`.
If you don't know which project repo maps to which slice, read
`WORKFLOW.md §1`. Filter to commits whose paths touch the slice.

### d. Active SLURM jobs (HPC slices only)
`squeue -u <user> --noheader -o "%i %j %T %M %L %R"` and recent
`sacct --starttime=<since_date> --format=JobID,JobName,State,Elapsed`.
For long output, delegate to
`Agent(subagent_type="slurm-status", prompt="summarize jobs since <since_date>")`
to keep this skill's context light.

### e. Figures / artifacts
`find <slice-related-paths> -name '*.png' -mtime -<N>`. List
paths — do not embed. Notion users link or upload them.

### f. Open decisions
From CURRENT.md `approval_required` + `remaining_actions` items
phrased as decisions ("Decide ...", "Pick ...", "Choose ...").

## Step 3 — Compose the digest

Use this exact shape:

```markdown
# {Project} — {YYYY-MM-DD} digest

Range: {since_date} → {today}. Per-slice status + CURRENT.md index, last updated {last_updated}.

## TL;DR
- **{slice1}**: one-sentence overall state.
- **{slice2}**: ...

## {slice1}

### Done since {since_date}
- {commit-or-contract-ref}: one-line summary. → `path/or/contract.md`
- ...

### In flight
| Item | Detail | Pointer |
|---|---|---|
| {item 1} | {1-line detail} | {path} |
| {item 2} | ... | ... |

### Decisions needed
- **{decision title}** — {context in one sentence}. Options: {A vs B}. Recommended: {pick or "defer until X"}.
- ...

### Blocked / Risks
- **{risk title}** — {one-sentence}. Mitigation: {action}.
- ...

### Next 1-2 weeks
- {next action 1} — {one-line scope}.
- ...

### Artifacts
- Contracts: `.agent/contracts/{slug}.md`
- Status: `.agent/status/{slice}.md`
- Figures: `analysis/.../foo.png`, `analysis/.../bar.png`
- Key commits: {sha} {message}

## {slice2}
(same shape)

## Cross-slice notes
(optional — only if there are dependencies between slices, e.g.
"mmgbsa Stage 2 blocked → affects fragmap baseline decision")

---
Generated {timestamp} via /meeting-report.
Source: .agent/status/*.md (per-slice batons) + .agent/handoffs/CURRENT.md index;
.agent/contracts/ filtered Status; git log since {since_date}.
```

## Step 4 — Persist (optional)

If the user passes `--save` or the report exceeds 60 lines,
write a copy to `.agent/scratch/meeting-reports/{YYYY-MM-DD}-{slice}.md`
(create the dir if missing). The skill always prints to stdout first
so the user can copy-paste before the file is written.

Do not commit the file — it's a snapshot, not coordination state.

## Karpathy alignment

- **Think Before Coding**: this skill is the "think" step
  applied to status compilation. Re-finding scattered data
  manually is the no-think path; this skill makes the data
  inventory explicit.
- **Simplicity First**: cap each section at ~5 items + summary
  pointer. A digest of 30 items per slice has 0 readers.
- **Surgical Changes**: do NOT alter source files (CURRENT.md,
  status, contracts). Reading only. The digest is a derived
  artifact.
- **Goal-Driven**: each line in the digest must be derivable from
  a cited source. If you cannot cite, drop the line.

## Red Flags

| Rationalization | Reality |
|---|---|
| "I'll fill in the gaps from chat history." | Chat is not durable. If a fact isn't in CURRENT.md / status / contracts / git, treat it as not-yet-recorded and ask the user to add it. The digest is the wrong place to first-record facts. |
| "5 commits don't have one-liners, I'll write descriptive ones from memory." | Commits have their own messages. Use them verbatim. If a commit message is uninformative, that's a signal to fix the commit-message discipline, not to launder it through the digest. |
| "I'll show 20 items per slice — comprehensive!" | Comprehensive ≠ useful. The user already has the data. They need the *compressed* view. Cap at 5 items per section; the rest goes to "Artifacts" pointers for drilldown. |
| "I'll guess the state of SLURM jobs I don't have output for." | Delegate to Agent(subagent_type=slurm-status). Don't fabricate exit codes or ETAs. |
| "Decisions needed: just copy approval_required verbatim." | approval_required is one source. Also pull "Decide ..." items from remaining_actions, "defer until" hedges from status files, and stalled contracts (status: pending > 7d). |
| "I'll add a 'Tweets' section with celebratory phrasing." | The user is presenting to a meeting, not a marketing channel. Plain factual phrasing. No tweet-speak. |
| "Figures: I'll embed PNGs inline as ![]() blocks." | Notion handles MD images IF the path resolves to an accessible URL. Local /mnt/data paths don't. List paths as text; user uploads on the Notion side. |

## Forbidden

- Do NOT modify CURRENT.md, .agent/status/*, .agent/contracts/*,
  or project files during /meeting-report. Read-only on source.
- Do NOT include facts not anchored in a citable file or commit.
- Do NOT use emoji status indicators (✅🟡 etc.); user prefers
  plain text.
- Do NOT exceed h3 header depth (Notion h4+ rendering is
  inconsistent).
- Do NOT embed local-path images as `![](file:///mnt/...)` —
  Notion can't fetch them. List paths textually.
- Do NOT commit the digest output to git; if persisted, only to
  `.agent/scratch/meeting-reports/` which is gitignored.

## When NOT to use this skill

- Single-slice quick check — `/slice-status <slice>` is faster
  and more focused.
- Mid-task interruption — wait until the task lands before
  digesting, otherwise the report captures churn.
- A meeting with one specific question — answer the question
  directly; don't drown the room in a full digest.
