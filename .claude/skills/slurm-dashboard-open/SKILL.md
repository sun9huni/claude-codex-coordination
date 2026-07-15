---
name: slurm-dashboard-open
description: Make the SLURM web dashboard reachable at localhost:18080 from a non-head node by starting a local TCP proxy to 10.0.5.62:18080, letting VS Code Remote-SSH forward it to the user's browser. Use when the user needs the dashboard but is not on the head node. The agent only opens the port; the human opens the browser.
argument-hint: "<none — or a custom port/host if not the default 10.0.5.62:18080>"
allowed-tools: Read Bash(hostname:*) Bash(curl:*) Bash(ss:*) Bash(netstat:*) Bash(pgrep:*) Bash(command:*) Bash(socat:*) Bash(ssh:*)
---

# /slurm-dashboard-open — Bridge the dashboard to localhost for the browser

The SLURM web dashboard lives on the **head node `10.0.5.62`, port `18080`**. A
browser on the user's laptop cannot reach the internal `10.0.5.x` network directly;
VS Code Remote-SSH forwards `localhost:<port>` from the connected node to the
laptop. If the user is connected to the head node, `localhost:18080` already is the
dashboard. **If connected to any other node** (the usual case), `localhost:18080` is
empty — this skill starts a local proxy `127.0.0.1:18080 → 10.0.5.62:18080` so VS
Code can forward it. The agent has no browser; it only opens the port. The **human
opens `http://localhost:18080`** and logs in.

## Step 1 — Locate self & test reachability

- `hostname` — if already on `10.0.5.62`, no proxy needed; `localhost:18080` is the
  dashboard. Tell the user to open it and STOP.
- `curl -s -m5 -o /dev/null -w "%{http_code}" http://localhost:18080` — if `200`,
  the port is already serving (proxy up or on head node). Tell the user, STOP.
- `curl -s -m5 -o /dev/null -w "%{http_code}" http://10.0.5.62:18080` — must be
  `200` (head service reachable over the internal net). If not `200`, the dashboard
  service itself is down/unreachable → report, do not proxy.

## Step 2 — Start the proxy (idempotent)

- Check `ss -ltn | grep ':18080 '` and `pgrep -af 'socat.*18080'` first — if a
  listener/proxy already exists, do NOT start a second (reuse it).
- Prefer `socat`:
  `socat TCP-LISTEN:18080,fork,reuseaddr,bind=127.0.0.1 TCP:10.0.5.62:18080`
  run in the **background** (it must persist across the turn).
- Fallback if no socat: `ssh -fN -L 127.0.0.1:18080:10.0.5.62:18080 localhost`, or a
  small `python3` socketserver relay.
- Bind `127.0.0.1` (not `0.0.0.0`) — VS Code forwards localhost ports and it avoids
  exposing the dashboard on the node's external interfaces.

## Step 3 — Verify & hand off

- `curl localhost:18080` → confirm `200`.
- Tell the user: in VS Code, the **PORTS** tab should auto-forward `18080` (else
  *Add Port → 18080*), then open **http://localhost:18080** in the laptop browser
  and log in (lowercase username = Linux/Slurm account).
- Note the proxy is background-only and dies with the session; offer to tear it down
  (`pkill -f 'socat.*18080'`) when done.

## Pairs with

`/gpu-dashboard-submit` stages the script + emits the submit card; this skill opens
the dashboard so the human can actually submit it (high/interactive QoS = web only).

## Red Flags

| Rationalization | Reality |
|---|---|
| "I'll open the browser / submit for them." | No browser, no auth session. The agent only opens the localhost port; the human drives the web UI. |
| "Bind 0.0.0.0 so anyone can reach it." | Bind 127.0.0.1. VS Code forwards localhost; 0.0.0.0 needlessly exposes the dashboard on the node. |
| "Just start another proxy." | Check for an existing listener/socat first; double-binding 18080 fails or orphans procs. |
| "localhost:18080 is 000, the dashboard is down." | 000 only means nothing listens *on this node*. Test `10.0.5.62:18080` before concluding the service is down. |

## Forbidden

- Do NOT bind to `0.0.0.0` or any external interface.
- Do NOT attempt to log in / submit through the dashboard programmatically (no
  credentials; that is the human's authenticated action).
- Do NOT start a second proxy if one is already listening on 18080.
