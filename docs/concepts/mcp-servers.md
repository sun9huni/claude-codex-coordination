# MCP servers

[Model Context Protocol](https://modelcontextprotocol.io) (MCP) servers
give Claude Code structured tools the agent can call by name —
filesystem ops, GitHub queries, Postgres reads, Slack posts, browser
control, etc. — without you wiring Bash glue.

The harness is **MCP-agnostic by default**. Nothing in
`claude-codex-coordination` requires an MCP server, and nothing
breaks if you skip MCP entirely. But MCP is the cleanest way to add
capability surface for a few specific workflows below.

## When MCP pays off

| Pattern | Bash workaround | MCP improvement |
|---|---|---|
| Reading many small files across multiple project repos | scripting `find` + `head` | `filesystem` MCP — structured `read_file`, no shell quoting |
| Reviewing a GitHub PR by number | `gh pr view N --json files,body` + manual diff parse | `github` MCP — structured PR / issue / commit objects, no JSON wrangling |
| Postgres lookups during `/debug` | `psql -h ... -c "SELECT ..."` with quoting hell | `postgres` MCP — typed queries, safer than DDL-gate prone shell strings |
| Sending a `/handoff` summary to Slack | curl + JSON shaping | `slack` MCP — `post_message`, attachments, threads |
| Pulling a remote runbook on hook config | WebFetch on docs URL | `fetch` MCP — caching + structured response |

If none of the patterns above fit your work, **skip MCP**. It's not
free: each server adds startup latency, auth surface area, and a
class of failures you have to debug.

## Configuration shape

MCP servers are configured per-project in `.mcp.json` at the
workspace root:

```jsonc
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/home/user/code"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

The template **does not ship a `.mcp.json`** because the right set
depends entirely on your environment. Add one when you need it.

## Recommended servers for this harness

### `filesystem`
Most universally useful. Pair with the `allowed-tools` lists in
expertise skills (`/code-review`, `/refactor-simplify`) to read
across project repos without `Bash(find:*)` proliferation. The
filesystem server's read operations are typed; you stop spending
context on shell-output parsing.

Install: `npx -y @modelcontextprotocol/server-filesystem <root1> [root2 ...]`.

Caveat: don't point it at `/` or `$HOME` — give it specific roots
(your project repos, your `.agent/`). Wide roots leak secrets and
inflate token cost from auto-completion lookups.

### `github`
Pair with `/code-review` when working from PR numbers. The skill
already lists `gh pr view` / `gh pr diff` in `allowed-tools`, but
the MCP server is cleaner — PR titles, file lists, and review
threads come back as structured JSON Claude can iterate.

Install: needs `GITHUB_PERSONAL_ACCESS_TOKEN` (PAT scope `repo`,
plus `workflow` if you'll edit GitHub Actions).

### `postgres` (optional, project-specific)
For workflows that hit a database during `/debug` or
`/contract-check`. The MCP server enforces read-only by default —
useful complement to the existing `pre-bash-db-gate.sh` (which
blocks DDL via shell `psql`).

### `playwright` / `puppeteer` (optional)
For UI-heavy projects. The harness has no UI patterns built in,
but you can pair them with a custom subagent.

## Interaction with existing harness

- **Approval gates**: MCP tool calls go through the same
  PreToolUse hook chain. Patterns to consider:
  - The `pre-bash-destructive-gate.sh` doesn't currently match MCP
    tool calls — destructive ops via MCP are NOT auto-blocked. If
    you enable a write-capable MCP server, add an MCP-matcher gate.
  - Example: add a hook with `"matcher": "mcp__github__create_repository"`
    to block repo creation without approval.
- **Settings**: `.claude/settings.json` `permissions.allow` lists
  MCP tools the same way as Bash patterns:
  ```json
  "allow": ["mcp__filesystem__read_file", "mcp__github__get_pull_request"]
  ```
- **Subagents**: a subagent's `permissions.allow` can include MCP
  tool names too, so you can restrict an HPC inspector to
  `mcp__filesystem__read_file` on `/shared/logs/**` without
  granting workspace-wide MCP access.

## Failure modes to watch

1. **MCP server fails to start**: surfaces as a tool-not-available
   error. Re-check `.mcp.json` syntax (`python3 -m json.tool`) and
   that the `command` / `npx` package exists.
2. **Auth expiry**: GitHub PATs and Slack tokens expire. Wrap
   `/handoff` outputs that depend on MCP with a "MCP healthy?"
   check, or accept that some sessions will see degraded MCP and
   plan for it.
3. **Latency**: each MCP server adds ~200-500ms to session
   startup. If you enable 5+ servers, session start gets noticeably
   sluggish. Disable the ones you don't use this week.
4. **Wide filesystem roots**: see above. Specific > broad.

## When NOT to use MCP

- Single-file projects, scripts, throwaway notebooks. The setup
  overhead outweighs the gain.
- Pre-stable harness adoption — get the slash skills + hooks
  working with Bash first; add MCP once you know which workflows
  recur often enough to justify a server.
- Untrusted code review. MCP servers expand the agent's reach;
  for adversarial review, narrower is safer.

## See also

- [enforcement-hooks.md](enforcement-hooks.md) — applies to MCP
  tool calls the same way it applies to Bash.
- [multi-agent-coexistence.md](multi-agent-coexistence.md) — MCP
  servers are agent-private; Codex and Cursor have their own MCP
  surfaces.
- Claude Code MCP docs: <https://code.claude.com/docs/en/mcp.md>
