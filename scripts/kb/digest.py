#!/usr/bin/env python3
"""Close the loop on kb-digest issues: supersede stale ones and turn ticked items into a KB change.

    # after kb-curator opens digest N: which older open digests nobody ticked anything in
    gh issue list --label kb-digest --state open --json number,body,comments > open.json
    python3 scripts/kb/digest.py supersede --issues open.json --new N

feedback.py calls accept() when a maintainer labels a digest kb-accepted: each ticked item is
added to its target page (the source's `→` page in the digest, or a `→ page` the person wrote at
the end of the item) under "From the digest", marked unverified until someone summarizes it in
our own words against a primary source. Issue text is only parsed as data; the pull request is
the review.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kblib  # noqa: E402
from kblib import KB_DIR  # noqa: E402

HEADING = re.compile(r"^### (?P<source>.+?)(?: → `?(?:docs/knowledge/)?(?P<page>[^`\s]+)`?)?\s*$")
TICKED = re.compile(r"^- \[[xX]\] \[(?P<title>.+)\]\((?P<url>https://[^\s)]+)\)"
                    r"(?: · (?P<date>\d{4}-\d{2}-\d{2}))?(?P<rest>.*)$")
OVERRIDE = re.compile(r"→\s*`?(?:docs/knowledge/)?([\w./-]+\.md)`?")
ANY_TICK = re.compile(r"^- \[[xX]\] ", re.M)
SECTION = "## From the digest"
MAX_TITLE = 200


class DigestError(Exception):
    pass


def has_ticks(body: str) -> bool:
    return bool(ANY_TICK.search(body or ""))


def superseded(open_issues: list[dict], new_number: int) -> list[int]:
    """Older open digests with nothing ticked and no comments (picks noted there count): the new one replaces them."""
    return sorted(i["number"] for i in open_issues
                  if i["number"] < new_number and not has_ticks(i.get("body") or "") and not i.get("comments"))


def ticked_items(body: str) -> list[dict]:
    """Every ticked item with its source and target page (a per-item `→ page` wins)."""
    items, source, page = [], None, None
    for line in (body or "").replace("\r\n", "\n").splitlines():
        if m := HEADING.match(line):
            source, page = m.group("source").strip(), m.group("page")
        elif m := TICKED.match(line):
            override = OVERRIDE.search(m.group("rest"))
            items.append({
                "source": source or "unknown source",
                "page": override.group(1) if override else page,
                "title": " ".join(m.group("title").split())[:MAX_TITLE],
                "url": m.group("url"),
                "date": m.group("date") or "",
            })
    return items


def add_to_page(page: Path, lines: list[str]) -> None:
    text = page.read_text(encoding="utf-8").rstrip("\n") + "\n"
    if SECTION not in text.splitlines():
        text += f"\n{SECTION}\n\nPicked from the weekly digest; each waits to be written up in our own words.\n\n"
    page.write_text(text + "\n".join(lines) + "\n", encoding="utf-8")


def topic_page(page: str | None, title: str) -> str:
    """The ticked item's page, which must be one of the KB's topic pages (never a decision or data file)."""
    if not page:
        raise DigestError(f"no page for '{title[:60]}'; add `→ docs/knowledge/<page>.md` to its line")
    pages = {p.relative_to(KB_DIR).as_posix() for p in KB_DIR.rglob("*.md")}
    pages = {p for p in pages if not p.startswith("decisions/") and p not in kblib.NOT_PAGES}
    if page not in pages:
        raise DigestError(f"page {page!r} isn't a topic page under docs/knowledge/")
    return page


def accept(issue: dict) -> tuple[str, str]:
    author = (issue.get("user") or {}).get("login")
    if author and author != "github-actions[bot]":
        raise DigestError(f"digests come from kb-curator, but this issue was opened by {author}")
    items = ticked_items(issue.get("body") or "")
    if not items:
        raise DigestError("nothing is ticked; tick the items worth adding, then re-add kb-accepted")
    by_page: dict[str, list[dict]] = {}
    for it in items:
        by_page.setdefault(topic_page(it["page"], it["title"]), []).append(it)
    n, added = issue["number"], 0
    for page, its in by_page.items():
        text = (KB_DIR / page).read_text(encoding="utf-8")
        new, seen = [], set()
        for it in its:
            if f"]({it['url']})" not in text and it["url"] not in seen:
                seen.add(it["url"])
                new.append(it)
        if new:
            added += len(new)
            add_to_page(KB_DIR / page, [
                f"- [{it['title'].replace('[', '(').replace(']', ')')}]({it['url']})"
                f" ({it['source']}{', ' + it['date'] if it['date'] else ''}; digest #{n})."
                " *Unverified:* summarize it here and check it against a primary source." for it in new])
    if not added:
        raise DigestError("every ticked item is already on its page; close the digest instead")
    pages = ", ".join(f"`docs/knowledge/{p}`" for p in sorted(by_page))
    return (f"KB digest picks: {added} item(s) from #{n}",
            f"Adds {added} of the {len(items)} item(s) ticked in #{n} to {pages}, under \"{SECTION}\".\n\n"
            "Before merging, turn each link into a sentence or two in our own words, cite a primary "
            "source, drop its *Unverified* marker, and update the page's `last_reviewed`.")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sp = sub.add_parser("supersede", help="print the open digests the new one replaces, one per line")
    sp.add_argument("--issues", required=True, help="JSON from gh issue list --json number,body,comments")
    sp.add_argument("--new", type=int, required=True, help="the digest issue just opened")
    args = ap.parse_args()
    issues = json.loads(Path(args.issues).read_text(encoding="utf-8"))
    for number in superseded(issues, args.new):
        print(number)
    return 0


if __name__ == "__main__":
    sys.exit(main())
