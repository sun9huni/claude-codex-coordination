#!/usr/bin/env python3
"""notionize.py — convert GitHub-flavored Markdown to Notion-flavored Markdown
and split it into safe-boundary chunks for MCP create/insert publishing.

Conversions:
  - inline math  $...$        -> $`...`$   (Notion inline equation)
  - block math   $$\n...\n$$  -> left as-is (Notion supports)
  - GFM pipe tables           -> Notion <table>…</table> (header-row=true)
  - mermaid / code fences     -> passed through untouched
  - chunked at heading / blank-line boundaries (never inside code/eq/table)

The table converter is `|`-aware: a `|` inside an inline-math span ($...$),
inline code (`...`), or escaped (\\|) is NOT treated as a column delimiter.
This is the fix for the failure mode where cells like `$|W_3|$` or
`$|\\langle\\psi|\\psi\\rangle|^2$` were split into spurious columns.

Usage:
  python3 scripts/notionize.py INPUT.md [--outdir DIR] [--limit N]
Prints a JSON manifest to stdout: {title, chunks:[paths], n_chunks,
tables, inline_math, total_chars}. The first H1 is lifted to `title`
(Notion page property) and removed from the body.
"""

import re
import os
import sys
import json
import argparse


# ---- span-aware tokenizer: protect $...$ and `...` and \x escapes ----
def _segments(text):
    """Yield (kind, content) where kind in {math, code, plain}.
    math = $...$ span (inclusive of $), code = `...` span (inclusive of `)."""
    out = []
    buf = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == "\\" and i + 1 < n:  # escaped char -> stays plain, keep both
            buf.append(text[i])
            buf.append(text[i + 1])
            i += 2
            continue
        if c == "`":
            j = text.find("`", i + 1)
            if j != -1:
                if buf:
                    out.append(("plain", "".join(buf)))
                    buf = []
                out.append(("code", text[i : j + 1]))
                i = j + 1
                continue
        if c == "$":
            j = text.find("$", i + 1)
            if j != -1 and "\n" not in text[i + 1 : j]:
                if buf:
                    out.append(("plain", "".join(buf)))
                    buf = []
                out.append(("math", text[i : j + 1]))
                i = j + 1
                continue
        buf.append(c)
        i += 1
    if buf:
        out.append(("plain", "".join(buf)))
    return out


def conv_inline(text):
    """Convert prose inline math $...$ -> $`...`$, leaving code/plain alone."""
    out = []
    for kind, seg in _segments(text):
        if kind == "math":
            out.append("$`" + seg[1:-1] + "`$")
        else:
            out.append(seg)
    return "".join(out)


def esc_cell(text):
    """Table-cell rich text: math->$`..`$, unescape \\|, escape bare < >."""
    out = []
    for kind, seg in _segments(text):
        if kind == "math":
            out.append("$`" + seg[1:-1] + "`$")
        elif kind == "code":
            out.append(seg)  # literal, no escaping inside code
        else:
            seg = seg.replace("\\|", "|").replace("<", "\\<").replace(">", "\\>")
            out.append(seg)
    return out and "".join(out).strip() or ""


def split_cells(line):
    """Split a GFM table row on `|`, ignoring `|` inside $...$, `...`, or \\|."""
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    cells = []
    buf = []
    i = 0
    n = len(s)
    in_math = False
    in_code = False
    while i < n:
        c = s[i]
        if c == "\\" and i + 1 < n:
            buf.append(s[i])
            buf.append(s[i + 1])
            i += 2
            continue
        if c == "`":
            in_code = not in_code
            buf.append(c)
            i += 1
            continue
        if c == "$" and not in_code:
            in_math = not in_math
            buf.append(c)
            i += 1
            continue
        if c == "|" and not in_math and not in_code:
            cells.append("".join(buf))
            buf = []
            i += 1
            continue
        buf.append(c)
        i += 1
    cells.append("".join(buf))
    return [c.strip() for c in cells]


def render_table(buf):
    sep_idx = None
    for i, l in enumerate(buf):
        if re.match(r"^\|[\s:|-]*-[\s:|-]*\|?\s*$", l):
            sep_idx = i
            break
    if sep_idx is None:  # not a real table -> emit as prose
        return [conv_inline(l) for l in buf]
    hdr = split_cells(buf[sep_idx - 1]) if sep_idx >= 1 else split_cells(buf[0])
    body = [split_cells(l) for l in buf[sep_idx + 1 :]]
    res = ['<table fit-page-width="true" header-row="true">']
    res.append("\t<tr>")
    for c in hdr:
        res.append("\t\t<td>" + esc_cell(c) + "</td>")
    res.append("\t</tr>")
    for r in body:
        if not any(x for x in r):
            continue
        res.append("\t<tr>")
        for c in r:
            res.append("\t\t<td>" + esc_cell(c) + "</td>")
        res.append("\t</tr>")
    res.append("</table>")
    return res


def convert(md_text):
    """Return (title, notion_md). Lifts first H1 to title, removes it."""
    lines = md_text.split("\n")
    title = None
    for i, l in enumerate(lines):
        if l.startswith("# "):
            title = l[2:].strip()
            del lines[i]
            if i < len(lines) and lines[i].strip() == "":
                del lines[i]
            break
    out = []
    in_code = in_eq = False
    tbuf = []
    for ln in lines:
        st = ln.strip()
        if st.startswith("```"):
            if tbuf:
                out += render_table(tbuf)
                tbuf = []
            in_code = not in_code
            out.append(ln)
            continue
        if in_code:
            out.append(ln)
            continue
        if st == "$$":
            if tbuf:
                out += render_table(tbuf)
                tbuf = []
            in_eq = not in_eq
            out.append(ln)
            continue
        if in_eq:
            out.append(ln)
            continue
        if st.startswith("|"):
            tbuf.append(ln)
            continue
        if tbuf:
            out += render_table(tbuf)
            tbuf = []
        out.append(conv_inline(ln))
    if tbuf:
        out += render_table(tbuf)
    return title, "\n".join(out)


def chunk(notion_md, limit=9000):
    """Split at heading / blank-line boundaries outside code & block-eq."""
    chunks = []
    cur = []
    cur_len = 0
    ic = ie = False

    def is_heading(l):
        return bool(re.match(r"^#{1,6}\s", l)) or l.startswith("# ")

    for ln in notion_md.split("\n"):
        st = ln.strip()
        if st.startswith("```"):
            ic = not ic
        elif st == "$$":
            ie = not ie
        safe = (not ic and not ie) and (is_heading(ln) or st == "")
        if cur_len >= limit and safe and cur:
            chunks.append("\n".join(cur))
            cur = []
            cur_len = 0
        cur.append(ln)
        cur_len += len(ln) + 1
    if cur:
        chunks.append("\n".join(cur))
    return chunks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input", help="input markdown file")
    ap.add_argument(
        "--outdir",
        default=None,
        help="chunk output dir (default: <input>_notion_chunks)",
    )
    ap.add_argument("--limit", type=int, default=9000, help="max chars per chunk")
    args = ap.parse_args()

    md = open(args.input, encoding="utf-8").read()
    title, notion_md = convert(md)
    chunks = chunk(notion_md, args.limit)

    outdir = args.outdir or (os.path.splitext(args.input)[0] + "_notion_chunks")
    os.makedirs(outdir, exist_ok=True)
    for fn in os.listdir(outdir):
        if fn.startswith("chunk_") and fn.endswith(".md"):
            os.remove(os.path.join(outdir, fn))
    paths = []
    for i, c in enumerate(chunks):
        p = os.path.join(outdir, f"chunk_{i:02d}.md")
        open(p, "w", encoding="utf-8").write(c)
        paths.append(p)

    manifest = {
        "title": title,
        "n_chunks": len(chunks),
        "chunks": paths,
        "tables": notion_md.count("<table"),
        "inline_math": notion_md.count("$`"),
        "total_chars": sum(len(c) for c in chunks),
        "chunk_chars": [len(c) for c in chunks],
    }
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
